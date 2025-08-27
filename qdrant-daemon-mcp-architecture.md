# Qdrant Code Indexing — Daemon + MCP Architecture Spec (Full)

**Status:** v0.4  
**Author:** (you)  
**Date:** 2025-08-26

---

## 1) Goals & Non-Goals

**Goals**
- Keep a lightweight, always-available **Rust daemon** that indexes codebases into **Qdrant** without Docker.
- Let a **Claude MCP server** act as a thin control/search surface: start/stop watching, force reindex, search, status.
- Support **dense + sparse** representations from day one (hybrid search); optional **re-ranking** for high-precision results.
- Work with **git** repos (including submodules) and also with non-git folders.
- Play nicely with **Neovim** (and other editors) via **LSP** or filesystem watching.

**Non-Goals**
- Not a full RAG framework; no generation or answer synthesis here.
- No automatic remote sync; storage is local Qdrant (you can later swap to a remote cluster).

---

## 2) High-Level Architecture

```
+-----------------+        stdio / TCP         +------------------------+
|  Claude (host)  | <------------------------> |  MCP: project-code-mcp |
+-----------------+                             +------------------------+
        |                                                   |
        | local RPC / HTTP (loopback)                       | local RPC / HTTP
        v                                                   v
+-------------------------+                      +---------------------------+
| Rust Daemon (systemd)   |  <---- LSP / FS ---- |  Editor/Neovim / Watcher |
|  - Project registry     |                      |  (plugin or LSP sidecar) |
|  - Chunking & Embedding |                      +---------------------------+
|  - Upload to Qdrant     |
+-----------+-------------+
            |
            | REST / gRPC (loopback or LAN)
            v
      +-----------+
      |  Qdrant   |
      +-----------+
```

**Responsibilities**
- **Daemon (Rust):** owns filesystem/LSP watching, chunking, embeddings, upserts/deletes, schema creation, and indexing queues. Exposes a small HTTP/Unix-socket API.
- **MCP server (Python or Rust):** session-scoped controller + search tools. On start, passes `{project_root}` to daemon to **activate** the project; on stop, sends a **deactivate**. Provides `search`, `index_all`, `reindex(paths)`, `purge(paths)`, `status`, `scope` (collections).
- **Editor integration (optional):** Neovim plugin (Lua) or Rust LSP sidecar to push didOpen/didChange/didSave/didClose + file ops for precise incremental updates.
- **Qdrant:** stores points with **named vectors**: `dense` (float32, fixed dim) and `sparse` (term-weight pairs), plus payload metadata.

---

## 3) Collections & Data Model

### 3.1 Collection layout
- Default: **one collection per repo root**, name `{repo}-code`. Submodules are *included* with payload fields `repo`, `module`, `path`.
- For very large submodules: optional **per-module collection** `{repo}-{module}-code`. The daemon provides **federated search** (fan-out + client-side fusion) across selected collections.
- Support **aliases** for zero-downtime rebuilds: e.g., `current-{repo}-code → {repo}-code-v2`.

### 3.2 Schema (declare at creation)
- **Named vectors**:
  - `dense`: `size = <embedding_dim>`, `distance = Cosine` (or Dot/L2 matching model training).
  - `sparse`: sparse vector space (score is **Dot**; no size needed).
- **Payload** (JSON):
  - `repo`: string (repo name)
  - `module`: string (submodule or “root”)
  - `path`: string (POSIX path relative to project root)
  - `lang`: string (heuristic or from LSP)
  - `sym`: string (optional: function/class name)
  - `range`: object `{start: [line, col], end: [line, col]}`
  - `hash`: string (content hash for dedupe/audit)

**Note:** plan for both vector types from the start; adding new vector *names* to an existing collection typically requires creating a new collection + alias swap.

---

## 4) Ingestion & Freshness

### 4.1 Chunking
- Start with sliding windows (e.g., 1200 chars, 200 overlap).
- Prefer **symbol-aligned** chunks when LSP is available (function/class/docstring blocks). Attach `sym` and `range` to payload.
- Treat large files with cap + stride (avoid huge vectors).

### 4.2 Embeddings
- **Dense:** any local CPU-friendly model (e.g., MiniLM/BGE via FastEmbed or your provider of choice).
- **Sparse:** BM25/miniCOIL or SPLADE to produce term-weight pairs. Store under the `sparse` vector name.

### 4.3 Indexing loop
- On activation: ensure collection exists; if empty, **initial index**; else **diff** (git + mtime + hash) to reindex only changed files.
- Live updates: on file save/rename/delete events, re-chunk → re-embed → **upsert** (or delete by filter for deletions).
- API knobs: batch size, debounce, CPU threads.

### 4.4 Consistency & concurrency
- Use Qdrant **idempotent upserts** (stable IDs) and pass `wait=true` for read-your-writes in interactive sessions; use `ordering=strong` when you require strict ordering.
- In clusters, configure `write_consistency_factor` if you later scale out.

---

## 5) Querying

### 5.1 Modes
- **Dense-only** (semantics)
- **Sparse-only** (lexical exactness: identifiers, error codes)
- **Hybrid** (recommended default): run both and **fuse** results on the server with `rrf` or `dbsf`.

### 5.2 Multi-stage (coarse → refine)
- Fetch N candidates (cheaper vectors or quantized) then **refine** with a richer representation (full-precision dense or **multi-vector/ColBERT**).
- Use Qdrant **Query API** `prefetch` to compose stages.

### 5.3 Re-ranking (optional second stage)
- Pull top-K candidates from Qdrant, then apply a **cross-encoder** (e.g., Jina reranker, BGE reranker) to reorder.
- Use a toggle for “high precision” mode; cache `(query_hash, point_id) → score` during a session.

### 5.4 Scoping
- The MCP exposes a `scope` parameter to target one collection, a set of collections, or “current project.” The daemon handles fan-out and client-side fusion for multi-collection queries.

---

## 6) Editor / LSP Integration

### 6.1 Options
- **Neovim plugin (Lua) → Daemon:** forward LSP notifications (didOpen/didChange/didSave/didClose, workspace file changes). Lowest friction; leverages existing language servers (pyright, rust-analyzer, etc.).
- **Rust LSP sidecar (tower-lsp):** register as a workspace utility server; receive the same notifications and optionally request `documentSymbol` / `semanticTokens` to drive AST-aware chunking.
- **Fallback:** filesystem watcher for when no editor is running (e.g., Claude Code standalone).

### 6.2 Control plane
- **Daemon** owns watchers and queues. MCP calls daemon APIs to `activate(project_root)`, `deactivate(project_root)`, and to run one-shot tasks (`index_all`, `purge`).

---

## 7) Operations

- **Backfills/Rebuilds:** create `{repo}-code-v2`, stream data in, then flip alias `current-{repo}-code → {repo}-code-v2`.
- **Compaction:** Qdrant background optimizers keep segments healthy; no collection-wide lock.
- **Backup:** snapshot/restore per collection on deploy/CI steps.
- **Resource control:** rate-limit embeddings, bound concurrent upserts, and enable quantization if RAM is tight.

---

## 8) Security & Deployment

- Bind daemon + MCP to **localhost** by default. Optional Unix socket for daemon API.
- Use simple tokens for MCP→daemon auth if needed.
- Log PII-safe payloads only (paths, hashes). Support `exclude` globs.
- Package daemon as **systemd** service (Linux) and launchd agent (macOS).

---

## 9) Configuration (suggested)

```yaml
daemon:
  data_dir: ~/.local/share/project-code
  debounce_ms: 600
  batch_size: 128
  embedding:
    dense_model: sentence-transformers/all-MiniLM-L6-v2
    sparse: bm25  # or 'splade'
qdrant:
  url: http://127.0.0.1:6333
  collections:
    default_distance: cosine
mcp:
  default_scope: current-project
  default_mode: hybrid   # dense|sparse|hybrid
  rerank:
    enabled: false
    top_k: 100
    model: jinaai/jina-reranker-v2-base-multilingual
```

---

## 10) References (further reading)

- **Qdrant vectors (dense, sparse, named vectors):**  
  https://qdrant.tech/documentation/concepts/vectors/

- **Hybrid & multi-stage search (Query API, prefetch, RRF/DBSF, MMR):**  
  https://qdrant.tech/documentation/concepts/hybrid-queries/  
  https://api.qdrant.tech/api-reference/search/query-points

- **Sparse vectors & hybrid overview:**  
  https://qdrant.tech/articles/sparse-vectors/

- **Create collections & runtime updates (indices/quantization):**  
  https://api.qdrant.tech/api-reference/collections/create-collection  
  https://qdrant.tech/documentation/concepts/collections/

- **Collection aliases (zero-downtime swaps):**  
  https://api.qdrant.tech/api-reference/aliases/update-aliases

- **Upserts and idempotence:**  
  https://api.qdrant.tech/api-reference/points/upsert-points  
  https://qdrant.tech/documentation/concepts/points/

- **Delete by filter & wait semantics:**  
  https://api.qdrant.tech/api-reference/points/delete-points

- **Distributed write consistency:**  
  https://api.qdrant.tech/documentation/guides/distributed_deployment/

- **FastEmbed hybrid & rerankers:**  
  https://qdrant.tech/documentation/beginner-tutorials/hybrid-search-fastembed/  
  https://qdrant.tech/documentation/fastembed/fastembed-rerankers/

- **LSP specification (document sync & workspace events):**  
  https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/

- **Rust LSP sidecar (tower-lsp):**  
  https://docs.rs/tower-lsp/  
  https://github.com/ebkalderon/tower-lsp

---

## 11) Universal Ingestion Extensions (Docs & Web)

**Objective:** Extend the daemon so *all* knowledge inflows (local docs and selected web sources) are normalized into Qdrant under well‑scoped collections, and are searchable alongside code (with opt‑in fusion).

### 11.1 Scope & Sources
- **Local documents:** `.md`, `.txt`, `.rst`, `.ipynb` (text cells), `.pdf` (text‑based; optional OCR plugin for scanned PDFs), common config formats (`.toml/.yaml/.json`).
- **Web documents:** Documentation sites (e.g., Rust stdlib, docs.rs), API references, wikis/handbooks. Support **URL submit**, **sitemap crawl**, or **seed list**.
- **Project‑adjacent folders:** `docs/`, `design/`, `ADR/`, `CHANGELOG.md`, `README.md` across repo and submodules.

### 11.2 Collections Strategy
- Keep **code** in `{repo}-code`.  
- Create **one collection per corpus** (e.g., `{repo}-docs`, `rust-stdlib-docs`), each with both `dense` + `sparse`.  
- Provide MCP **scopes**: `code-only`, `docs-only:<name>`, or federated sets (e.g., `code+docs:{repo}`, `code+rust-stdlib`). Federation uses client‑side fusion across collections.

### 11.3 Ingestion Pipeline
1) **Fetch** — local watcher/globs; web crawler with robots/ETag caching.  
2) **Extract** — Markdown/HTML/PDF text extraction with anchors/page numbers.  
3) **Normalize** — tree (headings/sections); chunk at semantic boundaries.  
4) **Represent** — dense (embeddings) + sparse (BM25/SPLADE).  
5) **Upsert** — stable IDs; payload: `source_type`, `source_id`, `title`, `heading_path`, `anchor`, `page`, `lang`, `hash`, `license`, `retrieved_at`.  
6) **Refresh** — diff by ETag/content; delete-by-filter then re‑ingest changed sources.

### 11.4 Query & Fusion
- Within a collection: **hybrid** (RRF/DBSF).  
- Across collections: fan‑out + client-side fusion; preserve `collection` and `source_id` in results.  
- Multi‑stage: `prefetch` → `refine`; optional **rerank** on combined top‑K.

### 11.5 Scheduling & Control
- Per‑source schedules; backoff on failures; MCP `refresh(source)` tool.  
- Allow‑lists, max pages, rate limits; robots/licensing stored in payload.

### 11.6 Security & Privacy
- Network fetches off by default; explicit allow-lists.  
- Redact tokens/PII in payload; per‑source exclusions.  
- Separate profiles for web corpora; opt‑in inclusion in project searches.

### 11.7 Observability
- Metrics: pages fetched/changed, chunks, embedding time, upsert latency, last refresh.  
- Health: `/status`, `/sources`, `/jobs`, `/queue` with errors/retries.

### 11.8 Failure Modes & Recovery
- Retries with backoff; idempotent upserts; filtered batched deletes (`wait=true`).  
- Safe rebuild via **aliases**: build `{corpus}-vN` then swap.

---

## Appendix A — Quick Notes & Source Pointers

- **Named vectors (dense + sparse) in one collection; plan at creation.** Qdrant supports storing both dense and sparse vectors per point as *named* vectors. Define vector spaces when creating the collection. Use aliases for zero‑downtime swaps when you need schema changes.  
  Sources: https://qdrant.tech/documentation/concepts/vectors/ ; https://qdrant.tech/documentation/concepts/points/ ; https://qdrant.tech/documentation/concepts/collections/ ; https://api.qdrant.tech/api-reference/aliases/update-aliases

- **Hybrid search & multi-stage are query-time constructs.** Use the **Query API** to compose dense + sparse branches and fuse results with **RRF** or **DBSF**, and to do multi-stage prefetch/refine plans.  
  Sources: https://qdrant.tech/documentation/concepts/hybrid-queries/ ; https://api.qdrant.tech/api-reference/search/query-points ; https://qdrant.tech/articles/hybrid-search/

- **Consistency and read-your-writes.** Use `wait=true` on upserts (and `ordering=strong` when needed). In distributed setups, tune `write_consistency_factor`.  
  Sources: https://api.qdrant.tech/api-reference/points/upsert-points ; https://api.qdrant.tech/api-reference/collections/create-collection

- **Reranking is a separate pipeline step.** Fetch top‑K from Qdrant, then apply a cross‑encoder reranker (e.g., via FastEmbed). It does not modify DB data; it reorders results per query.  
  Sources: https://qdrant.tech/documentation/beginner-tutorials/hybrid-search-fastembed/ ; https://qdrant.tech/documentation/fastembed/fastembed-rerankers/

---

## Appendix B — Choosing between RRF and DBSF (Hybrid Fusion)

- **RRF (Reciprocal Rank Fusion)**: Best when sub‑queries produce *heterogeneous* score scales or models; it only cares about **ranks**, not raw scores. Safe default, robust to outliers and incomparable scales.  
- **DBSF (Distribution‑Based Score Fusion)**: Best when score **distributions are reliable and comparable**; it **normalizes** each list’s scores (using mean ± 3σ by default) and then sums, often giving finer control when one branch is more confidently separated.  
- **Practical heuristic**: start with **RRF** (robust baseline). If you observe that one branch (e.g., sparse BM25) has well‑separated scores and you want to weight it more, try **DBSF** (and/or explicit weights). Validate with a small eval set and pick per‑project defaults.  
  Sources: https://qdrant.tech/documentation/concepts/hybrid-queries/
