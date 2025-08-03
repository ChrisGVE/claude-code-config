========================================
FILE: README.md
(Documentation for the system)
========================================

# Claude Code Prompt System

This directory contains the optimized prompt system for Claude Code with a focus on efficiency, clarity, and strict boundaries.

## Core Principles

### 1. Commit Discipline

**EVERY change gets committed immediately**

- One logical change = One commit
- No batching changes
- Commit before moving to next task
- Target: Commit every 5-10 minutes

### 2. Decision Boundaries

**NEVER make decisions for the user**

- Always ask about scope
- Get explicit tolerances
- Confirm test coverage
- Present options, don't choose

## Files Overview

### System Files

- **CLAUDE_SYSTEM_PROMPT.md** - The main system prompt to place in ~/.claude/
- **CLAUDE_SYSTEM.md** - Shared instructions for all projects (place in project root)

### Template Files

- **CLAUDE.md.template** - Project tracking file template
- **PRD.md.template** - Product Requirements Document template
- **ALGO.md.template** - Algorithm repository template

## Setup Instructions

### 1. System Prompt Setup

```bash
# Copy the system prompt to Claude's config directory
cp CLAUDE_SYSTEM_PROMPT.md ~/.claude/CLAUDE.md
```

### 2. New Project Setup

```bash
# In your project root:
cp /path/to/prompts/CLAUDE_SYSTEM.md .
cp /path/to/prompts/CLAUDE.md.template CLAUDE.md
cp /path/to/prompts/PRD.md.template PRD.md
cp /path/to/prompts/ALGO.md.template ALGO.md

# Initialize git if not already done
git init
git add .
git commit -m "chore: Initial project setup with Claude system"
```

## The Commit Loop

This is the core workflow:

```
REPEAT:
  1. Make ONE atomic change
  2. Test that specific change
  3. Commit IMMEDIATELY
  4. Move to next change
```

**Good commit pattern:**

```bash
09:00 feat: Add user model class
09:05 test: Add user model validation tests
09:08 fix: Handle none in user email field
09:12 docs: Add user model docstrings
09:15 refactor: Extract email validation
```

**Bad pattern:**

```bash
09:00 feat: Add complete user system  # Too much in one commit!
```

## Decision Points

### Always Ask The User About:

1. **Testing Scope**
   - "What should I test?"
   - "Which edge cases matter?"
   - "What's the coverage target?"

2. **Performance**
   - "What's acceptable response time?"
   - "Memory constraints?"
   - "Should I optimize?"

3. **Implementation**
   - "Process all data or sample?"
   - "Fail fast or collect errors?"
   - "Which approach do you prefer?"

### Never Assume:

- ❌ "This is probably good enough"
- ❌ "I'll just test the happy path"
- ❌ "Performance doesn't matter here"
- ❌ "I'll sample to save time"

### Always Ask:

- ✅ "What's your definition of good enough?"
- ✅ "What specific cases should I test?"
- ✅ "What performance criteria must be met?"
- ✅ "Should I process everything or would you prefer sampling?"

## Progress Tracking

Track progress through git, not logs:

```bash
# See your commit frequency
git log --since="1 hour ago" --oneline

# Verify atomic commits
git log --stat -5

# Check time between commits
git log --format="%ar %s" -10
```

## Best Practices

1. **One Change, One Commit** - No exceptions
2. **Ask, Don't Assume** - Every decision point
3. **Test to Spec** - Not your interpretation
4. **Clean Status** - Git status clean before next task
5. **Document Decisions** - In PRD.md decision log

Remember: "The mark of wisdom is not how much you add, but how precisely you can target what needs changing."
