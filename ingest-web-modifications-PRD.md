# Ingest-web MCP Modifications - Product Requirements Document

## Overview

This document specifies modifications to the existing ingest-web-mcp to integrate with the Qdrant-based project memory system. The modifications redirect web content ingestion from Milvus to Qdrant while adding security protections for malicious content.

## Current State Analysis

**Existing ingest-web-mcp**:
- Uses SearxNG for search aggregation
- Scrapes content via trafilatura/BeautifulSoup
- Stores embeddings in Milvus vector store
- Provides search and ingestion capabilities

**Required Changes**:
- Redirect storage from Milvus to Qdrant
- Implement Qdrant payload contract compliance
- Add web content security protections
- Integrate with per-project collection strategy

## Technical Modifications

### Vector Store Integration

**From Milvus to Qdrant**:
```python
# Before (Milvus)
from pymilvus import Collection, connections
collection = Collection("web_content")

# After (Qdrant)
from qdrant_client import QdrantClient
client = QdrantClient(url="http://localhost:6333")
collection_name = f"pm_{project_slug}"
```

**Embedding Model Standardization**:
- **Current**: Various embedding models supported
- **New**: Standardized to Ollama nomic-embed-text (768-dimensional)
- **Rationale**: Consistency with claude-context MCP and project memory system

### Qdrant Payload Contract Implementation

**Required Payload Structure**:
```python
{
  "project": "project-slug",           # Required: project identifier
  "type": "web_content",              # Required: content type
  "tags": ["research", "external"],   # Optional: classification tags  
  "stage": "final",                   # Optional: content maturity
  "summary": "...",                   # Required: ≤200-token summary
  "content_ref": "https://...",       # Required: original URL
  "related_task_ids": ["8", "12.2"],  # Optional: linked tasks
  "created_at": "2025-01-23T10:30:00Z", # Auto-generated
  "updated_at": "2025-01-23T10:30:00Z"  # Auto-generated
}
```

**Collection Strategy**:
- Per-project collections: `pm_<project-slug>`
- Collection vector size: 768 dimensions (nomic-embed-text)
- Distance metric: Cosine similarity

### Security Enhancements

**Web Content Security Framework**:

**URL Filtering**:
```python
BLOCKED_DOMAINS = [
    # Malicious/suspicious domains
    "malware-example.com",
    "phishing-site.net", 
    # Add known malicious patterns
]

BLOCKED_URL_PATTERNS = [
    r".*\.tk$",           # Suspicious TLDs
    r".*\.ml$",           # Free hosting domains
    r".*\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}.*",  # Raw IP addresses
]

def is_url_safe(url: str) -> bool:
    """Check URL against security filters"""
    # Implementation of filtering logic
```

**Content Validation**:
```python
def validate_scraped_content(content: str, url: str) -> bool:
    """Validate content before ingestion"""
    # Check for malicious patterns
    # Verify content legitimacy
    # Size and format validation
```

**Process Isolation**:
- Web scraping operations run in isolated process/container
- Timeout limits for scraping operations
- Resource limits (memory, CPU) for scraping processes
- Cleanup procedures for temporary files

## Modified Pipeline Architecture

### Enhanced Ingestion Pipeline

**SearxNG Integration** (unchanged):
1. Search via SearxNG (`SEARXNG_URL`) with `format=json`
2. Deduplicate/normalize URLs using `tldextract`
3. Filter out AMP/mirror hosts

**Enhanced Fetch Process**:
```python
def enhanced_fetch_with_security(urls: List[str]) -> List[ScrapedContent]:
    safe_urls = [url for url in urls if is_url_safe(url)]
    
    # Process isolation for scraping
    with isolated_scraper_process():
        for url in safe_urls:
            try:
                content = secure_scrape(url, timeout=30)
                if validate_scraped_content(content, url):
                    yield content
            except SecurityError:
                log_security_violation(url)
                continue
```

**Content Processing**:
1. **Parse**: trafilatura (primary) with BeautifulSoup fallback
2. **Security Scan**: Validate content for malicious patterns
3. **Summarize**: Generate ≤200 token summary for Qdrant payload
4. **Embed**: Generate 768-d vectors via Ollama nomic-embed-text
5. **Store**: Upsert to project-specific Qdrant collection

### Error Handling Strategy

**Security-First Error Handling**:
- **Malicious URL Detected**: Log, block, continue with remaining URLs
- **Content Validation Failed**: Quarantine content, alert user
- **Scraping Timeout**: Retry once, then skip
- **Embedding Failure**: Log error, store without vector (manual review)

**Graceful Degradation**:
- Continue processing if individual URLs fail
- Provide partial results rather than complete failure
- Clear error reporting to user

## Integration Points

### Project Context Integration

**Project Detection**:
```python
def detect_project_context(working_directory: str) -> str:
    """Extract project slug from working directory"""
    # Look for .claude/project.json
    # Extract project identifier
    # Default to directory name if not found
```

**Task Integration**:
```python
def link_to_tasks(content: ScrapedContent, task_ids: List[str]) -> None:
    """Link scraped content to Task-master tasks"""
    # Add task IDs to related_task_ids field
    # Update task details with content references
```

### Qdrant Collection Management

**Collection Initialization**:
```python
def ensure_project_collection(project_slug: str) -> None:
    """Create project collection if it doesn't exist"""
    collection_name = f"pm_{project_slug}"
    
    if not client.collection_exists(collection_name):
        client.create_collection(
            collection_name=collection_name,
            vectors_config=VectorParams(
                size=768,  # nomic-embed-text dimensions
                distance=Distance.COSINE
            )
        )
```

### Claude Code Integration

**MCP Tool Interface**:
```python
# Updated tool signatures
@mcp_tool
def ingest_query(query: str, project_slug: str, max_results: int = 10) -> Dict:
    """Search and ingest web content into project collection"""

@mcp_tool  
def ingest_urls(urls: List[str], project_slug: str) -> Dict:
    """Ingest specific URLs into project collection"""

@mcp_tool
def search_ingested_content(query: str, project_slug: str, limit: int = 8) -> Dict:
    """Search previously ingested content in project collection"""
```

## Configuration Management

### Environment Variables

**Required Configuration**:
```bash
# Existing
SEARXNG_URL=http://localhost:8080
OLLAMA_URL=http://localhost:11434

# New/Modified
QDRANT_URL=http://localhost:6333
EMBEDDING_MODEL=nomic-embed-text
EMBEDDING_DIMENSIONS=768

# Security
ENABLE_URL_FILTERING=true
SCRAPING_TIMEOUT_SECONDS=30
MAX_CONTENT_SIZE_MB=10
```

### Security Configuration

**Configurable Security Policies**:
```yaml
security:
  url_filtering:
    enabled: true
    block_raw_ips: true
    blocked_domains: []
    blocked_patterns: []
  
  content_validation:
    enabled: true
    max_size_mb: 10
    allowed_content_types: ["text/html", "text/plain"]
  
  process_isolation:
    enabled: true
    timeout_seconds: 30
    memory_limit_mb: 512
```

## Testing Requirements

### Security Testing

**Malicious URL Tests**:
- Test blocking of known malicious domains
- Verify IP address filtering
- Validate suspicious pattern detection

**Content Validation Tests**:
- Test malicious content detection
- Verify size limit enforcement
- Test content type restrictions

### Integration Testing

**Qdrant Integration**:
- Test project collection creation
- Verify payload contract compliance
- Test vector storage and retrieval

**End-to-End Pipeline**:
- Complete ingestion workflow testing
- Error handling verification
- Performance under load

### Backwards Compatibility

**Migration Strategy**:
- Provide migration tools from existing Milvus installations
- Support parallel operation during transition
- Data export/import utilities

## Performance Considerations

### Optimization Targets

**Ingestion Performance**:
- Target: <5 seconds per URL for typical web pages
- Parallel processing of multiple URLs
- Efficient embedding generation

**Storage Efficiency**:
- Summary-first storage pattern
- Full content stored at content_ref URL
- Efficient vector storage in Qdrant

### Resource Management

**Memory Usage**:
- Streaming processing for large content
- Cleanup of temporary scraping data  
- Controlled concurrent operations

**Network Efficiency**:
- Connection pooling for HTTP requests
- Retry logic with exponential backoff
- Bandwidth throttling if needed

## Success Metrics

**Primary Metrics**:
- Content ingestion success rate (target: >90%)
- Security violation detection rate
- Average ingestion time per URL

**Secondary Metrics**:
- Project collection growth rate
- Search relevance quality
- System resource utilization

**Security Metrics**:
- Blocked malicious URL count
- Content validation rejection rate
- Zero security incidents target