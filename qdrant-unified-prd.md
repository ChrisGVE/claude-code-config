# Qdrant Unified System PRD

**Version:** 1.0  
**Date:** 2025-08-26  
**Status:** Draft

## Executive Summary

This PRD defines the replacement of claude-context MCP and Milvus with a unified Qdrant-based system for code indexing, project memory, and knowledge management. The new architecture features a daemon process for continuous indexing and an MCP for search/control, providing superior performance, simpler infrastructure, and better integration with Claude Code.

## Architectural Changes

### Components Being Removed
- **claude-context MCP**: Entire component and its Milvus dependency
- **Milvus**: Vector database (port 19530)
- **Separate ingestion paths**: Consolidate all ingestion through single daemon

### Components Being Added
- **project-code-daemon**: Rust daemon for indexing and ingestion (launchctl/systemd managed)
- **project-code-mcp**: MCP server for search and daemon control
- **Unified Qdrant storage**: Single vector store for all project knowledge

### Components Being Modified
- **ingest-web-mcp**: Redirect to use daemon as entry point instead of direct Qdrant writes
- **Task-master integration**: Update to reference new search tools
- **System prompts**: Update to use new MCP tools instead of claude-context

## System Architecture

```
┌─────────────────┐
│  Claude Code    │
└────────┬────────┘
         │ stdio/TCP
         v
┌─────────────────────┐     HTTP/Unix Socket    ┌──────────────────────┐
│  project-code-mcp   │ <---------------------> │ project-code-daemon  │
│  (Search & Control) │                         │ (Indexing & Ingest)  │
└─────────────────────┘                         └──────────┬───────────┘
         ^                                                  │
         │                                                  │ REST/gRPC
         │                                                  v
         │                                          ┌──────────────┐
         └──────────────────────────────────────────┤   Qdrant     │
                        Search Results              └──────────────┘
```

## Core Features

### 1. Project-Code Daemon

**Purpose**: Always-available background service for indexing and ingestion

**Responsibilities**:
- Watch project directories for changes
- Index code with language-aware chunking
- Generate dense + sparse embeddings
- Manage Qdrant collections and schemas
- Handle document ingestion (PDF, markdown, text)
- Process web content from ingest requests
- Maintain project registry of active projects

**Lifecycle**:
- Launch: Via launchctl (macOS) / systemd (Linux) at system startup
- Activation: MCP sends project_root on session start
- Operation: Watch files, debounce, batch index
- Deactivation: MCP signals session end, daemon sleeps (minimal resources)

**Key Features**:
- Git-aware ignore patterns
- Stable chunk IDs for idempotent updates
- Delete-by-filter for file removals
- Symbol-aligned chunking when possible
- Multi-project support with isolated collections

### 2. Project-Code MCP

**Purpose**: Thin control and search interface for Claude Code

**Tools Exposed**:
- `activate(project_root)`: Start watching a project
- `deactivate(project_root)`: Stop watching, release resources
- `search(query, mode, scope)`: Semantic/hybrid search
- `index_all()`: Force full reindex
- `reindex(paths)`: Targeted reindex of specific files
- `purge(paths)`: Remove specific paths from index
- `status()`: Get daemon health and indexing stats
- `list_collections()`: Show available project collections
- `ingest_document(path)`: Index local documents
- `ingest_web(url)`: Index web content

**Session Hooks**:
- On start: Activate current project_root
- On exit: Deactivate to free resources

**Search Modes**:
- Dense-only (semantic)
- Sparse-only (lexical/exact)
- Hybrid (recommended default with RRF fusion)
- Optional reranking for precision

### 3. Collection Strategy

**Per-Project Collections**:
- `{project-name}-code`: Source code chunks
- `{project-name}-docs`: Local documentation
- `{project-name}-web`: Ingested web content
- `{project-name}-memory`: Project decisions/algorithms (from existing Qdrant MCP)

**Schema (Named Vectors)**:
- `dense`: 384-dim (all-MiniLM-L6-v2) or 768-dim (nomic-embed-text)
- `sparse`: BM25 or SPLADE term weights

**Payload Fields**:
```json
{
  "repo": "project-name",
  "module": "root|submodule-name",
  "path": "relative/path/to/file",
  "lang": "python|rust|js|...",
  "type": "code|doc|web",
  "chunk_type": "function|class|block",
  "sym": "function_name",
  "range": {"start": [line, col], "end": [line, col]},
  "content": "actual text content",
  "hash": "sha256-of-content",
  "indexed_at": "2025-01-26T10:00:00Z"
}
```

## Migration Strategy

### Phase 1: Parallel Operation (Week 1-2)
1. Deploy project-code-daemon alongside existing claude-context
2. Index projects into Qdrant while claude-context still operates
3. Implement project-code-mcp with basic search tools
4. Test search quality and performance in parallel

### Phase 2: Feature Parity (Week 2-3)
1. Implement remaining MCP tools (reindex, purge, status)
2. Add document and web ingestion to daemon
3. Modify ingest-web-mcp to use daemon API
4. Validate feature completeness

### Phase 3: Cutover (Week 3-4)
1. Update system prompts to use project-code-mcp
2. Update task-master references
3. Disable claude-context in MCP config
4. Monitor for issues, keep claude-context available for rollback

### Phase 4: Cleanup (Week 4+)
1. Remove claude-context from project
2. Shutdown and remove Milvus
3. Document new architecture
4. Archive migration artifacts

## Implementation Plan

### Milestone 1: Daemon Core (Days 1-5)
- [ ] Rust project setup with tokio async runtime
- [ ] HTTP API server (activate/deactivate/status)
- [ ] File watcher with git-aware ignores
- [ ] Basic chunking (sliding window)
- [ ] Qdrant client integration
- [ ] Collection creation with named vectors

### Milestone 2: Embeddings & Indexing (Days 5-10)
- [ ] Dense embeddings via FastEmbed or Candle
- [ ] Sparse vectors (BM25 implementation)
- [ ] Batch upsert with stable IDs
- [ ] Delete-by-filter for removals
- [ ] Debouncing and batching logic

### Milestone 3: MCP Server (Days 10-15)
- [ ] Python MCP using FastMCP
- [ ] Core tools: activate, deactivate, search
- [ ] Session lifecycle hooks
- [ ] Hybrid search with RRF fusion
- [ ] Multi-collection scoping

### Milestone 4: Advanced Features (Days 15-20)
- [ ] Document ingestion (PDF, markdown)
- [ ] Web content ingestion API
- [ ] Symbol-aligned chunking (optional)
- [ ] Reranking support
- [ ] Performance optimizations

### Milestone 5: Integration (Days 20-25)
- [ ] Modify ingest-web-mcp
- [ ] Update system prompts
- [ ] Migration scripts
- [ ] Testing and validation
- [ ] Documentation

## Configuration

### Daemon Configuration (`~/.config/project-code/daemon.yaml`)
```yaml
daemon:
  listen: "127.0.0.1:8090"
  unix_socket: "/tmp/project-code-daemon.sock"
  data_dir: "~/.local/share/project-code"
  log_level: "info"
  
indexing:
  debounce_ms: 500
  batch_size: 100
  max_chunk_size: 1500
  chunk_overlap: 200
  ignore_patterns:
    - "*.pyc"
    - "__pycache__"
    - "node_modules"
    - ".git"
    
embedding:
  dense_model: "all-MiniLM-L6-v2"
  sparse_method: "bm25"
  device: "cpu"
  
qdrant:
  url: "http://127.0.0.1:6333"
  api_key: null
```

### MCP Configuration (`.claude/project.json`)
```json
{
  "mcpServers": {
    "project-code": {
      "command": "uvx",
      "args": ["project-code-mcp"],
      "env": {
        "DAEMON_URL": "http://127.0.0.1:8090",
        "PROJECT_ROOT": "${PWD}"
      }
    }
  }
}
```

### LaunchAgent (`~/Library/LaunchAgents/com.project-code.daemon.plist`)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" 
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.project-code.daemon</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/project-code-daemon</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>/tmp/project-code-daemon.err</string>
    <key>StandardOutPath</key>
    <string>/tmp/project-code-daemon.out</string>
</dict>
</plist>
```

## Performance Targets

Based on existing architecture documents:

- **Search latency**: P95 ≤ 120ms (hybrid), ≤ 350ms (with rerank)
- **Indexing throughput**: ≥ 300 chunks/sec (dense), ≥ 150 chunks/sec (hybrid)
- **Save-to-search visibility**: ≤ 2 seconds
- **Daemon memory**: ≤ 200MB RSS when idle
- **Search quality**: ≥ 0.7 nDCG@10 on evaluation set

## Security Considerations

- Daemon binds to localhost only
- Optional API token for daemon access
- Unix socket option for enhanced security
- PII-safe logging (no content, only metadata)
- Respect .gitignore and custom exclude patterns

## Testing Strategy

### Unit Tests
- Chunk boundary calculation
- ID stability across re-chunks
- Embedding dimension validation
- Payload schema compliance

### Integration Tests
- Index → search roundtrip
- File rename/delete handling
- Multi-collection federation
- Session lifecycle

### Performance Tests
- 100k+ chunk collections
- Concurrent index + search
- Memory leak detection
- CPU usage profiling

### Comparison Tests
- Search quality vs claude-context
- Indexing speed comparison
- Resource usage comparison
- Feature parity validation

## Success Criteria

1. **Feature Parity**: All claude-context search capabilities available
2. **Performance**: Meet or exceed all performance targets
3. **Reliability**: 7+ day daemon uptime without memory leaks
4. **Migration**: Zero-downtime cutover from claude-context
5. **Simplification**: Single vector store instead of two
6. **Integration**: Seamless with existing task-master and prompts

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Search quality regression | High | Parallel operation period with A/B testing |
| Daemon instability | High | Comprehensive testing, gradual rollout |
| Migration data loss | Medium | Full backups, rollback plan |
| Performance degradation | Medium | Profiling, optimization, caching |
| Integration issues | Low | Maintain compatibility layer during transition |

## Future Enhancements

1. **GPU acceleration** for embeddings
2. **Multi-vector/ColBERT** models for better search
3. **LSP integration** for precise incremental updates
4. **Distributed daemon** for large teams
5. **Cloud sync** for remote development
6. **Advanced rerankers** (cross-encoder models)

## Decisions Required

1. **Embedding model**: all-MiniLM-L6-v2 (384d) vs nomic-embed-text (768d)?
   - Recommendation: Start with MiniLM for speed, upgrade path to nomic
   
2. **Sparse method**: BM25 (fast) vs SPLADE (better quality)?
   - Recommendation: BM25 initially, SPLADE as enhancement
   
3. **Daemon language**: Rust (performance) vs Python (faster development)?
   - Recommendation: Rust for production quality
   
4. **MCP framework**: FastMCP (Python) vs custom?
   - Recommendation: FastMCP for rapid development

## Appendix: API Specifications

### Daemon HTTP API

```
POST /activate
Body: {"project_root": "/path/to/project"}
Response: {"status": "activated", "collection": "project-name-code"}

POST /deactivate  
Body: {"project_root": "/path/to/project"}
Response: {"status": "deactivated"}

GET /status
Response: {"projects": [...], "stats": {...}}

POST /reindex
Body: {"project_root": "...", "paths": ["src/main.rs"]}
Response: {"indexed": 45, "deleted": 2}

POST /ingest/document
Body: {"path": "/path/to/doc.pdf", "collection": "project-docs"}
Response: {"chunks": 23, "status": "success"}

POST /ingest/web
Body: {"url": "https://...", "collection": "project-web"}
Response: {"chunks": 15, "status": "success"}
```

### MCP Tool Schemas

```typescript
interface SearchTool {
  name: "search_code";
  parameters: {
    query: string;
    mode?: "dense" | "sparse" | "hybrid";
    scope?: string[];  // collection names
    limit?: number;
    rerank?: boolean;
  };
  returns: {
    results: Array<{
      path: string;
      content: string;
      score: number;
      metadata: Record<string, any>;
    }>;
  };
}
```

## Conclusion

This unified Qdrant-based system eliminates the complexity of maintaining two vector databases, provides better control over indexing, and offers superior performance through purpose-built architecture. The migration path ensures zero disruption while the modular design allows for future enhancements without architectural changes.