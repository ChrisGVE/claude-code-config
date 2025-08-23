#!/bin/bash

set -e

echo "=== Setting up GitHub repositories and submodules ==="

# Navigate to project root
cd /Users/chris/Dropbox/dev/ai/claude-code-cfg-dev

# Step 1: Remove existing ingest-web-mcp folder and replace with submodule
echo "1. Setting up ingest-web-mcp submodule..."
if [ -d "mcp/ingest-web-mcp" ]; then
    # Remove from git tracking first
    git rm -r mcp/ingest-web-mcp --cached 2>/dev/null || true
    rm -rf mcp/ingest-web-mcp
    git commit -m "Remove ingest-web-mcp folder to replace with submodule" || true
fi

# Add as submodule
git submodule add https://github.com/ChrisGVE/claude-code-ingest-web.git mcp/ingest-web-mcp
echo "✓ ingest-web-mcp submodule added"

# Step 2: Add claude-capabilities-mcp submodule
echo "2. Setting up claude-capabilities-mcp submodule..."
git submodule add https://github.com/ChrisGVE/claude-code-capabilities.git mcp/claude-capabilities-mcp
echo "✓ claude-capabilities-mcp submodule added"

# Step 3: Add qa-engine-mcp submodule  
echo "3. Setting up qa-engine-mcp submodule..."
git submodule add https://github.com/ChrisGVE/claude-code-qa-engine.git mcp/qa-engine-mcp
echo "✓ qa-engine-mcp submodule added"

# Step 4: Transform localdata-mcp to SSH submodule
echo "4. Setting up localdata-mcp SSH submodule..."
if [ -d "mcp/localdata-mcp" ]; then
    # Remove from git tracking
    git rm -r mcp/localdata-mcp --cached 2>/dev/null || true
    rm -rf mcp/localdata-mcp
    git commit -m "Remove localdata-mcp folder to replace with SSH submodule" || true
fi

# Add as SSH submodule
git submodule add git@github.com:ChrisGVE/localdata-mcp.git mcp/localdata-mcp
echo "✓ localdata-mcp SSH submodule added"

# Step 5: Initialize and update all submodules
echo "5. Initializing all submodules..."
git submodule update --init --recursive
echo "✓ All submodules initialized"

# Step 6: Commit the .gitmodules changes
echo "6. Committing submodule configuration..."
git add .gitmodules
git commit -m "feat: Configure project submodules structure

- Add ingest-web-mcp: https://github.com/ChrisGVE/claude-code-ingest-web.git
- Add claude-capabilities-mcp: https://github.com/ChrisGVE/claude-code-capabilities.git  
- Add qa-engine-mcp: https://github.com/ChrisGVE/claude-code-qa-engine.git
- Add localdata-mcp via SSH: git@github.com:ChrisGVE/localdata-mcp.git
- Maintain existing: awesome-claude-code-subagents, subagent-example-script

All MCPs now managed as submodules for individual maintainability"

echo "7. Final status check..."
git submodule status

echo ""
echo "=== Submodule setup complete! ==="
echo ""
echo "Created repositories:"
echo "  - https://github.com/ChrisGVE/claude-code-config"
echo "  - https://github.com/ChrisGVE/claude-code-ingest-web"
echo "  - https://github.com/ChrisGVE/claude-code-capabilities"
echo "  - https://github.com/ChrisGVE/claude-code-qa-engine"
echo ""
echo "Configured submodules:"
echo "  - mcp/ingest-web-mcp → claude-code-ingest-web"
echo "  - mcp/claude-capabilities-mcp → claude-code-capabilities"
echo "  - mcp/qa-engine-mcp → claude-code-qa-engine"
echo "  - mcp/localdata-mcp → localdata-mcp (SSH)"
echo "  - resources/awesome-claude-code-subagents (existing)"
echo "  - resources/subagent-example-script (existing)"