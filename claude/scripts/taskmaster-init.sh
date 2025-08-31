#!/bin/bash
# taskmaster-init.sh

current_dir="$CLAUDE_PROJECT_DIR"
template_config="$HOME/.claude/assets/taskmaster/config.json"

# Function to find git root and setup taskmaster
setup_taskmaster() {
	local dir="$1"

	while [[ "$dir" != "$HOME" && "$dir" != "/" ]]; do
		if [[ -d "$dir/.git" ]]; then
			# Found git repo
			if [[ ! -d "$dir/.taskmaster" ]]; then
				mkdir -p "$dir/.taskmaster"
			fi

			if [[ ! -s "$dir/.taskmaster/config.json" ]]; then
				cp "$template_config" "$dir/.taskmaster/config.json"
				echo "Initialized taskmaster config in $dir/.taskmaster/"
			fi
			return 0
		fi
		dir="$(dirname "$dir")"
	done
	return 1
}

setup_taskmaster "$current_dir"
