
# Qdrant Code Indexing — Daemon + MCP — Project Plan (v0.1)

**Date:** 2025-08-26

This plan turns the Architecture Spec into milestones, tickets, acceptance criteria, and decision checkpoints. It assumes **single-node Qdrant**, **CPU embeddings**, and **Linux/macOS** targets.

---

## 1) Success Criteria (KPIs)

- **Search quality:** ≥ 0.7 nDCG@10 on a 50-query eval set built from your repos; manual spot-check passes.  
- **Latency:** hybrid search P95 ≤ 120 ms on medium repos; hybrid+rerank P95 ≤ 350 ms for top‑K=100 on CPU.  
- **Indexing throughput:** ≥ 300 chunks/sec dense‑only; ≥ 150 chunks/sec dense+sparse on your iMac.  
- **Freshness:** save→search visibility ≤ 2 s (watch mode, same session).  
- **Stability:** daemon uptime ≥ 7 days; no leaks (steady RSS under sustained edits).

---

## 2) Milestones & Deliverables

**M0 — Bootstrap (1–2 days)**  
- Repos created (daemon, MCP, editor plugin).  
- CI set up (lint/test on macOS/Linux).  
- Sample config + `.env` templates.  
**Deliverables:** repo skeletons, CI green.

**M1 — Qdrant schema + batch indexer (3–5 days)**  
- Create collection with **named vectors** `dense` (size set by model) and `sparse`.  
- Chunker (sliding windows).  
- Dense embeddings (FastEmbed MiniLM/BGE).  
- Batch upsert with stable IDs + `wait=true`.  
**AC:** CLI indexes a repo; simple query returns relevant chunks.

**M2 — Hybrid search + sparse vectors (4–6 days)**  
- Sparse pipeline (BM25 or SPLADE).  
- Query API integration: dense, sparse, **hybrid** with RRF & DBSF.  
- Small eval harness to compare modes.  
**AC:** measurable boost on eval set; default mode chosen (likely RRF).

**M3 — Watcher daemonization (4–6 days)**  
- File watcher (git‑aware ignores), debounce, batching.  
- Idempotent updates; delete-by-filter for deletions.  
- **systemd/launchd** units and logs.  
**AC:** save a file → visible in search ≤ 2 s; service restarts cleanly.

**M4 — MCP server (3–5 days)**  
- Tools: `activate`, `deactivate`, `index_all`, `reindex(paths)`, `purge(paths)`, `search`, `status`, `scope`.  
- Session hooks: start passes `project_root`; exit deactivates.  
**AC:** Works in Claude Code; search tool returns scoped results.

**M5 — LSP integration (Neovim-first) (4–7 days)**  
- **Option A**: tiny Neovim plugin forwarding didSave/rename/delete to daemon.  
- **Option B (PoC)**: Rust sidecar via `tower-lsp` for structured chunking.  
- Decision checkpoint: keep A only, or proceed toward B.  
**AC:** save in Neovim triggers targeted reindex; reduced churn vs pure FS watch.

**M6 — Universal ingestion (Docs & Web) (6–10 days)**  
- Local docs ingestion (Markdown, text, PDF text).  
- Web crawler with ETag/Last‑Modified, rate limits, allow‑lists.  
- Separate corpus collections + federated search across collections.  
**AC:** search across code+docs with clear source metadata.

**M7 — Reranking (optional) (3–5 days)**  
- Cross‑encoder reranker; cache results; toggle in MCP.  
**AC:** precision@10 improvement on eval; acceptable latency.

**M8 — Observability & Security (3–4 days)**  
- Metrics endpoints; structured logs.  
- Daemon API auth token; localhost binding; exclusions.  
- Backups/snapshots documented.  
**AC:** basic dashboard; runbook complete.

**M9 — Hardening & Tuning (3–5 days)**  
- Stress tests (large repos, deletes, binary files ignored).  
- Memory profiling; quantization toggle if needed.  
- Final defaults (RRF/DBSF, top‑K, batch sizes).  
**AC:** KPIs met; 1.0 tag cut.

---

## 3) Work Breakdown (Tickets)

**Schema & Indexing**  
- Define collection schema (dense+sparse).  
- Implement chunker; language/size heuristics.  
- Dense embedder adapter (FastEmbed).  
- Sparse adapter (BM25/SPLADE).  
- Upsert API with `wait=true`, retries, backoff.

**Daemon Core**  
- Project registry; config loader; ignore rules.  
- Watch loop; debounce; batcher.  
- Stable ID + delete-by-filter paths.  
- HTTP/Unix-socket API; health/status.

**MCP Server**  
- Tool wiring; session lifecycle (activate/deactivate).  
- Search modes & scoping.  
- Error surfaces (timeouts, unready daemon).

**LSP/Editor**  
- Neovim plugin skeleton; event forwarder (HTTP).  
- Optional: `tower-lsp` sidecar PoC (documentSymbol).

**Universal Ingestion**  
- Markdown/HTML/PDF extractors; anchor/heading mapping.  
- Web crawler (robots/etag/limits).  
- Corpus configs & schedules; federation.

**Observability/Security**  
- Metrics counters/timers; logs.  
- Auth token for daemon API; localhost bind.  
- Backup/snapshot scripts; alias swap helper.

**Eval & QA**  
- Build 50–100 labeled queries per repo.  
- Eval harness (nDCG@10, P@5/10).  
- Latency/throughput benches.

---

## 4) Key Decisions to Confirm

- **Dense model** default: `all-MiniLM-L6-v2` vs `bge-small-en-v1.5`.  
- **Sparse method:** BM25 (fast) vs SPLADE (heavier, higher recall).  
- **Hybrid fusion default:** RRF (likely) vs DBSF; allow per-project override.  
- **LSP path:** Neovim plugin only vs add Rust sidecar later.  
- **Collections for submodules:** single collection with `module` payload vs per-module collections + federation.  
- **Rerank model:** Jina v2 vs BGE reranker; K default (e.g., 100).

---

## 5) Risks & Mitigations

- **CPU-only embeddings too slow** → batch + async; smaller models; cache.  
- **PDF extraction variance** → start with text-based; add OCR later.  
- **Schema evolution** → use **aliases** for swaps.  
- **Index growth** → TTL/purge policy; dedupe by hash; cap chunk size.  
- **Editor diversity** → start Neovim; FS watcher covers Claude Code standalone.

---

## 6) Testing Strategy

- **Unit**: chunk boundaries, ID stability, payload schema.  
- **Integration**: index→query roundtrip; delete/rename; multi-collection federation.  
- **Load**: 100k+ chunks; concurrent upserts + queries.  
- **Chaos**: kill daemon mid-write; verify idempotence on resume.  
- **Eval**: regression suite tracks nDCG/P@K across milestones.

---

## 7) Operations Runbook (Summary)

- **Start/Stop**: `systemctl --user start project-code-daemon` (macOS: launchctl).  
- **Rebuild**: ingest into `{repo}-code-vN`, then alias swap `current-{repo}-code`.  
- **Purge path**: daemon `purge(paths=[...])`.  
- **Backup**: snapshot collection dir; record alias map.  
- **Troubleshoot**: check metrics/logs; verify model dim vs schema.

---

## 8) Documentation To Ship

- README (quick start), CONFIG.md (knobs), OPERATIONS.md (runbook), EVALUATION.md (metrics & methodology), SECURITY.md (bindings/auth/exclusions).
