#!/usr/bin/env /bin/bash

cd ..
ls
# First link claude.json
ln -sf "$(pwd)/claude.json" "$HOME/.claude.json"

# Second backup the .claude folder
folder="$HOME/.claude"
backup="$HOME/claude_backup"
if [ -d "$folder" ] && [ ! -L "$folder" ]; then
	n=1
	if [ -e "$backup" ]; then
		while [ -e "${backup}_${n}" ]; do
			((n++))
		done
		backup="${backup}_${n}"
	fi
	mv "$folder" "$backup"
fi
ln -sf "$(pwd)/claude" "$folder"
