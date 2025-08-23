#!/usr/bin/env zsh

# Global MCP Environment Update Script
# Runs weekly to update global tools and Docker images
# Usage: ./update-environment.zsh [--dry-run] [--force]

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
readonly SCRIPT_DIR="${0:A:h}"
readonly PROJECT_ROOT="${SCRIPT_DIR:h}"
readonly BACKUP_DIR="${HOME}/.claude/backups/$(date +%Y%m%d_%H%M%S)"
readonly LOCKFILE="/tmp/claude-env-update.lock"

# Global tool configurations
declare -A GLOBAL_TOOLS=(
    ["uv"]="latest"
    ["docker"]="latest"
    ["docker-compose"]="latest"
    ["ollama"]="latest"
)

# Docker images to update
readonly DOCKER_IMAGES=(
    "milvusdb/milvus:latest"
    "qdrant/qdrant:latest" 
    "searxng/searxng:latest"
    "redis:alpine"
    "postgres:16-alpine"
    "gitea/gitea:latest"
    "temporalio/auto-setup:latest"
    "temporalio/web:latest"
    "temporalio/admin-tools:latest"
)

# MCP packages to update (Python)
readonly MCP_PACKAGES=(
    "claude-context-mcp"
    "ingest-web-mcp" 
    "localdata-mcp"
    "serena"
    "task-master"
    "mcp-server-time"
    "mcp-server-github"
)

# Parse arguments
DRY_RUN=false
FORCE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            cat << EOF
Global MCP Environment Update Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --dry-run       Show what would be updated without making changes
    --force         Skip confirmation prompts
    --verbose       Enable verbose output
    --help          Show this help message

DESCRIPTION:
    Updates global tools, Docker images, and MCP packages used across
    all Claude Code projects. Creates automatic backups before changes.

EXAMPLES:
    $0                    # Interactive update with confirmations
    $0 --dry-run          # Preview what would be updated
    $0 --force            # Update everything without prompts
EOF
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
    esac
done

# Utility functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_verbose() {
    [[ "$VERBOSE" == "true" ]] && echo -e "${BLUE}[VERBOSE]${NC} $1"
}

cleanup() {
    [[ -f "$LOCKFILE" ]] && rm -f "$LOCKFILE"
}

trap cleanup EXIT INT TERM

acquire_lock() {
    if [[ -f "$LOCKFILE" ]]; then
        local pid=$(cat "$LOCKFILE" 2>/dev/null || echo "unknown")
        log_error "Another update is already running (PID: $pid)"
        log_error "If this is incorrect, remove $LOCKFILE and try again"
        exit 1
    fi
    echo $$ > "$LOCKFILE"
}

create_backup() {
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would create backup in $BACKUP_DIR"
        return
    fi

    log_info "Creating backup in $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # Backup Claude config
    [[ -d "${HOME}/.claude" ]] && cp -r "${HOME}/.claude" "$BACKUP_DIR/"
    
    # Backup Docker compose files
    find "$PROJECT_ROOT" -name "docker-compose*.yml" -o -name "compose*.yaml" | while read -r file; do
        local rel_path="${file#$PROJECT_ROOT/}"
        local backup_file="$BACKUP_DIR/${rel_path//\//_}"
        cp "$file" "$backup_file"
    done
    
    log_success "Backup created successfully"
}

check_prerequisites() {
    local missing_tools=()
    
    for tool in docker docker-compose uv python3 ollama; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install missing tools and try again"
        exit 1
    fi
}

update_global_tools() {
    log_info "Updating global tools..."
    
    for tool in "${!GLOBAL_TOOLS[@]}"; do
        local version="${GLOBAL_TOOLS[$tool]}"
        log_verbose "Checking $tool (target: $version)"
        
        case "$tool" in
            "uv")
                if [[ "$DRY_RUN" == "true" ]]; then
                    log_info "[DRY RUN] Would update uv to latest"
                else
                    curl -LsSf https://astral.sh/uv/install.sh | sh
                    log_success "Updated uv"
                fi
                ;;
            "docker"|"docker-compose")
                log_verbose "Skipping $tool (managed by system package manager)"
                ;;
            "ollama")
                if [[ "$DRY_RUN" == "true" ]]; then
                    log_info "[DRY RUN] Would update Ollama to latest"
                else
                    curl -fsSL https://ollama.ai/install.sh | sh
                    log_success "Updated Ollama"
                fi
                ;;
        esac
    done
}

update_docker_images() {
    log_info "Updating Docker images..."
    
    for image in "${DOCKER_IMAGES[@]}"; do
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would pull $image"
        else
            log_verbose "Pulling $image"
            if docker pull "$image"; then
                log_success "Updated $image"
            else
                log_warning "Failed to update $image"
            fi
        fi
    done
}

update_mcp_packages() {
    log_info "Updating MCP packages..."
    
    # Create/update virtual environment for MCP tools
    local venv_dir="${HOME}/.claude/mcp-env"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would update Python MCP packages in $venv_dir"
        return
    fi
    
    if [[ ! -d "$venv_dir" ]]; then
        log_info "Creating MCP virtual environment"
        uv venv "$venv_dir"
    fi
    
    source "$venv_dir/bin/activate"
    
    for package in "${MCP_PACKAGES[@]}"; do
        log_verbose "Updating $package"
        if uv pip install --upgrade "$package"; then
            log_success "Updated $package"
        else
            log_warning "Failed to update $package"
        fi
    done
    
    deactivate
}

update_ollama_models() {
    log_info "Updating Ollama models..."
    
    local models=("nomic-embed-text" "llama3.2:latest")
    
    for model in "${models[@]}"; do
        if [[ "$DRY_RUN" == "true" ]]; then
            log_info "[DRY RUN] Would pull ollama model $model"
        else
            log_verbose "Pulling $model"
            if ollama pull "$model"; then
                log_success "Updated Ollama model $model"
            else
                log_warning "Failed to update $model"
            fi
        fi
    done
}

restart_services() {
    log_info "Restarting Docker services..."
    
    local compose_files=(
        "$PROJECT_ROOT/mcp/claude-context-mcp/docker-compose.yml"
    )
    
    for compose_file in "${compose_files[@]}"; do
        if [[ -f "$compose_file" ]]; then
            local service_dir="$(dirname "$compose_file")"
            if [[ "$DRY_RUN" == "true" ]]; then
                log_info "[DRY RUN] Would restart services in $service_dir"
            else
                log_verbose "Restarting services in $service_dir"
                (cd "$service_dir" && docker-compose down && docker-compose up -d)
                log_success "Restarted services in $service_dir"
            fi
        fi
    done
}

cleanup_old_images() {
    log_info "Cleaning up old Docker images..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would run docker system prune"
        return
    fi
    
    # Remove dangling images
    docker image prune -f
    
    # Remove unused images older than 7 days
    docker image prune -a --filter "until=168h" -f
    
    log_success "Cleaned up old Docker images"
}

prompt_confirmation() {
    if [[ "$FORCE" == "true" || "$DRY_RUN" == "true" ]]; then
        return 0
    fi
    
    echo
    echo -e "${YELLOW}This will update:${NC}"
    echo "  • Global tools (uv, ollama)"
    echo "  • Docker images (${#DOCKER_IMAGES[@]} images)"
    echo "  • MCP packages (${#MCP_PACKAGES[@]} packages)"
    echo "  • Ollama models"
    echo
    echo -e "${YELLOW}A backup will be created in: ${BACKUP_DIR}${NC}"
    echo
    
    read -q "REPLY?Continue with update? (y/N): "
    echo
    
    [[ "$REPLY" =~ ^[Yy]$ ]]
}

main() {
    echo -e "${BLUE}Claude Code Environment Updater${NC}"
    echo "======================================"
    
    acquire_lock
    check_prerequisites
    
    if ! prompt_confirmation; then
        log_info "Update cancelled by user"
        exit 0
    fi
    
    create_backup
    
    # Run updates
    update_global_tools
    update_docker_images
    update_mcp_packages
    update_ollama_models
    restart_services
    cleanup_old_images
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo
        log_info "Dry run completed. No changes were made."
    else
        echo
        log_success "Environment update completed successfully!"
        log_info "Backup created in: $BACKUP_DIR"
    fi
    
    # Show summary
    echo
    echo -e "${BLUE}Update Summary:${NC}"
    echo "  • Global tools: ${#GLOBAL_TOOLS[@]} checked"
    echo "  • Docker images: ${#DOCKER_IMAGES[@]} updated"
    echo "  • MCP packages: ${#MCP_PACKAGES[@]} updated"
    echo "  • Ollama models: 2 updated"
    echo
}

main "$@"