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

## Research Findings: Existing MCP Options Analysis

> **💡 Research Note**: This section documents comprehensive analysis of existing MCP servers for Qdrant integration, conducted to evaluate build-vs-buy decisions before custom development.

### Multi-Collection MCP Investigation

**Problem Statement**: Official Qdrant MCP is single-collection only. Multiple instances create context bloat (each adds `qdrant-store`, `qdrant-find` tools).

**Key Finding**: **No existing single MCP server** supports multiple Qdrant collections with startup configuration.

**Analyzed Options**:
- `@modelcontextprotocol/server-memory` - JSON-backed knowledge graph (not Qdrant-based)
- `rajasami156/Qdrant-Langchain-Multiple-Collections` - LangChain script, no MCP interface
- **Trade-off identified**: Context bloat vs custom development risk

### Cross-Collection Search MCP Investigation  

**Evaluated Options**:

1. **AI Federation Network MCP** ❌ 
   - **Issue**: Doesn't support Qdrant (irrelevant to search)
   - **Additional concerns**: Enterprise-grade complexity for local use case

2. **Community Qdrant MCP Servers** 🔍
   - **Qdrant Retrieve MCP**: https://github.com/gergelyszerovay/mcp-server-qdrant-retrieve
   - **MCP Qdrant Memory**: https://github.com/delorenj/mcp-qdrant-memory  
   - **Better Qdrant MCP**: https://github.com/wrediam/better-qdrant-mcp-server
   - **Claude Qdrant MCP**: https://github.com/marlian/claude-qdrant-mcp

3. **Related Tools/References**:
   - **CrewAI Qdrant Tool**: https://docs.crewai.com/en/tools/database-data/qdrantvectorsearchtool
   - **LangChain Qdrant Integration**: https://python.langchain.com/docs/integrations/vectorstores/qdrant/

**Status**: ✅ **COMPLETED** - Detailed evaluation completed 2025-08-27

### Community MCP Server Analysis Results

#### 1. Qdrant Retrieve MCP (gergelyszerovay) ⭐ **BEST CANDIDATE**
- ✅ **Native multi-collection support** - searches across multiple collections
- ✅ **Cross-collection search** with result source tracking
- ✅ **Configurable embedding models** (not locked to single provider)
- ✅ **Mature architecture** with comprehensive CLI and config options
- ✅ **Result metadata** includes collection source, scores, original queries
- ❌ **Limitation**: Read-only (no write/upsert capabilities)

#### 2. Claude Qdrant MCP (marlian) 🔶 **SECOND CHOICE**
- ✅ **Multi-client isolation** via separate collections per client
- ✅ **Local AI processing** with LM Studio integration  
- ✅ **Dual collection pattern** (catalog + chunks)
- ✅ **SHA256 deduplication** and batch processing
- ❌ **Limitation**: Client-focused, not project-focused architecture
- ❌ **Complex dependencies** (LM Studio, BGE-M3, Qwen3-8B)

#### 3. Better Qdrant MCP (wrediam) 🔶 **ALTERNATIVE**
- ✅ **Multiple embedding services** (OpenAI, Ollama, FastEmbed)
- ✅ **Document management** with chunking control
- ✅ **Collection management** (create/delete/list)
- ❌ **Limitation**: Single collection focus in search operations
- ❌ **Node.js dependency** vs our Python/Rust preference

#### 4. MCP Qdrant Memory (delorenj) ❌ **NOT SUITABLE**
- ✅ **Knowledge graph approach** with dual persistence
- ❌ **Single collection limitation** 
- ❌ **OpenAI dependency** for embeddings
- ❌ **Memory-focused**, not code-indexing focused

### Implementation Strategy: HYBRID APPROACH ✅

**Final Architecture Decision**:

1. **Multi-Collection Read Access**: 
   - **FORK/EXTEND** Qdrant Retrieve MCP as foundation
   - Add write capabilities (upsert, delete) to existing read-only framework
   - Leverage proven multi-collection search architecture

2. **Daemon Development**: 
   - **PROCEED** with custom memexd daemon as planned
   - No existing daemon alternatives found
   - Use Qdrant Retrieve MCP patterns for collection management

3. **Integration Pattern**:
   - **memexd daemon**: Handles indexing, file watching, embedding generation  
   - **Enhanced Qdrant Retrieve MCP**: Handles multi-collection search and basic CRUD
   - **Daemon Control MCP**: Separate lightweight MCP for daemon start/stop/status

### Risk Mitigation Strategy

**Reduced Development Risk**:
- ✅ **Proven multi-collection search** from Qdrant Retrieve MCP
- ✅ **Existing embedding flexibility** patterns from Better Qdrant MCP  
- ✅ **Collection isolation** patterns from Claude Qdrant MCP
- ✅ **Custom daemon only** for indexing pipeline (core competency area)

**Technical Validation**:
- Multi-collection search capabilities **CONFIRMED** in production code
- Embedding model flexibility **CONFIRMED** across multiple implementations  
- MCP tool patterns **ESTABLISHED** and proven

## Final Tool Specifications

Based on community MCP analysis, the system will consist of **three distinct tools**:

### 1. memexd - Semantic Code Indexing Daemon 🦾 **CUSTOM BUILD**

**Purpose**: Always-available background service for project-specific code indexing

**Core Capabilities**:
- File watching with git-aware ignores and debouncing
- Language-aware chunking (sliding window + symbol-aligned when possible)
- Dense + sparse embedding generation (all-MiniLM-L6-v2 + BM25)
- Batch upsert with stable IDs and idempotent updates
- Per-project collection management with isolation

**API Surface** (HTTP + Unix Socket):
```
POST /activate     - Start watching project
POST /deactivate   - Stop watching, release resources  
GET  /status       - Health, stats, active projects
POST /reindex      - Force full or partial reindex
POST /purge        - Remove paths from index
```

**Lifecycle**: launchctl/systemd managed, dormant when no active projects

### 2. qdrant-multi-mcp - Multi-Collection Search Server 🔍 **FORK & EXTEND**

**Base**: Fork of `mcp-server-qdrant-retrieve` (gergelyszerovay)

**Enhancements to Add**:
- ✅ **Keep existing**: Multi-collection search, result source tracking
- ➕ **Add write operations**: `upsert_points`, `delete_points`, `create_collection`
- ➕ **Add daemon integration**: Forward write operations to memexd when available
- ➕ **Add FastEmbed support**: Local embedding generation option
- ➕ **Add hybrid search**: RRF/DBSF fusion support

**Tool Interface**:
```typescript
// Read Operations (inherited)
search_collections(query, collections[], mode, limit)
list_collections()

// New Write Operations  
upsert_points(collection, points[])
delete_points(collection, ids[])
create_collection(name, vectors{})
purge_collection(collection, filter?)
```

### 3. memexd-control-mcp - Daemon Control Interface ⚙️ **LIGHTWEIGHT BUILD**

**Purpose**: Thin MCP wrapper for daemon lifecycle management

**Core Tools**:
```typescript
activate_project(project_root: string)    // Start daemon for project
deactivate_project(project_root: string)  // Stop daemon, preserve state
daemon_status()                           // Health check, active projects
force_reindex(paths?: string[])          // Trigger reindex via daemon
```

**Session Integration**:
- Auto-activate on Claude Code session start
- Auto-deactivate on session end
- Pass-through to qdrant-multi-mcp for searches

### Integration Architecture

```
Claude Code Session
       │
       ├─ memexd-control-mcp ─────► memexd daemon ─────► Qdrant
       │                                │
       └─ qdrant-multi-mcp ─────────────┘
```

**Data Flow**:
1. **Session starts** → memexd-control-mcp activates project → memexd starts watching
2. **File changes** → memexd chunks/embeds/upserts → Qdrant updated  
3. **Search queries** → qdrant-multi-mcp → multi-collection search results
4. **Session ends** → memexd-control-mcp deactivates → memexd goes dormant

### Decision Confirmations ✅

**Embedding Model**: `all-MiniLM-L6-v2` (384-dim) - proven in community servers  
**Sparse Method**: BM25 - fast, established, good baseline  
**Hybrid Fusion**: RRF (Reciprocal Rank Fusion) - robust default  
**Daemon Language**: Rust - performance and reliability  
**MCP Framework**: Python + FastMCP - rapid development, proven patterns  

## Conclusion

This hybrid approach leverages proven multi-collection search from the community while building custom tooling only where no alternatives exist. The three-component architecture provides clear separation of concerns and reduces development risk by reusing established patterns for the most complex component (multi-collection search).

**Key Benefits**:
- ✅ **Reduced development time** by forking proven multi-collection search
- ✅ **Lower risk** from validated community patterns  
- ✅ **Clear architecture** with distinct responsibilities
- ✅ **Future extensibility** through modular design