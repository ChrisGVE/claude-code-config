========================================
FILE: CLAUDE.md.template
(Template for project tracking)
========================================

# CLAUDE.md

## SYSTEM RULES

See CLAUDE_SYSTEM.md for core directives and workflow.

## PROJECT CONTEXT

### Current Focus

[What you're actively working on RIGHT NOW]

### Outstanding Decisions Needed

- [ ] Decision 1: [What needs to be decided]
- [ ] Decision 2: [What needs to be decided]

### Unconfirmed Assumptions

- [ ] Assumption 1: [State assumption - awaiting confirmation]
- [ ] Assumption 2: [State assumption - awaiting confirmation]

### Project Structure

```
project/
├── CLAUDE_SYSTEM.md     # Shared system instructions (immutable)
├── CLAUDE.md            # This file - project tracking
├── PRD.txt              # Project requirements (parse with task-master)
├── ALGO.md              # Algorithm repository (ALL algorithms MUST be here)
├── src/                 # Source code
├── tests/               # Test files
└── docs/                # Documentation
```

### MCP Tool Status

- [ ] Serena initial instructions read
- [ ] Claude-context codebase indexed
- [ ] Task-master tasks generated from PRD
- [ ] Algorithms loaded from memory/ALGO.md
- [ ] GitHub repository connected (if applicable)

## TRACKING

### Task Management

**Use `task-master` for ALL task tracking - NO separate todo lists here**

- View tasks: `task-master get_tasks`
- Add task: `task-master add_task`
- Update status: `task-master set_task_status`
- For each task: Use `sequential-thinking` to break it down

### Active Sub-Agents

| Agent Type | Task | Status | Commit Instructions |
| ---------- | ---- | ------ | ------------------- |
| [type]     | [task] | [status] | Atomic commits required |

### Commit Checklist

Before moving to next task:

- [ ] Git status is clean
- [ ] Last commit was < 10 minutes ago
- [ ] Each logical change has its own commit

### Git Progress

```bash
# Verify granular commits:
git log --oneline -10

# Today's commit frequency:
git log --since="6am" --format="%h %s [%ar]"

# Check working state:
git status
```

### Active Branches

| Branch | Purpose            | Started | Last Commit |
| ------ | ------------------ | ------- | ----------- |
| main   | Stable releases    | -       | -           |
| dev    | Active development | -       | -           |

### Test Specifications

(As provided by user)

- Coverage requirements: [User specified]
- Performance criteria: [User specified]
- Edge cases to handle: [User specified]

### Memory Registry

| Tag | Description | Last Updated |
| --- | ----------- | ------------ |
|     |             |              |

### Algorithm Registry (MUST match ALGO.md)

| Algorithm | Memory Tag | Description | Status |
| --------- | ---------- | ----------- | ------ |
| [name]    | [tag]      | [brief desc] | [stored/pending] |

### Temporary Files

```markdown
- [ ] /path/to/temp/file - Purpose (delete after task X)
```
