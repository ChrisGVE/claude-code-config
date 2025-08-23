#!/usr/bin/env zsh
# Batch-copy Markdown files from multiple subpaths under a base source dir
# to a single destination dir, excluding README.md, and prefixing filenames.
#
# No validation is performed per request.

set -euo pipefail

# Ensure a sane PATH for non-interactive shells
export PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# --- Constants (override via env if desired) ---
: ${BASE_SRC_DIR:="$PWD/resources/awesome-claude-code-subagents/categories"}   # e.g., /path/to/base/source
: ${DEST_DIR:="$PWD/agents/collection"}       # e.g., /path/to/destination

# 2xN flat array: ( path1 prefix1 path2 prefix2 ... )
# Edit to suit your layout.
typeset -ar PAIRS=(
  "01-core-development"    "core"  
  "02-language-specialists"   "lang"
  "03-infrastructure"  "infra"
  "04-quality-security" "qa-sec"
  "05-data-ai" "data"
  "06-developer-experience" "devex"
  "07-specialized-domains" "domains"
  "08-business-product" "biz"
  "09-meta-orchestration" "meta"
  "10-research-analysis" "research"
)

# Prepare destination (not a validation, just convenience)
mkdir -p -- "$DEST_DIR"

# Iterate pairs two at a time
for (( i=1; i <= $#PAIRS; i+=2 )); do
  path=${PAIRS[i]}
  prefix=${PAIRS[i+1]}
  src="$BASE_SRC_DIR/$path"

  # Loop *.md files; (N) makes glob expand to nothing when no match
  for f in "$src"/*.md(.N); do
    base=${f:t}
    [[ $base == README.md ]] && continue
    target="$DEST_DIR/${prefix}-${base}"
    /bin/cp -p "$f" "$target"

    # --- Front matter–aware edits (between the first pair of '---' lines) ---
    # If a 'model:' line exists in front matter, do nothing further.
    if /usr/bin/sed -n '/^---[[:space:]]*$/,/^---[[:space:]]*$/p' "$target" | /usr/bin/grep -q '^[[:space:]]*model:'; then
      :
    else
      # Choose mode: replace the first tools: -> model: sonnet, or insert model: after description:
      if /usr/bin/sed -n '/^---[[:space:]]*$/,/^---[[:space:]]*$/p' "$target" | /usr/bin/grep -q '^[[:space:]]*tools:'; then
        MODE="replace_tools"
      else
        MODE="insert_after_desc"
      fi

      /usr/bin/awk -v MODE="$MODE" '
      BEGIN { inFM=0; delim=0; repl=0; ins=0; app=0 }
      /^---[[:space:]]*$/ {
        delim++
        print
        if (delim==1) inFM=1
        else if (delim==2) inFM=0
        next
      }
      {
        if (inFM) {
          if (MODE=="replace_tools" && !repl && $0 ~ /^[[:space:]]*tools:/) {
            print "model: sonnet"
            repl=1
            next
          }
          if (!app && $0 ~ /^[[:space:]]*description:/) {
            print $0 " PROACTIVELY use this agent."
            if (MODE=="insert_after_desc" && !ins) {
              print "model: sonnet"
              ins=1
            }
            app=1
            next
          }
        }
        print
      }' "$target" > "$target.__tmp__" && /bin/mv "$target.__tmp__" "$target"
    fi
  done
done
