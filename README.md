# Claude Code Configuration

This repository contains centralized configuration for Claude Code and related MCP tools.

## Configuration Wiring

- `claude.json` (root) → `~/.claude.json` (symlink)
- `claude/` (root) → `~/.claude/` (symlink)
- Setup script: `scripts/setup-links.sh`

## Structure

- `claude/` - Claude Code configuration files
- `mcp/` - MCP server configurations and tools
- `config/` - Additional configuration files
- `persistent_memory/` - Local memory storage (git-ignored)
- `prompts/` - System and project prompts
- `scripts/` - Setup and utility scripts

## MCP Tools

- Claude Context MCP
- Task Master MCP  
- Memory MCP
- Ingest Web MCP
- Local Data MCP
- Qdrant vector database

Data storage directories (memory/milvus/qdrant) are excluded from git.