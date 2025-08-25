# Overview

This blueprint describes the desired state of the MCP environment for development work with Claude Code and related subagents. It consolidates design decisions made in earlier discussions, with emphasis on **separation of concerns** and the ability to define **per-project environments**. The goal is to provide a clear PRD to drive reconfiguration of a test environment before wider deployment.

The project is defined in three parts:

1. Setting up the mcp components as per the specifications below, their current state is stored in the `mcp/` folder of this project.
2. Updating the existing prompting system, consisting of a global system prompt and a per-project prompt, their current state is stored in the `prompts/` folder of this project.
3. Creating project-specific subagents for planning phases, their `.md` files stored in `prompts/agents`

# Core Features

> **Note:** The Task-master (MCP) task schema and the Qdrant project-memory payload used in this environment are **explicitly described in this PRD** to avoid ambiguity. Task-master’s model is adopted from its upstream documentation, and the Qdrant payload is a custom contract defined here for STORE/FIND; neither should be treated as an off‑the‑shelf standard outside this PRD.

## Task Management

- **Task-master** is the **source of truth for all tasks**.

**Task Creation Authority (Hierarchical)**:
- **Sequential-Thinking**: Creates initial task DAGs from PRDs (bootstrap only)
- **Claude Debugger MCP**: Creates bug fix tasks and subtasks when tests fail (QA workflow only)
- **Planner Subagent**: Updates task structure during PRD revisions (planning phases only)

**Task Execution Architecture**:
- **Claude Code** acts as **supervisor**, orchestrating subagents for all development work
- **Development Subagents** handle specific tasks (build, fix, refactor, test) under Claude Code supervision
- **Claude Code** updates task statuses in Task-master and coordinates with Claude Debugger MCP
- **Claude Debugger MCP** handles all testing workflows via self-contained orchestration
- **GitHub MCP** is used only for repo management (creation, linking to project, and optional issue mirroring)

## Codebase Context

- **Claude-Context-MCP** provides semantic and structural codebase retrieval.
- Embedding: handled locally with Ollama (nomic-embed-text).
- DB backend: **Milvus (dedicated to claude-context only)** - self-contained with Claude-Context. 
- **Architectural Decision**: Milvus and Qdrant operate as separate, specialized vector stores due to claude-context's Milvus dependency and Qdrant's superior ingestion performance and recall for project memory.
- **Claude Code** and **development subagents** query Claude-Context for code context, never reindex code themselves.

## Project Memory

- **Qdrant-MCP** stores project-specific memory (algorithms, decisions, notes, designs, ingested web content).
- Schema includes: `{project, type, tags, stage, summary, content_ref, related_task_ids}`.
- Storage is **per-project collection** in Qdrant, with summaries returned first and hydration of full text only on demand.
- **Ingest-web-mcp** pushes external content (scraped via trafilatura/BeautifulSoup, queried through SearxNG) into Qdrant instead of Milvus.

## Subagents

**On-Demand Subagents (Deployed Based on Phase/Needs)**:
- **Planner Subagent**: handles PRD → task DAG conversion, writes to Task-master only. Deployed during bootstrap and PRD revision phases.
- **Architect Subagent**: manages architectural decisions and ADRs, stores summaries in Qdrant. Deployed during bootstrap and architectural planning phases.
- **Development Subagents**: Handle build, fix, refactor, and implementation tasks under Claude Code orchestration
  - Backend Engineer, Frontend Engineer, Full Stack Developer (overlapping but clearly delineated roles)
  - Testing Specialists, Debugging Specialists
- **Specialized Subagents**: Project-specific agents deployed based on capabilities (e.g., Rust expert, React specialist)

**Specialized MCPs**:
- **Claude Debugger MCP**: Detailed specifications in [`mcp/claude-debugger/PRD.md`](./mcp/claude-debugger/PRD.md)
- **Ingest-web MCP Modifications**: Detailed specifications in [`mcp/ingest-web-mcp/PRD.md`](./mcp/ingest-web-mcp/PRD.md)

**Registry-Based Deployment**:
- Project-specific subagents are deployed during planning phases via registry-based selection.

## Project Profiles

- Each project has a `.claude/project.json` config generated at bootstrap via registry-based tool selection.
- **Always-on MCPs**: Task-master, Time, GitHub, Qdrant, Claude-Context, Sequential-Thinking.
- **On-Demand Subagents**: All subagents deployed based on project phase and capability needs (no permanent subagents).
- **Optional MCPs** enabled per project via capabilities from PRD:
  - `corrode` (Rust-specific projects)
  - `ios-simulator-mcp` (iOS/iPadOS projects)
  - `mermaid` (diagrams/doc-heavy projects)
  - `magic-ui-design` (UI/UX focused projects)
  - `container-use` (devops/testing needs)
  - `debugger-mcp` (custom QA orchestration)

- **Registry-driven deployment**: MCP and subagent selection based on project capabilities with GitHub Actions compatibility.
- **Claude Code Orchestration**: Supervises all development subagents via parallel execution, coordinates task execution, manages handoffs to Claude Debugger MCP.
- **Lifecycle Management**: All subagents deployed on-demand, no permanent agents, Claude manages parallel execution naturally.

## MCP & Subagent Registry

**Tool Selection Strategy:**
- Registry file maps project capabilities → required MCPs and subagents
- Bootstrap script infers capabilities from PRD (stack, targets, ui_focus, etc.)
- Preference for global tool installation (`uv tool install`, `npm install -g`) over Docker
- All MCPs maintained as thin interface layers over underlying systems

**Registry Management Philosophy:**
- **Latest Versions**: Always use latest MCP versions - no version pinning
- **Graceful Degradation**: Failed MCPs don't block Claude startup, continue with available tools
- **Capability Standardization**: Prevent overlapping tools (e.g., Playwright over Puppeteer)
- **Break-Fix Approach**: When ecosystem changes break MCPs, fix and continue
- **Maintenance Acceptance**: Registry updates are normal operational overhead

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
  debugger-mcp:
    name: "debugger-mcp"
    capabilities: ["testing", "qa", "e2e"]
    integration: "debugger-mcp --port 8082"
  corrode:
    name: "corrode"
    capabilities: ["rust", "cargo.toml"]
    integration: "corrode-mcp"
  playwright-mcp:
    name: "playwright-mcp"
    capabilities: ["web-automation", "e2e-testing", "browser-control"]
    integration: "playwright-mcp"
    replaces: ["puppeteer-mcp", "selenium-mcp", "browser-automation-mcp"]

subagents:
  planner:
    capabilities: ["planning", "prd_work"]
    source: "agents/planner.md"
    phases: ["bootstrap", "prd_revision"]
    deployment: "on-demand"
  architect:
    capabilities: ["architecture", "prd_work"]
    source: "agents/architect.md"
    phases: ["bootstrap", "architecture_planning"]
    deployment: "on-demand"
  backend-engineer:
    capabilities: ["backend", "api", "database"]
    source: "agents/backend-engineer.md"
    phases: ["development", "implementation"]
    deployment: "on-demand"
  frontend-engineer:
    capabilities: ["frontend", "ui", "ux"]
    source: "agents/frontend-engineer.md"
    phases: ["development", "ui_implementation"]
    deployment: "on-demand"

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
  # Content-defined files (inline content)
  - file: ".claude/settings.json"
    content: "{}"
  
  # Source-copied files (copy from source to target)  
  - file: ".gitignore"
    source: "/Users/chris/dev/ai/claude-code-cfg/templates/.gitignore.template"
  
  - file: "CLAUDE.md"
    source: "/Users/chris/dev/ai/claude-code-cfg/prompts/CLAUDE.md.template"

workflows:
  new_project:
    step: 1
      name: "Project Scaffolding Setup"
      description: "Hook up new project with scaffolding infrastructure"
      task: 1
        name: "Git Repository Check"
        git:
          dirty: yes
          command: "git commit -am"
          message: "Committing staged files before setting up project"
      task: 2
        name: "CLAUDE.md Backup"
        file:
          action: "move_within_project"
          source: "CLAUDE.md"
          target: "CLAUDE.md.backup"
          if_exists: yes
      task: 3
        name: "Folder and File Creation" 
        directory: ".claude/agents/"
        directory: ".claude/hooks/"
        directory: ".claude/commands/"
        file:
          action: "copy_into_project"
          source: "templates/registry.template.yaml"
          target: ".claude/registry.yaml"
        file:
          action: "copy_into_project"
          source: "templates/task-master.config.json"
          target: ".claude/task-master.config.json"
        file:
          action: "copy_into_project"
          source: "prompts/CLAUDE.md.step2"
          target: "CLAUDE.md"
      task: 4
        name: "Project Registry Population"
        project_registry:
          action: "sync"
      task: 5
        name: "Agent Installation"
        project_registry:
          action: "deploy_agent"
          agent_name: "planner"

claude-integration:
  command: "claude mcp add {name} -- {integration}"
```

## Registry Workflow Syntax

**Structure:** `workflows: <workflow_name>: step: N task: N`
- Each step and task includes `name:` and `description:` for maintainability and user messaging

**Operation Types:**

**File Operations:**
- `file:` with `action:`, `source:`, and `target:`
- **Actions:**
  - `copy_into_project`: Copy global file into project (source relative to global registry)
  - `copy_within_project`: Copy file within project  
  - `move_within_project`: Move/rename within project (used for backup)
- Optional `if_exists: yes/no` (unconditional if not specified)

**Directory Operations:**
- `directory:` (folder relative to project root, uses `mkdir -p` for nested creation)

**Git Operations:**
- `git:` with optional `dirty:` condition:
  - `dirty: yes` → execute if unstaged files exist
  - `dirty: no` → execute if no unstaged files  
  - No `dirty:` → unconditional execution
- `command:` (e.g., `git commit -am`)
- `message:` (optional, automatically appended in quotes)

**Project Registry Operations:**
- `project_registry:` with `action:` and `name:` (single string or list)
  - `sync` → synchronize project registry with installed agents/MCPs
  - `deploy_agent` → deploy agent(s)  
  - `deploy_mcp` → deploy MCP(s)
  - `undeploy_agent` → undeploy agent(s)
  - `undeploy_mcp` → undeploy MCP(s)

**Claude Operations:**
- `claude:` with `action:` (pending Claude Code SDK capability research):
  - `clear_context` → equivalent of `/clear` command to reset context
  - `prompt_and_over_to_user` with `prompt:` → inject prompt and hand control to user
  - `message` with `message:` → send message to user from within MCP

**Task-master Operations:**
- `task-master:` with `action:` (syntax TBD based on chosen integration approach):
  - `init` → initialize task-master with PRD and generate task DAG
  - `get_tasks` → retrieve all tasks (CLI/MCP-to-MCP/direct integration)
  - `update_task` → update task with capability requirements (integration dependent)
  - `query_tasks` with `filter:` → query existing tasks (e.g., filter: "incomplete")

**Safety Check Operations:**
- `safety_check:` with `action:`, `path:`, and `behavior:`
  - `check_exists` → check if path exists, behavior: "preserve_if_exists"

**Bootstrap Workflow:**

## New Project Workflow (Path A)

**Workflow Trigger:**
- User declares new project with PRD location (draft or template)
- System prompt triggers claude-capability-manager MCP with:
  - PRD file location
  - Project type indicator: `new_project`

**Step 1: Project Scaffolding Setup**
*Purpose: Hook up new project with scaffolding infrastructure (no configuration yet)*

- **Task 1 - Git Repository Check:**
  - Check if repository initialized
  - If yes: check for staged files
  - If staged files exist: commit with message "Committing staged files before setting up project"
  - If no repository: skip task

- **Task 2 - CLAUDE.md Backup:**
  - Check existence of CLAUDE.md
  - If exists: backup as CLAUDE.md.backup (preserve user's existing configuration)

- **Task 3 - Folder and File Creation:**
  - Create required folder structure via global registry
  - Create files: registry template, task-master standard configuration
  - Copy special version of system prompt into CLAUDE.md (prepare for Step 2)

- **Task 4 - Project Registry Population:**
  - Populate project registry with agents already installed in `.claude/agents/`
  - Check existing project MCPs from `.claude.json`

- **Task 5 - Agent Installation:**
  - Install necessary agents (defined in global registry workflows section)
  - Hook agents up to project registry

**Step 2: PRD Iterative Refinement**
*Purpose: Work iteratively with user on PRD until complete and confirmed*

- **Task 1 - Context Clear:**
  - Clear context to load agents installed in Step 1 (equivalent of `/clear` command)
  - **Registry Syntax**: `claude: action: clear_context` (pending SDK capability research)
  - Fallback: Prompt user to quit and relaunch Claude

- **Task 2 - Prompt Injection and User Handoff:**
  - Inject specialized PRD refinement prompt
  - Hand control to Claude for iterative user interaction
  - **Registry Syntax**: `claude: action: prompt_and_over_to_user, prompt: "..."`
  - Available agents: research agents, prompt specialist, architect, etc.
  - Continue until PRD complete and user confirms readiness

**Completion**: System prompt triggers claude-capability-manager MCP for Step 3

**Step 3: Task-master Initialization and Execution Setup**
*Purpose: Initialize task-master, generate capability requirements, deploy for execution*

- **Task 1 - Task-master Initialization:**
  - Initialize task-master with refined PRD (variable filename from Claude)
  - Task-master defines complete task DAG according to PRD
  - **Registry Syntax**: `task-master: action: init` (syntax TBD based on chosen integration approach)

- **Task 2 - Capability Requirements Generation:**
  - Get each task from task-master (CLI or MCP-to-MCP communication)
  - Use subagent to generate required capabilities for each task
  - Update tasks with capability requirements
  - **Integration Dependencies**: TBD based on task-master integration research

- **Task 3 - System Prompt Replacement and Agent Cleanup:**
  - Replace CLAUDE.md with main system prompt
  - Undeploy initialization subagents
  - **Registry Syntax**: `project_registry: action: undeploy_agent, name: ["planner", "architect"]`

- **Task 4 - Task 1 Execution Preparation:**
  - Deploy agents/MCPs needed for task-master's first task
  - **Implementation**: TBD based on chosen task-master integration approach

- **Task 5 - Context Clear:**
  - Clear context for execution phase
  - **Registry Syntax**: `claude: action: clear_context`

- **Task 6 - Final User Handoff:**
  - Hand complete control back to user with full system ready
  - **Registry Syntax**: `claude: action: prompt_and_over_to_user, prompt: "[execution ready prompt]"`

**Completion**: All initialization complete, user has control with task-master and full capability system ready

## Existing Project Workflow (Path B)

**Philosophy**: User-driven workflow selection with minimal detection and maximum reuse of new project patterns.

**Key Assumptions:**
- Core system already installed (not starting from scratch)
- User wants migration = user wants to uplift project (dissatisfied with current state)

### **User-Driven Entry Points**

**README.md Use Cases** (documented after Installation section):
- "Migrate existing project with PRD"
- "Migrate existing project with task-master already initialized" 
- "Migrate existing project with specs in CLAUDE.md"
- "Add capabilities to ongoing task-master project"

**User Interaction**: User follows README instructions and tells Claude which entry point applies to their situation.

### **3-Step Workflow Structure**

**Step 1: Safety Check & Entry Point Routing**
*Purpose: Preserve existing work and route to appropriate sub-workflow*

- **Task 1 - Safety Check:**
  - Check `.taskmaster/` folder existence to avoid overwriting
  - **Registry Syntax**: `safety_check: action: check_exists, path: ".taskmaster/", behavior: preserve_if_exists`

- **Task 2 - Existing Task Query:**
  - Query existing tasks if task-master already initialized
  - **Registry Syntax**: `task-master: action: query_tasks, filter: incomplete`

- **Task 3 - Entry Point Routing:**
  - Route to appropriate sub-workflow based on user's stated entry point
  - No automation - user-directed workflow selection

**Step 2: PRD Resolution (Conditional)**
*Purpose: Ensure project has validated PRD for task-master initialization*

**Sub-workflow A: PRD Exists**
- Validate/refine existing PRD with user (minimal changes)

**Sub-workflow B: Specs in CLAUDE.md** 
- Claude extracts and formalizes specs using natural language processing (no special tooling)
- **Registry Syntax**: Reuse new project Step 2 PRD refinement workflow

**Sub-workflow C: No PRD**
- Branch to new project Step 2 (PRD creation workflow)

**Step 3: Task-master Alignment & Capability Deployment**
*Purpose: Align task-master with project state and deploy required capabilities*

- **Task 1 - Task-master Initialization/Refresh:**
  - Initialize task-master (if not exists) or refresh with updated PRD
  - **Registry Syntax**: `task-master: action: init` (reuse new project syntax)

- **Task 2 - Capability Requirements Generation:**
  - Query incomplete tasks for capability requirements
  - Generate capability mappings for existing/pending work

- **Task 3 - Project Registry Setup:**
  - Install project registry if missing + sync with existing agents/MCPs
  - **Registry Syntax**: `project_registry: action: sync` (reuse existing syntax)

- **Task 4 - Capability Deployment:**
  - Deploy capabilities for current/next tasks
  - **Registry Syntax**: Reuse new project deployment syntax

- **Task 5 - Context Clear:**
  - **Registry Syntax**: `claude: action: clear_context`

- **Task 6 - User Handoff:**
  - **Registry Syntax**: `claude: action: prompt_and_over_to_user`

**Completion**: Existing project successfully integrated with task-master and capability system operational

# User Experience

- **New Project Bootstrap Flow**:
  1. User declares new project with PRD location (draft or template)
  2. System prompt triggers claude-capability-manager MCP with PRD location + `new_project` indicator
  3. **Step 1 - Project Scaffolding Setup**: Registry-defined workflow execution:
     - Git repository check and cleanup
     - CLAUDE.md backup (preserve existing user configuration)
     - Folder structure creation (.claude/agents/, .claude/hooks/, etc.)
     - File creation (registry template, task-master config, Step 2 system prompt)
     - Project registry population and agent installation
  4. **Step 2 - PRD Iterative Refinement**: Context clear and iterative PRD work:
     - Context clear to load installed agents
     - Specialized prompt injection for PRD refinement
     - Iterative work with research agents, prompt specialists, architects
     - Continue until PRD complete and user confirms readiness
  5. **Step 3 - Task-master Initialization and Execution Setup**: Final system preparation:
     - Task-master initialization with refined PRD
     - Capability requirements generation for each task
     - System prompt replacement and initialization agent cleanup
     - Task 1 execution preparation
     - Final context clear and user handoff
  6. **Completion**: User has full operational system with task-master and dynamic capability management

- **Existing Project Migration Flow**:
  1. User follows README.md use case instructions and declares migration intent with specific entry point
  2. System prompt triggers claude-capability-manager MCP with `existing_project` indicator
  3. **Step 1 - Safety Check & Entry Point Routing**: Preserve existing work and route appropriately:
     - Check .taskmaster/ existence to avoid overwriting
     - Query existing tasks if task-master initialized
     - Route to sub-workflow based on user entry point
  4. **Step 2 - PRD Resolution** (conditional based on entry point):
     - **Sub-workflow A**: Validate/refine existing PRD
     - **Sub-workflow B**: Extract and formalize specs from CLAUDE.md using Claude's natural processing
     - **Sub-workflow C**: Branch to new project PRD creation if no PRD exists
  5. **Step 3 - Task-master Alignment & Capability Deployment**: 
     - Initialize/refresh task-master with validated PRD
     - Generate capability requirements for incomplete tasks
     - Set up project registry and sync with existing setup
     - Deploy capabilities for current work
     - Context clear and user handoff
  6. **Completion**: Existing project integrated with task-master and capability system operational

- **Context Management**:
  - Claude Code and development subagents fetch **summaries first** from Qdrant.
  - Claude-Context provides repo snippets directly.
  - Hydration of full content is explicit, preventing context bloat.

# Technical Architecture

## Authoritative Data Contracts

**Data Contract Evolution:**
- **Tool-Native Migration**: Each tool (Task-master, Qdrant) handles its own schema evolution
- **No Backward Compatibility Requirements**: Accept breaking changes as tools mature
- **Schema Enhancement Welcome**: Embrace beneficial changes (e.g., Task-master assignee field for agent pre-assignment)
- **JSON Flexibility**: Task-master's JSON format naturally accommodates schema changes
- **Mature Tool Stability**: Qdrant schema changes expected to be infrequent due to tool maturity

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

- **768-d (Ollama nomic-embed-text)** - standardized embedding model across all components. **Collection vector size must match.**

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
6. **Embed** via **Ollama** (`nomic-embed-text`, 768-d) - standardized across all components.
7. **Upsert** to Qdrant with the payload contract above.

### QA Architecture

**Claude Debugger MCP**: Complete architecture and workflow specifications in [`claude-debugger-MCP-PRD.md`](./claude-debugger-MCP-PRD.md)

## System Components

- **Claude Code**: Primary supervisor and orchestrator of all development work via parallel subagent execution.
- **MCP Servers**: Task-master, Claude-Context, Qdrant, GitHub, Time, Sequential-Thinking, **Claude Debugger MCP**, and optional project‑specific servers.
- **On-Demand Subagents**: All subagents (Planner, Architect, Development specialists) deployed based on project phase and capability needs.
- **Registry-Based Deployment**: Subagents selected and deployed dynamically from registry based on project capabilities.

## Infrastructure

**Core Services:**
- **Milvus**: Claude-Context semantic search (self-contained, dedicated to code context)
- **Qdrant**: Project memory (local, Docker) - superior ingestion performance and recall for project data
- **Dual Vector Store Rationale**: Milvus required by claude-context (non-negotiable), Qdrant chosen for project memory due to faster ingestion and higher recall metrics
- **Ollama**: Embeddings (nomic-embed-text for Claude-Context + ingest-web)
- **SearxNG**: Search aggregator for ingest-web (local Docker)

**QA Infrastructure:**
- **Gitea/Forgejo**: Self-hosted Git + Issues (GitHub Actions compatible)
- **Kiwi TCMS**: Test campaign and case management  
- **ReportPortal**: Test result analytics and reporting
- **Temporal**: Workflow orchestration (durable, retry logic)
- **Langfuse**: Agent tracing and evaluation

**Port Allocation (localhost):**
- **3000**: Gitea/Forgejo
- **6333/6334**: Qdrant
- **7233**: Temporal  
- **8080**: SearxNG
- **8081**: ReportPortal
- **8082**: Kiwi TCMS
- **11434**: Ollama (default)
- **19530**: Milvus (default)

**Tool Installation Preference:**
1. **Global tools**: `uv tool install <mcp>` or `npm install -g <mcp>`
2. **Docker fallback**: For tools requiring complex dependencies
3. **Update automation**: Manual execution with registry-driven commands

**GitHub Ecosystem Compatibility:**
- Gitea Actions uses GitHub Actions YAML syntax
- Seamless migration path to GitHub workflows
- CI/CD definitions portable between platforms

## Security Architecture

**Security Philosophy**: High risk tolerance with minimal friction - focus on essential protections only.

**Network Security:**
- **Localhost Only**: All services bound to localhost, no external exposure
- **Inbound/Outbound**: External access only from within (ingest-web, git operations)

**Data Protection:**
- **Project Boundary**: Generally stay within project root directory tree (soft rule with exceptions when needed)
- **GitHub Protection**: Enhanced `.gitignore` patterns to prevent accidental sensitive data commits

**Web Content Security (ingest-web-mcp):**
- **URL Filtering**: Block known malicious domains during web scraping
- **Content Validation**: Basic validation of scraped content before ingestion
- **Process Isolation**: Web scraping operations run in isolated process/container

**Community Agent Security:**
- **Agent Files**: Community agents are `.md` files - same security level as system
- **MCP Servers**: Third-party MCPs evaluated via standard due diligence (adoption, popularity, active development)

**Resource Management:**
- **Monitoring Approach**: Monitor resource usage over time, adjust limits as needed
- **No Preemptive Limits**: Avoid friction until actual abuse patterns emerge

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
        "EMBEDDING_MODEL": "nomic-embed-text"
      }
    },
    "claude-context": { "command": "claude-context-mcp" },
    "github": { "command": "github-mcp" },
    "time": { "command": "time-mcp" },
    "debugger-mcp": {
      "command": "debugger-mcp",
      "env": {
        "GITEA_URL": "http://localhost:3000",
        "KIWI_TCMS_URL": "http://localhost:8082",
        "REPORTPORTAL_URL": "http://localhost:8081",
        "TEMPORAL_URL": "localhost:7233"
      }
    }
  },
  "subagents": {
    "planner": { "path": ".claude/agents/planner.md", "phases": ["bootstrap", "prd_revision"], "deployment": "on-demand" },
    "architect": { "path": ".claude/agents/architect.md", "phases": ["bootstrap", "architecture_planning"], "deployment": "on-demand" }
  },
  "bootstrap": {
    "status": "complete",
    "version": "1.0",
    "completed_steps": [1,2,3,4,5,6,7,8,9,10],
    "completed_at": "2025-01-23T10:30:00Z",
    "rollback_available": true,
    "backup_path": ".claude/backups/pre-bootstrap.tar.gz"
  }
}
```

# Development Roadmap

## MVP

- Task-master as task authority with simplified QA task hierarchy.
- Sequential-Thinking → Task-master integration.
- Claude Code orchestrates development subagents, delegates QA to Claude Debugger MCP.
- Claude Debugger MCP with Temporal workflows and specialized tool stack.
- Qdrant integration for project memory, per-project collections.
- Ingest-web modified to push into Qdrant via SearxNG.
- Registry-driven `.claude/project.json` bootstrap script.
- Debugger MCP as thin layer over Gitea + Kiwi TCMS + ReportPortal + Temporal.
- Update automation via manual execution with registry-driven commands.

## Future Enhancements

- Add rerankers (e.g., bge-reranker) to Qdrant search.
- Extend bootstrap to support per-project overrides (`project.profile.json`).
- Automated GitHub issue mirroring from Task-master.
- UI/dashboard for monitoring tasks + memory + QA results.

# Development Phases

## Subagent Mapping Summary

**From `awesome-claude-code-subagents` collection:**

**Phase 1 (Immediate):**
- `git-workflow-manager` (06-developer-experience) - Repository structure, submodule setup
- `mcp-developer` (06-developer-experience) - MCP protocol, Qdrant integration  
- `research-analyst` (10-research-analysis) - claude-context investigation

**Phase 2:**
- `data-engineer` (05-data-ai) - Pipeline architecture, ingestion systems
- `mcp-developer` (reuse) - ingest-web-mcp adaptation

**Phase 3:**
- `research-analyst` (reuse) - task-master codebase analysis
- `mcp-developer` (reuse) - claude-capability-manager MCP development
- `python-pro` (02-language-specialists) - Python automation, SDK integration

**Phase 4:**
- `qa-expert` (04-quality-security) - Test strategy, campaign design
- `mcp-developer` (reuse) - Claude Debugger MCP development
- `devops-engineer` (03-infrastructure) - QA infrastructure deployment

**Phase 5:**
- `prompt-engineer` (05-data-ai) - Agent customization, adaptation
- `python-pro` (reuse) - Automation pipeline
- `mcp-developer` (reuse) - Integration patterns

**Total Unique Agents Needed: 7**
- Core: `mcp-developer` (used across all phases)
- Specialized: `git-workflow-manager`, `research-analyst`, `data-engineer`, `python-pro`, `qa-expert`, `devops-engineer`

## Phase 1: Project Foundation & Infrastructure Setup
**Goal**: Establish project structure and core infrastructure

**Recommended Subagents**:
- `mcp-developer`: MCP protocol analysis, Qdrant MCP integration, custom MCP development  
- `research-analyst`: claude-context codebase investigation, feasibility analysis

1. **Qdrant MCP Installation**:
   - Install and deploy Qdrant + Qdrant-MCP for project memory (`mcp-developer`)
   - Establish Qdrant as unified vector store foundation
   - Verify integration with Claude Code MCP ecosystem

2. **De-dockerization Opportunities**:
   - Identify components that can be simplified from Docker to native installation
   - Evaluate performance and maintenance benefits

3. **Task-master Integration Investigation** (Expanded into 4 tasks):
   - **NOTE**: Task-master is already deployed and working well - this is analysis only
   
   **3.1 Task-master Strategy and Implementation Analysis** (`research-analyst`):
   - Understanding the strategy behind Task-master architecture
   - Deep dive into MCP server implementation logic
   - Analysis of CLI interface and command patterns
   - Investigation of Claude Code integration patterns
   - **Goal**: Comprehensive understanding of Task-master's approach
   
   **3.2 MCP Standard Inter-Server Communication Research** (`research-analyst`):
   - Investigate if MCP standard allows direct server-to-server communication
   - Research MCP protocol for server discovery and communication patterns
   - Evaluate feasibility of claude-capability-manager MCP talking directly to task-master MCP
   - **Goal**: Determine if MCP-to-MCP communication is possible/standardized
   
   **3.3 Direct Integration with Task-master Investigation** (`mcp-developer`):
   - How to integrate directly with task-master JavaScript codebase
   - CI setup to detect breaking changes in task-master repository
   - Unit test strategy to validate integration stability over time
   - Automated monitoring of task-master repository changes
   - **Goal**: Direct integration approach evaluation and monitoring strategy
   
   **3.4 Python-JavaScript Integration via Shims** (`mcp-developer`):
   - Explore shim layer between Python (claude-capability-manager) and JavaScript (task-master)
   - Investigate interop patterns and best practices
   - Evaluate performance and maintenance implications of bridge solutions
   - Research Node.js/Python bridge solutions and tooling
   - **Goal**: Determine if shim-based integration is viable approach
   
   **Integration Decision**: Phase 1 investigation will resolve task-master integration approach by evaluating CLI, MCP-to-MCP, direct integration, and shim-based approaches

4. **FastMCP Framework Ingestion**:
   - Ingest and memorize FastMCP Python library documentation (`research-analyst`)
   - **Source**: https://github.com/jlowin/fastmcp
   - Store comprehensive API documentation, patterns, and implementation examples in Qdrant
   - **Goal**: Foundation knowledge for MCP development using FastMCP framework

5. **Claude Code SDK Ingestion**:
   - Ingest and memorize Anthropic Claude Code SDK documentation (`research-analyst`)
   - **Source**: https://docs.anthropic.com/en/docs/claude-code/sdk
   - Store API references, integration patterns, context management, and MCP lifecycle documentation in Qdrant
   - **Goal**: Foundation knowledge for Claude Code integration and context management APIs

6. **Task-master CLI Documentation Ingestion**:
   - Ingest and memorize Task-master CLI commands and integration patterns (`research-analyst`)
   - **Source**: https://docs.task-master.dev/introduction
   - Store CLI command reference, PRD parsing capabilities, and task management APIs in Qdrant
   - **Goal**: Foundation knowledge for Task-master CLI integration in claude-capability-manager MCP

## Phase 2: Memory & Research Enhancement
**Goal**: Add project memory and web research capabilities

**Recommended Subagents**:
- `data-engineer`: Pipeline architecture, ETL design, ingestion optimization
- `mcp-developer`: ingest-web-mcp adaptation, integration patterns

1. **Memory System**:
   - Per-project Qdrant collections (`data-engineer`)
   - Project-specific memory schemas and contracts

2. **Research Integration**:
   - Adapt ingest-web-mcp for Qdrant integration (`mcp-developer` + `data-engineer`)
   - SearxNG setup and integration (`data-engineer`)
   - Web content ingestion pipeline (`data-engineer`)

## Phase 3: Capability Management System
**Goal**: Dynamic MCP and agent management

**Recommended Subagents**:
- `research-analyst`: task-master codebase analysis, pattern identification
- `mcp-developer`: claude-capability-manager MCP development, protocol implementation
- `python-pro`: Python SDK integration, automation scripts

1. **claude-capability-manager MCP Development**:
   - Apply Task-master codebase analysis learnings from Phase 1 (`research-analyst`)
   - Build capability detection and deployment system (`mcp-developer`)
   - Registry-driven project bootstrap (`python-pro`)

2. **Agent Ecosystem Foundation**:
   - Project-specific subagent deployment (`mcp-developer`)
   - Phase-based agent activation

## Phase 4: QA Orchestration & Testing
**Goal**: Sophisticated testing workflows

**Recommended Subagents**:
- `qa-expert`: Test strategy design, campaign planning, quality metrics
- `mcp-developer`: Claude Debugger MCP development, Temporal integration
- `devops-engineer`: QA infrastructure setup, service orchestration

1. **Claude Debugger MCP**:
   - Temporal workflow orchestration (`mcp-developer`)
   - Campaign-based testing system (`qa-expert`)

2. **QA Infrastructure**:
   - Gitea + Kiwi TCMS + ReportPortal integration (`devops-engineer`)
   - Bug lifecycle management (`qa-expert`)

## Phase 5: Advanced Agent Integration
**Goal**: Community agent ecosystem

**Recommended Subagents**:
- `prompt-engineer`: Agent customization, adaptation strategies
- `python-pro`: Automation pipeline, registry management
- `mcp-developer`: MCP dependency resolution, integration patterns

1. **Agent Customization Pipeline**:
   - 100+ community agent integration (`prompt-engineer`)
   - Automated agent adaptation system (`python-pro`)
   - Advanced registry features (`mcp-developer`)

# Risks and Mitigations

- **Task coordination complexity** → mitigated by Claude Code acting as supervisor with clear subagent orchestration.
- **Context bloat** → mitigated by summary-first retrieval in Qdrant.
- **Embedding quality tradeoffs** → standardized on Ollama nomic-embed-text (768-d) across all components.
- **Complexity in per-project configs** → mitigated with bootstrap script and registry-driven rules.
- **QA pipeline failures** → mitigated by Claude Debugger MCP with progressive testing, smart circuit breaking, container isolation, and operational safeguards.
- **QA tooling complexity** → accepted tradeoff for preventing Task-master context drift and ensuring campaign completion (validated by experimentation).

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

**Note**: Claude Debugger MCP is a self-contained MCP server (like task-master) and does not require a separate global subagent definition. It may use internal subagents for workflow orchestration, but these are managed within the MCP itself.

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
        "EMBEDDING_MODEL": "nomic-embed-text"
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
        q.recreate_collection(col, vectors=VectorParams(size=768, distance=Distance.COSINE))
    print("Qdrant collection ready:", col)
except Exception as e:
    print("(Optional) qdrant-client not installed:", e)
```

## Qdrant Upsert with Ollama (768-d)

```python
import ollama
from qdrant_client import QdrantClient
from qdrant_client.http.models import PointStruct

client = QdrantClient(url="http://localhost:6333")
texts = ["Algorithm draft", "UI design note"]
vectors = []
for text in texts:
    response = ollama.embeddings(model="nomic-embed-text", prompt=text)
    vectors.append(response["embedding"])

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
- New projects: Capability collection only (no Qdrant data expected)
- Existing projects: Code exploration + tool initialization + Qdrant memory review
- Collect required capabilities from PRD

**Phase 3: Bootstrap & Planning**
1. Pass capabilities to bootstrap MCP for capability installation
2. Initialize project with task-master, claude-context, serena
3. Create task plan in task-master
4. Final task: "Plan testing campaign, confirm with user, update task-master"

**claude-capability-manager MCP**: Detailed specifications in [`mcp/claude-capability-manager/PRD.md`](./mcp/claude-capability-manager/PRD.md)

## Task-Capability Binding Architecture

**Current Status**: Architecture deferred pending Phase 1 Task-master investigation

**Research Questions**:
- Task-master MCP integration capabilities: https://github.com/eyaltoledano/claude-task-master/blob/main/context/MCP_INTEGRATION.md
- Canonical task schema validation and extension mechanisms
- Custom field support vs. structured content in existing fields

**Resolution Path**: Phase 1 Task-master Internal Architecture Analysis will investigate schema flexibility and provide architectural recommendations for storing capability requirements alongside tasks.

# System Prompt Suggestions

- **Task separation**
  "Task creation follows strict hierarchy: Sequential-Thinking (bootstrap), Claude Debugger MCP (test failures), Planner Subagent (PRD revisions). Claude Code supervises development subagents but never creates tasks - coordinates execution only and reports status back to Task-master."

- **Statuses & dependencies**
  “Use only the canonical statuses: `pending`, `done`, `deferred`. Model blocking exclusively via `dependencies`. Treat work‑in‑progress as `pending` and log progress in `details` with time‑stamped notes.”

- **Retrieval discipline**
  “Always retrieve **summaries first** from Qdrant and hydrate full content only when necessary. Keep context tight; avoid large blobs without explicit user confirmation.”

- **Code retrieval**
  “All code snippets and cross‑references must come through **Claude‑Context‑MCP**. Do not attempt to reindex code elsewhere.”

- **Traceability**
  “Reference Task IDs (e.g., `8`, `8.1`) in commits, PR titles, Qdrant `related_task_ids`, and ADRs.”

- **Role boundaries**  
  "Claude Code: supervisor and orchestrator. Development Subagents: build, fix, refactor under supervision. Claude Debugger MCP: testing workflows via Temporal. Clear handoff at QA task delegation."

- **QA workflow hierarchy**
  "Use simplified task structure: campaign → fix task → bug subtasks. Bugs tracked in Gitea Issues with detailed lifecycle, subtasks for work items."

- **State-as-data principle**
  "All QA state in systems, not prompts: campaigns in Kiwi TCMS, results in ReportPortal, bugs in Gitea Issues, workflows in Temporal."

- **Error handling**
  "On any MCP failure, retry once with exponential backoff; if still failing, surface a concise error with the tool name and attempted parameters, then propose a fallback."

