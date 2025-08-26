# Lean Knowledge & Retrieval for Claude Code — A→H Playbook

**Scope**: You use Claude Code exclusively for coding, run **Qdrant** as a local service (non‑Docker), and prefer **no external APIs**. You also use **@modelcontextprotocol/server‑memory** (JSON‑backed KG). This playbook merges the earlier **Core Ideas (A→H)** with **concrete implementation guidance**—what *you* do, what the *model* should do, and what to *configure on servers*—so you can keep context tight and precise.

**Roles/Legend**  
**You** = manual workflows or scripts you run.  
**Model** = stable prompting/instructions you keep in your Claude Code profile/snippets.  
**Server** = MCP/Qdrant/GitHub MCP configuration choices.

---

## A) Keep KG tiny (but useful)
**Goal**: The KG provides crisp, durable truths and pointers—*not* long prose. Reduce prompt surface while increasing reliability.

**You**
- Keep KG nodes minimal: IDs, names, 1–3 bullet **rule cards** (≤ 300–500 chars), and **links** to rich sources in Qdrant (docs/code).
- Promote only *stable* facts from retrieved text into KG, never whole paragraphs.

**Model**
- Always retrieve from **`rules`** first (k ≤ 3). Use **KG = facts**, **Qdrant = prose**. Expand only when asked or when uncertainty is high.
- Treat KG entries as authoritative; if a doc contradicts KG, ask for human confirmation.

**Server**
- Maintain a tiny Qdrant collection **`rules`** (micro‑snippets) separate from `docs`/`code`.
- In the Qdrant MCP, set tool descriptions to bias the model to consult `rules` first.

**Pitfalls**: KG bloat (too much prose); stale rules mixed with current ones.  
**Metric**: % of answers grounded by 1–3 rule cards without needing expansion.

---

## B) GitHub MCP without bloat (structure→slice)
**Goal**: Pull *only what’s needed* (function/hunk/region), not entire files.

**You**
- Adopt a two‑step flow: **(1) structure** (repo tree, symbols, search paths) → **(2) slice** (fetch the smallest range needed).
- Prefer *diff‑first* for active work (pass hunks rather than full files).
- Impose **size gates** (e.g., max 200–400 lines per fetch) and fall back to summaries + candidate ranges.

**Model**
- "Never fetch the whole file unless explicitly required. Prefer function/section ranges, or diff hunks."
- When multiple files match, ask for a short disambiguation or fetch only top‑1 region with a brief summary.

**Server**
- Start GitHub MCP in **read‑only** mode by default. Enable write actions only when needed.
- Limit to minimal toolsets (e.g., `context,repos`). Prefer dynamic/lazy toolsets if available.

**Pitfalls**: Recursive fetches; giant files; binary blobs.  
**Metric**: Avg. lines per GitHub fetch; % of answers solved with slices only.

---

## C) Qdrant retrieval that stays small
**Goal**: Small, high‑signal results through schema discipline and pre‑filters.

**You**
- Define collections by **role**: `rules` (tiny), `facts-short` (curated micro‑snippets), `docs` (chunked text), `code` (function/hunk chunks). Optionally per‑project variants.
- Design **payload** (metadata) for pre‑filtering: `project`, `version`, `lang`, `path`, `section`, `pub_date`, `tags`.
- Chunk sizes: **200–500 tokens** with headings. Store **1‑sentence abstract** in payload for each chunk.

**Model**
- Filter by `project/version` before vector search.
- Default to **abstracts**; include full chunk only on demand.
- Use small **top‑k** per source (k = 2–4) and diversity (avoid near‑duplicates).

**Server**
- Keep **one embedding family per collection**. Record `model_name` and `dim`.
- Run multiple **named instances** of the same Qdrant MCP to target different collections (per role or per project).

**Pitfalls**: Mixed embeddings in a collection; missing payload fields.  
**Metric**: Avg. tokens per retrieval; duplicate‑rate in merged results.

---

## D) Multi‑collection search (when & how)
**Goal**: Fuse narrow slices from multiple domains without inflating the prompt.

**You**
- Decide fusion sets (e.g., **`docs + code`** for coding questions). Keep **budget per source** (e.g., 2 abstracts each).
- If models differ across collections, keep rankings **within** collection and fuse at the end (don’t compare raw distances).

**Model**
- Retrieval order: **rules → facts‑short → (docs & code)**.
- Merge, dedup by path/URL and cosine (> 0.98). Output only top 4–6 items total.

**Server**
- Prefer same embedding family across cross‑searched collections for cleaner scoring. If not possible, rely on per‑collection ranking + fusion.

**Pitfalls**: Score skew from mixed models; excessive k per collection.  
**Metric**: #sources blended per answer; relevance of top‑1 chunk (manual spot‑check).

---

## E) “Docs‑variety” ingestion (books/manuals allowed)
**Goal**: Curated, versioned, offline docbases.

**You**
- Run a small **ingester**: parse (Markdown/HTML/PDF) → normalize → **semantic chunk** → embed → upsert.
- Add rich payload: `title`, `breadcrumbs`, `version`, `pub_date`, `url/anchor`, `license`.
- You *can* ingest large works (Rust Reference, algorithms texts). The key is chunking + payload.
- Handle **obsolescence** via either versioned collections (e.g., `rust_ref_2025-08`) or a `version`/`date` payload and a “latest” filter.

**Model**
- Prefer newest version by default; cite section/anchor; escalate to full chunk only as needed.

**Server**
- Keep collections **separable** so you can drop/rebuild per source or per edition without touching others.

**Pitfalls**: Oversized chunks; mixing editions; missing anchors.  
**Metric**: % of answers with section‑level citations; re‑index time per source.

---

## F) Embedding choices on CPU (FastEmbed vs. Ollama nomic)
**Goal**: Balance speed, quality, and maintenance.

**You**
- Default to **FastEmbed (ONNX)** for bulk indexing and fast queries.
- Trial **Ollama `nomic-embed-text`** (or `bge-m3`) on one project where you want that family.
- Never mix models in one collection; pin `dim` and `model_name` in notes.
- Optionally: FastEmbed for all collections; Ollama only at **query time** for heavy questions (separate retriever).

**Model**
- Prefer FastEmbed collections unless a specific collection is earmarked for Ollama.

**Server**
- Official Qdrant MCP provides **FastEmbed**. For Ollama‑embedded corpora, use a **separate** retriever targeting the Ollama‑dimensioned collection.

**Rules of thumb** (relative, CPU‑only): FastEmbed is typically **order‑of‑magnitude faster** per chunk; Ollama models can yield better semantics for certain domains/languages at the cost of latency and RAM.

**Pitfalls**: Dimension mismatch; slow batch indexing with Ollama.  
**Metric**: ms/embedding; docs/sec indexed; top‑k MRR on a small relevance set.

---

## G) Token budgeting & compression
**Goal**: Fit more signal into fewer tokens.

**You**
- Set a **hard context budget** (e.g., ≤ N tokens). Allocate **25%** to `rules/facts`, **75%** to task context.
- Keep abstracts cached with chunks to avoid on‑the‑fly summarization cost.

**Model**
- Summarize each retrieved chunk to **2–3 sentences**; include **path/anchor** for optional expansion.
- Avoid duplicates; don’t include both a parent chunk and its child if the child suffices.

**Server**
- None required (beyond tool descriptions). Consider a small re‑ranking or MMR in your retriever if available.

**Pitfalls**: Over‑summarization that loses key code; redundant chunks.  
**Metric**: Tokens per answer; manual grading of faithfulness.

---

## H) Operational hygiene (keep it clean & auditable)
**Goal**: Maintain consistency and easy rollback.

**You**
- Record `model_name`, `dim`, and `created_at` for each collection; re‑embed **per collection** when you upgrade models.
- Add TTL/decay for volatile notes; prune regularly.
- Maintain a **summaries cache** (abstracts) and regenerate only when content changes.
- Backups & rollback: snapshot Qdrant collections before large re‑embeds.

**Model**
- Do not assume cross‑collection score comparability unless models match.

**Server**
- Run **multiple named instances** of the same MCP: one per collection or per project, each with its own `COLLECTION_NAME` and description.
- Consider a **separate admin MCP** (locked down) for deletes or drop‑collection while keeping the official Qdrant MCP append‑only.

**Pitfalls**: Accidental mixed embeddings; irrecoverable deletes.  
**Metric**: Time to rebuild a collection; % of collections with pinned metadata.

---

## Minimal GitHub surface (practical profile)
- Default profile: GitHub MCP **read‑only**, toolsets **`context,repos`** only.
- "Power" profile (opt‑in): enable extra toolsets only when needed (create/rename/set privacy).
- Claude policy snippet: "Fetch structure first, then smallest slice; favor diffs; never fetch entire file unless asked."

---

## Dynamic server usage (switching on/off)
- Keep multiple **profiles/configs** for Claude Code (per project or per task). Swap config/symlink and restart.
- Prefer retrievers that can run as **SSE/HTTP** you can start/stop independently; keeping them down effectively hides their tools.
- Use **dynamic/lazy toolsets** where supported (e.g., GitHub) to shrink default exposure.

---

## Example collection layout (CPU‑only, no external APIs)
- `rules` — micro‑snippets (policy cards). *(FastEmbed)*
- `facts-short` — curated 1–3 sentence facts. *(FastEmbed)*
- `docs` — chunked manuals/books with abstracts + breadcrumbs. *(FastEmbed)*
- `code` — function/hunk chunks with path/lines/lang. *(FastEmbed)*
- `proj‑X‑docs‑ollama` — optional project using Ollama `nomic-embed-text`. *(Separate retriever, own dim)*

**Retrieval policy**: Always include `rules` (k=2) → `facts-short` (k=2) → small k from `docs` & `code`; summarize; cite path/anchor; expand on demand.

---

## Checklist (quick start)
- [ ] Prune KG to IDs + rule cards + links.
- [ ] Create Qdrant collections: `rules`, `facts-short`, `docs`, `code` (+ per‑project if needed).
- [ ] Define payload schema and chunking policy; add abstracts.
- [ ] Configure minimal GitHub MCP toolsets; read‑only by default.
- [ ] Add Claude snippets that enforce retrieval order and size gates.
- [ ] Benchmark FastEmbed vs. Ollama on one project; pin model dims.
- [ ] Set up backups and a locked‑down admin path for deletes (separate from the main Qdrant MCP).
