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

### Project Structure

```
project/
├── CLAUDE_SYSTEM.md     # Shared system instructions (immutable)
├── CLAUDE.md            # This file - project tracking
├── PRD.md               # Project requirements
├── ALGO.md              # Algorithm repository
├── src/                 # Source code
├── tests/               # Test files
└── docs/                # Documentation
```

## TRACKING

### Active Todo

```markdown
- [ ] Task 1: Description
  - [ ] Make change
  - [ ] Commit change
  - [ ] Test change
  - [ ] Commit test
- [ ] Task 2: Description
  - [ ] Make change
  - [ ] Commit change
```

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

### Temporary Files

```markdown
- [ ] /path/to/temp/file - Purpose (delete after task X)
```
