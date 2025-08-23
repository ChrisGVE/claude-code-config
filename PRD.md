# Overview

This blueprint describes the desired state of the MCP environment for development work with Claude Code and related subagents. It consolidates design decisions made in earlier discussions, with emphasis on **separation of concerns** and the ability to define **per-project environments**. The goal is to provide a clear PRD to drive reconfiguration of a test environment before wider deployment.

The project is defined in three parts:

1. Setting up the mcp components as per the specifications below, their current state is stored in the `mcp/` folder of this project.
2. Updating the existing prompting system, consisting of a global system prompt and a per-project prompt, their current state is stored in the `prompts/` folder of this project.
3. Creating two subagents that will be deployed permanently as per the specifications below, their `.md` files is to be stored into `prompts/agents`

# Core Features

> **Note:** The Task-master (MCP) task schema and the Qdrant project-memory payload used in this environment are **explicitly described in this PRD** to avoid ambiguity. Task-master’s model is adopted from its upstream documentation, and the Qdrant payload is a custom contract defined here for STORE/FIND; neither should be treated as an off‑the‑shelf standard outside this PRD.

## Task Management

- **Task-master** is the **source of truth for all tasks**.
- **Sequential-Thinking** creates task DAGs from PRDs and persists them to Task-master.
- **Serena** executes development tasks (build, fix, refactor), updates statuses, and reports back to Task-master. Serena delegates QA tasks to QA Orchestrator.
- **QA Orchestrator** handles all testing tasks via Temporal workflow orchestration, creates bug fix tasks in Task-master.
- **GitHub MCP** is used only for repo management (creation, linking to project, and optional issue mirroring).

## Codebase Context

- **Claude-Context-MCP** provides semantic and structural codebase retrieval.
- Embedding: handled locally with Ollama (nomic-embed-text).
- DB backend: Milvus (self-contained with Claude-Context). Serena queries Claude-Context for code context, never reindexes code itself.

## Project Memory

- **Qdrant-MCP** stores project-specific memory (algorithms, decisions, notes, designs, ingested web content).
- Schema includes: `{project, type, tags, stage, summary, content_ref, related_task_ids}`.
- Storage is **per-project collection** in Qdrant, with summaries returned first and hydration of full text only on demand.
- **Ingest-web-mcp** pushes external content (scraped via trafilatura/BeautifulSoup, queried through SearxNG) into Qdrant instead of Milvus.

## Subagents

- **Planner Subagent**: handles PRD → task DAG conversion, writes to Task-master only.
- **Architect Subagent**: manages architectural decisions and ADRs, stores summaries in Qdrant.
- **QA Orchestrator**: specialized agent for testing workflows, uses Temporal for durable orchestration.
- All subagents are deployed per-project via registry-based selection.

## Project Profiles

- Each project has a `.claude/project.json` config generated at bootstrap via registry-based tool selection.
- Always-on MCPs: Task-master, Time, GitHub, Qdrant, Claude-Context.
- Optional MCPs enabled per project via signals from PRD:
  - `corrode` (Rust-specific projects)
  - `ios-simulator-mcp` (iOS/iPadOS projects)
  - `mermaid` (diagrams/doc-heavy projects)
  - `magic-ui-design` (UI/UX focused projects)
  - `container-use` (devops/testing needs)
  - `qa-mcp` (custom QA orchestration)

- Sequential-Thinking is enabled when planning subtasks.
- **Registry-driven deployment**: MCP and subagent selection based on project signals with GitHub Actions compatibility.

## MCP & Subagent Registry

**Tool Selection Strategy:**
- Registry file maps project signals → required MCPs and subagents
- Bootstrap script infers signals from PRD (stack, targets, ui_focus, etc.)
- Preference for global tool installation (`uv tool install`, `npm install -g`) over Docker
- All MCPs maintained as thin interface layers over underlying systems
- Regular update scheduling via batch scripts

**File Structure:**
```
/Users/chris/dev/ai/claude-code-cfg/
├── mcp/              # ALL MCP code (project-specific or global)
├── prompts/          # System and project templates
│   ├── CLAUDE.md.template
│   └── CLAUDE_SYSTEM.md
├── resources/        # Deployable artifacts
│   ├── agents/       # Subagent source files
│   └── registry.yaml # Tool selection registry
└── persistent_memory/ # Data storage
    ├── qdrant/
    ├── kiwi-tcms/
    └── reportportal/
```

**Registry Structure (`resources/registry.yaml`):**
```yaml
mcps:
  qa-mcp:
    name: "qa-mcp"
    signals: ["testing", "qa", "e2e"]
    integration: "qa-mcp --port 8080"
  corrode:
    name: "corrode"
    signals: ["rust", "cargo.toml"]
    integration: "corrode-mcp"

subagents:
  qa-orchestrator:
    signals: ["testing", "qa"]
    source: "agents/qa-orchestrator.md"
  planner:
    signals: ["planning"]
    source: "agents/planner.md"

prompts:
  claude-md:
    source: "/Users/chris/dev/ai/claude-code-cfg/prompts/CLAUDE.md.template"
    target: "CLAUDE.md"
  claude-system:
    source: "/Users/chris/dev/ai/claude-code-cfg/prompts/CLAUDE_SYSTEM.md"
    target: "CLAUDE_SYSTEM.md"

folders:
  - ".claude/agents"
  - ".claude/hooks"
  - ".claude/commands"

files:
  - file: ".claude/settings.json"
    content: "{}"

claude-integration:
  command: "claude mcp add {name} -- {integration}"
```

**Bootstrap Workflow:**

**Phase 1: Project Declaration & Bootstrap Setup**
```
User declares: "New project" OR "Upgrade existing project"
Claude (via system prompt):
- Copy CLAUDE.md.bootstrap → PROJECT_ROOT/CLAUDE.md
- Instruct user: "/clear context and restart"
```

**Phase 2: Context Restart with Bootstrap Template**
```
New Project: PRD creation → Bootstrap MCP → Task planning
Existing Project: Code exploration → Qdrant review → PRD review → Bootstrap MCP → Task planning
```

**Phase 3: claude-capabilities MCP Operations**
1. Parse registry.yaml based on PRD signals
2. Create folders (`.claude/agents/`, `.claude/hooks/`, `.claude/commands/`)
3. Create files (`.claude/settings.json` with `{}`)
4. Copy prompts (`CLAUDE.md.template` → `CLAUDE.md`, etc.)
5. Deploy matching subagents to `.claude/agents/`
6. Execute `claude mcp add {name} -- {integration}` for matching MCPs
7. Initialize project with task-master, claude-context, serena

# User Experience

- **Project Bootstrap Flow**:
  1. User creates repo and adds `PRD.txt`.
  2. Run `project_bootstrap.py`, which:
     - Calls Task-master to ingest PRD.
     - Infers signals (stack, targets, ui_focus, diagrams, etc.).
     - Generates `.claude/project.json` enabling only relevant MCPs and linking subagents.
     - Prepares Qdrant collection for project memory and seeds PRD summary.

  3. Sequential-Thinking generates initial tasks → Task-master.
  4. Serena executes ready tasks, querying Claude-Context for code and Qdrant for project memory.
  5. Debugging/QA MCP validates outputs at each phase and ensures feedback loops.

- **Context Management**:
  - Serena and subagents fetch **summaries first** from Qdrant.
  - Claude-Context provides repo snippets directly.
  - Hydration of full content is explicit, preventing context bloat.

# Technical Architecture

## Authoritative Data Contracts

### Tasks (Task-master / authoritative schema)

We follow the upstream **Task Master** task model exactly (no custom fields). This section summarizes the canonical fields and how we use them in this environment.

**Fields (canonical, per docs)**

- `id` — unique identifier (e.g., `8`). Subtasks use dotted IDs (e.g., `8.1`).
- `title` — brief, descriptive title.
- `description` — what the task involves.
- `status` — `pending` | `done` | `deferred`.
- `dependencies` — prerequisite task IDs that must be done first.
- `priority` — `high` | `medium` | `low`.
- `details` — implementation notes / step plan.
- `testStrategy` — how we verify success.
- `subtasks` — optional nested tasks, same shape.

**Usage notes**

- We **do not add extra fields**. Any cross-links (Qdrant memory, code refs, artifacts) live inside `details` or `testStrategy` using stable link strings.
- Because the schema does not include `in_progress`/`blocked`, treat work-in-progress as **`pending`** and represent blocking via `dependencies` plus a short note in `details`.

**Cross-link conventions inside `details`/`testStrategy`**

- Memory item → `memory:qdrant://collection=pm_<project>/id=<point_id>`
- Code reference → `code:gh://<repo>/<path>#Lx-Ly`
- Artifact → `artifact:file://…` or `artifact:https://…`
- Bug reference → `bug:gitea://repo/issues/<number>`
- Test campaign → `campaign:kiwi://project/<id>`
- Test run → `run:reportportal://project/<launch_id>`

### Project Memory (Qdrant payload / custom contract)

The Qdrant MCP requires you to define the payload used by `qdrant-store`/`qdrant-find`. This is the **authoritative contract**:

**Payload fields**

- `project` _(required)_ — project slug; also used for collection naming and filters.
- `type` _(required)_ — `algorithm | decision | design | note | todo | adr`.
- `tags` — freeform keywords.
- `stage` — `draft | refined | final`.
- `summary` — ≤200-token distillation for retrieval.
- `content_ref` — pointer to full body (`file://`, `http(s)://`, etc.).
- `related_task_ids` — Task-master IDs (e.g., `"8"`, `"12.2"`).
- `created_at`, `updated_at` — ISO-8601 timestamps.

**Vector space**

- 384‑d (FastEmbed MiniLM‑L6‑v2) when using the Qdrant MCP’s embedder, or 768‑d if ingest writes Ollama vectors. **Collection vector size must match.**

**Collection strategy**

- One collection per project: `pm_<project-slug>`; keep `project` in payload redundantly for safety.

**STORE tool example**

```json
{
  "information": "Short body or summary-first text; full body should live at content_ref.",
  "metadata": {
    "project": "pen-ink-app",
    "type": "decision",
    "tags": ["architecture", "client-server"],
    "stage": "refined",
    "summary": "ADR: Split UI and core via RPC boundary…",
    "content_ref": "file://docs/adr/0001-ui-core-boundary.md",
    "related_task_ids": ["8"]
  },
  "collection_name": "pm_pen-ink-app"
}
```

**FIND tool example (summary-first)**

```json
{
  "query": "ui-core boundary adr",
  "collection_name": "pm_pen-ink-app",
  "filter": { "must": [{ "key": "stage", "match": { "value": "refined" } }] },
  "limit": 8,
  "return": "summary"
}
```

### Ingest-web-mcp Pipeline (with SearxNG)

**Goal**: SearxNG → fetch → parse → summarize → embed → upsert to Qdrant.

1. **Search** via SearxNG (`SEARXNG_URL`) with `format=json` (enable JSON in `settings.yml`).
2. **Deduplicate/normalize** URLs (`tldextract`), avoid AMP/mirror hosts.
3. **Fetch** with retries (`tenacity`).
4. **Parse** using `trafilatura` (fallback: BeautifulSoup) to extract clean text + title + metadata.
5. **Summarize** into ≤200 tokens for `summary`; write full body to `content_ref`.
6. **Embed** via **Ollama** (`nomic-embed-text`) _or_ **FastEmbed**; ensure vector size matches the collection.
7. **Upsert** to Qdrant with the payload contract above.

### QA Architecture (Specialized Orchestrator Model)

**Objective**: Durable, state-as-data QA workflows with clear separation of concerns.

**Architecture Decision:** Specialized QA Orchestrator handles all testing workflows, with Serena focused on development tasks.

**Component Roles:**

- **Task-master**: Source of truth for all tasks (including QA tasks)
- **Serena**: Executes development tasks, delegates QA tasks to QA Orchestrator, handles bug fixes
- **QA Orchestrator**: Specialized agent using Temporal for durable workflow orchestration
- **QA MCP**: Thin interface layer over Gitea Issues + Kiwi TCMS + ReportPortal + Temporal

**Tool Stack (Self-hosted, GitHub-compatible):**

- **Bug Tracking**: Gitea/Forgejo Issues (GitHub Actions-compatible syntax)
- **Test Management**: Kiwi TCMS (campaigns, test cases, runs)
- **Analytics**: ReportPortal (automation results, flaky test detection)
- **Orchestration**: Temporal (durable workflows, retries, audit history)
- **Tracing**: Langfuse (token budgets, role drift monitoring)
- **Execution Tools**: playwright-mcp, container-use, corrode (Rust)

**Simplified Task Hierarchy:**

QA workflows use clean task grouping to separate workflow concerns from detailed bug tracking:

```
Task 15: Implement feature X
Task 16: Test campaign for feature X (depends on 15)  
Task 17: Fix bugs from test campaign 16 (depends on 16, created if bugs found)
  ├── Subtask 17.1: Fix Bug #101 (links to Gitea Issue #101)
  ├── Subtask 17.2: Fix Bug #102 (links to Gitea Issue #102)
  └── Subtask 17.3: Fix Bug #103 (links to Gitea Issue #103)
Task 18: Regression test after fixes (optional)
```

**QA MCP Tool Surface (Thin Layer):**

```python
# Campaign Management (→ Kiwi TCMS)
qa.create_campaign(task_id, scope, entry_criteria, exit_criteria)
qa.get_campaign(campaign_id)

# Test Execution (→ ReportPortal + local runners)  
qa.start_test_run(campaign_id, test_suite)
qa.record_result(run_id, test_id, status, artifacts)

# Bug Management (→ Gitea Issues)
qa.create_bug(title, repro_steps, severity, failing_run_id)
qa.link_bug_to_task(bug_id, task_id)

# Analytics (→ ReportPortal)
qa.get_flaky_tests(campaign_id)
qa.get_coverage_trends(project_id)

# Human Approval Gates
qa.request_approval(campaign_id, approval_type, context)
```

**State-as-Data Principle:**

All QA state lives in systems, not prompts:
- **Test campaigns/cases**: Kiwi TCMS (operational)
- **Test results**: ReportPortal (analytics)
- **Bugs**: Gitea Issues (detailed lifecycle)
- **Workflow state**: Temporal (orchestration)
- **Project context**: Qdrant (summaries, decisions)
- **Task workflow**: Task-master (high-level progress)

**Workflow Example:**

1. **Serena** completes development Task 15
2. **Serena** encounters QA Task 16 → delegates to **QA Orchestrator**
3. **QA Orchestrator** (via Temporal):
   - Creates test campaign in Kiwi TCMS
   - Spawns test execution subagents
   - **If bugs found**: creates bugs in Gitea Issues + Task 17 with subtasks
   - Marks Task 16 as `done` (campaign complete)
4. **Serena** handles subtasks 17.1, 17.2, 17.3 (fixes)
5. **QA Orchestrator** verification: re-runs tests, closes bugs if successful

**Bug Lifecycle Integration:**
- **Gitea Issues**: Detailed bug states (Open → In Progress → Fixed → Closed)
- **Task-master Subtasks**: Work items within fix batches
- **Cross-linking**: `bug:gitea://repo/issues/101` ↔ `task 17.1`
- **Iteration**: Failed fixes create new subtasks, bugs remain open

**GitHub Compatibility & Updates:**
- **Gitea Actions**: GitHub Actions-compatible YAML syntax for future migration
- **CI/CD Integration**: QA orchestrator can trigger/consume GitHub CI results
- **Update Scheduling**: Batch scripts for regular tool updates (Gitea, Kiwi TCMS, ReportPortal, Temporal)

**Role Contracts & Guardrails:**
- **QA Orchestrator**: 1-2 sentence mission + allowed QA tools only
- **Subagents**: Specific roles (test executor, triage analyst) with tool restrictions  
- **Budget enforcement**: Token/time limits with orchestrator oversight
- **Human gates**: Required approval for campaign closure, critical bug triage

## System Components

- **Claude Code**: MCP orchestrator.
- **MCP Servers**: Task-master, Claude-Context, Qdrant, GitHub, Time, Sequential-Thinking, **Debugging/QA MCP**, and optional project‑specific servers.
- **Subagents**: Planner, Architect.

## Infrastructure

**Core Services:**
- **Milvus**: Claude-Context semantic search (self-contained)
- **Qdrant**: Project memory (local, Docker)
- **Ollama**: Embeddings (nomic-embed-text for Claude-Context + ingest-web)
- **SearxNG**: Search aggregator for ingest-web (local Docker)

**QA Infrastructure:**
- **Gitea/Forgejo**: Self-hosted Git + Issues (GitHub Actions compatible)
- **Kiwi TCMS**: Test campaign and case management  
- **ReportPortal**: Test result analytics and reporting
- **Temporal**: Workflow orchestration (durable, retry logic)
- **Langfuse**: Agent tracing and evaluation

**Tool Installation Preference:**
1. **Global tools**: `uv tool install <mcp>` or `npm install -g <mcp>`
2. **Docker fallback**: For tools requiring complex dependencies
3. **Update automation**: Scheduled batch scripts for tool maintenance

**GitHub Ecosystem Compatibility:**
- Gitea Actions uses GitHub Actions YAML syntax
- Seamless migration path to GitHub workflows
- CI/CD definitions portable between platforms

### Qdrant runtime (Docker)

```bash
docker run -d --name qdrant \
  -p 6333:6333 -p 6334:6334 \
  -v $HOME/qdrant/storage:/qdrant/storage \
  qdrant/qdrant:latest
```

### Project Configuration Example

Registry-driven `.claude/project.json` generation:

```json
{
  "mcpServers": {
    "task-master": { "command": "task-master-ai" },
    "qdrant": {
      "command": "uvx",
      "args": ["mcp-server-qdrant"],
      "env": {
        "QDRANT_URL": "http://localhost:6333",
        "COLLECTION_NAME": "pm_<project-slug>",
        "EMBEDDING_MODEL": "sentence-transformers/all-MiniLM-L6-v2"
      }
    },
    "claude-context": { "command": "claude-context-mcp" },
    "github": { "command": "github-mcp" },
    "time": { "command": "time-mcp" },
    "qa-mcp": {
      "command": "qa-mcp",
      "env": {
        "GITEA_URL": "http://localhost:3000",
        "KIWI_TCMS_URL": "http://localhost:8080",
        "REPORTPORTAL_URL": "http://localhost:8081",
        "TEMPORAL_URL": "localhost:7233"
      }
    }
  },
  "subagents": {
    "planner": { "path": ".claude/agents/planner.md" },
    "architect": { "path": ".claude/agents/architect.md" },
    "qa-orchestrator": { "path": ".claude/agents/qa-orchestrator.md" }
  }
}
```

# Development Roadmap

## MVP

- Task-master as task authority with simplified QA task hierarchy.
- Sequential-Thinking → Task-master integration.
- Serena executes development tasks, delegates QA to QA Orchestrator.
- QA Orchestrator with Temporal workflows and specialized tool stack.
- Qdrant integration for project memory, per-project collections.
- Ingest-web modified to push into Qdrant via SearxNG.
- Registry-driven `.claude/project.json` bootstrap script.
- QA MCP as thin layer over Gitea + Kiwi TCMS + ReportPortal + Temporal.
- Update automation via scheduled batch scripts.

## Future Enhancements

- Add rerankers (e.g., bge-reranker) to Qdrant search.
- Extend bootstrap to support per-project overrides (`project.profile.json`).
- Automated GitHub issue mirroring from Task-master.
- UI/dashboard for monitoring tasks + memory + QA results.

# Logical Dependency Chain

1. Establish Task-master as central authority.
2. Connect Sequential-Thinking → Task-master.
3. Wire Serena to Task-master (execution only).
4. Keep Claude-Context self-contained with Milvus + Ollama.
5. Deploy Qdrant + Qdrant-MCP, adapt ingest-web.
6. Implement project bootstrap config generator.
7. Add Debugging/QA MCP pipeline.
8. Add optional MCPs as per project profiles.

# Risks and Mitigations

- **Overlap between Serena and Task-master** → mitigated by strict role separation (Serena executes only).
- **Context bloat** → mitigated by summary-first retrieval in Qdrant.
- **Embedding quality tradeoffs** → default to Ollama nomic-embed-text; test FastEmbed as fallback.
- **Complexity in per-project configs** → mitigated with bootstrap script and registry-driven rules.
- **QA pipeline failures** → mitigated by Debugging/QA MCP with retries, logging, and Task-master status hooks.

# Permanent Subagents Definitions

**Planner Subagent (`planner.md`)**

```md
# Subagent: Planner

## Role

Transform PRDs into a dependency-ordered task DAG with crisp acceptance criteria.

## Tools

- task-master: create/update tasks
- qdrant: retrieve project memory (summaries first)

## Guardrails

- Never execute tasks. Only plan and persist to Task-master.
```

**Architect Subagent (`architect.md`)**

```md
# Subagent: Architect

## Role

Owns system and code architecture decisions (boundaries, components, data contracts).

## Tools

- qdrant: store/retrieve decisions and ADRs
- claude-context: cite code when validating feasibility

## Guardrails

- Favor ADRs (short, versioned). Don't push long blobs into context; store then summarize.
```

**QA Orchestrator Subagent (`qa-orchestrator.md`)**

```md
# Subagent: QA Orchestrator

## Role

Orchestrates testing workflows using Temporal for durable, state-as-data QA processes.

## Tools

- qa-mcp: campaign management, test execution, bug tracking
- temporal: workflow orchestration, retries, state management
- task-master: create fix tasks and subtasks
- qdrant: store test summaries and decisions

## Guardrails

- Never execute development tasks - only testing workflows
- All state in external systems (Kiwi TCMS, ReportPortal, Gitea)
- Create fix tasks in Task-master when bugs found
- Use simplified task hierarchy: campaign → fix task → bug subtasks
- Enforce human approval gates for critical decisions
```

# Example Code Snippets

## Project Bootstrap (writes `.claude/project.json`, ensures Qdrant collection)

```python
#!/usr/bin/env python3
import json, os, sys
from pathlib import Path

proj_root = Path.cwd()
prd_path = proj_root/"PRD.txt"
if not prd_path.exists():
    print("PRD.txt not found", file=sys.stderr); sys.exit(1)

cfg = {
  "mcpServers": {
    "task-master": {"command": "task-master-ai"},
    "qdrant": {
      "command": "uvx",
      "args": ["mcp-server-qdrant"],
      "env": {
        "QDRANT_URL": "http://localhost:6333",
        "COLLECTION_NAME": "pm_" + proj_root.name.replace(" ", "-"),
        "EMBEDDING_MODEL": "sentence-transformers/all-MiniLM-L6-v2"
      }
    },
    "claude-context": {"command": "claude-context-mcp"},
    "github": {"command": "github-mcp"},
    "time": {"command": "time-mcp"}
  },
  "subagents": {
    "planner": {"path": "~/.subagents/planner.md"},
    "architect": {"path": "~/.subagents/architect.md"}
  }
}

out = proj_root/".claude"/"project.json"
out.parent.mkdir(exist_ok=True)
out.write_text(json.dumps(cfg, indent=2))
print("Wrote", out)

# Ensure Qdrant collection
try:
    from qdrant_client import QdrantClient
    from qdrant_client.http.models import VectorParams, Distance
    q = QdrantClient(url=os.getenv("QDRANT_URL","http://localhost:6333"))
    col = cfg["mcpServers"]["qdrant"]["env"]["COLLECTION_NAME"]
    try:
        q.get_collection(col)
    except Exception:
        q.recreate_collection(col, vectors=VectorParams(size=384, distance=Distance.COSINE))
    print("Qdrant collection ready:", col)
except Exception as e:
    print("(Optional) qdrant-client not installed:", e)
```

## Qdrant Upsert with FastEmbed (384‑d)

```python
from fastembed import TextEmbedding
from qdrant_client import QdrantClient
from qdrant_client.http.models import PointStruct

client = QdrantClient(url="http://localhost:6333")
embed = TextEmbedding(model_name="sentence-transformers/all-MiniLM-L6-v2")
texts = ["Algorithm draft", "UI design note"]
vectors = list(embed.embed(texts))
points = [
  PointStruct(id=i, vector=vectors[i], payload={"project":"demo","type":"note","stage":"draft"})
  for i in range(len(texts))
]
client.upsert(collection_name="pm_demo", points=points)
```

## SearxNG Query (ingest‑web‑mcp)

```python
import os, requests
SEARX = os.getenv("SEARXNG_URL", "http://localhost:8080")
resp = requests.get(
    f"{SEARX}/search",
    params={"q":"site:qdrant.tech hybrid search","format":"json","categories":"general"},
    timeout=30
)
resp.raise_for_status()
for r in resp.json().get("results", []):
    print(r.get("title"), r.get("url"))  # then fetch+parse; summarize; embed; upsert
```

## Filtered Semantic Search (summary‑first)

```python
from qdrant_client.http.models import Filter, FieldCondition, MatchValue

query = "rerank pipeline for code+notes"
vector = list(embed.embed([query]))[0]
flt = Filter(must=[
  FieldCondition(key="project", match=MatchValue(value="pen-ink-app")),
  FieldCondition(key="stage", match=MatchValue(value="refined"))
])

hits = client.search(
  collection_name="pm_pen-ink-app",
  query_vector=vector,
  limit=8,
  query_filter=flt,
  with_payload=True
)
for h in hits:
    print(h.score, h.payload.get("summary"))
```

# Enhanced System Prompt Workflow

## Mandatory Pre-Planning Process

**Phase 1: PRD Review (Iterative)**
1. Read complete PRD.md from project root
2. Ask clarification questions (always, even if gaps not obvious)
3. If user provides new information → update PRD.md → return to step 1
4. If no new information → proceed to confirmation
5. Confirm complete PRD understanding with user before proceeding

**Phase 2: Context Assessment**
- New projects: Signal collection only (no Qdrant data expected)
- Existing projects: Code exploration + tool initialization + Qdrant memory review
- Collect required capabilities/signals from PRD

**Phase 3: Bootstrap & Planning**
1. Pass signals to bootstrap MCP for capability installation
2. Initialize project with task-master, claude-context, serena
3. Create task plan in task-master
4. Final task: "Plan testing campaign, confirm with user, update task-master"

**claude-capabilities MCP Scope:**
- **Core**: Signal detection + capability installation + project initialization
- **Extended**: Add new capabilities during development (uplift) + agent customization pipeline
- **Implementation**: Python-based using claude-code-sdk, dual-mode (stdio MCP + CLI tool)

# System Prompt Suggestions

- **Task separation**
  “Serena never creates tasks. Task-master (MCP) is the single authority for task creation and lifecycle. Serena executes only and reports status and artifacts back to Task-master.”

- **Statuses & dependencies**
  “Use only the canonical statuses: `pending`, `done`, `deferred`. Model blocking exclusively via `dependencies`. Treat work‑in‑progress as `pending` and log progress in `details` with time‑stamped notes.”

- **Retrieval discipline**
  “Always retrieve **summaries first** from Qdrant and hydrate full content only when necessary. Keep context tight; avoid large blobs without explicit user confirmation.”

- **Code retrieval**
  “All code snippets and cross‑references must come through **Claude‑Context‑MCP**. Do not attempt to reindex code elsewhere.”

- **Traceability**
  “Reference Task IDs (e.g., `8`, `8.1`) in commits, PR titles, Qdrant `related_task_ids`, and ADRs.”

- **Role boundaries**  
  "Serena: development, fixes, refactoring. QA Orchestrator: testing workflows via Temporal. Clear handoff at QA task delegation."

- **QA workflow hierarchy**
  "Use simplified task structure: campaign → fix task → bug subtasks. Bugs tracked in Gitea Issues with detailed lifecycle, subtasks for work items."

- **State-as-data principle**
  "All QA state in systems, not prompts: campaigns in Kiwi TCMS, results in ReportPortal, bugs in Gitea Issues, workflows in Temporal."

- **Error handling**
  "On any MCP failure, retry once with exponential backoff; if still failing, surface a concise error with the tool name and attempted parameters, then propose a fallback."

