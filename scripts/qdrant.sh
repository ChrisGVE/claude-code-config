#!/usr/bin/env bash

QDRANT__STORAGE__STORAGE_PATH="$XDG_DATA_HOME/claude/persistent_memory/qdrant/storage" \
	QDRANT__STORAGE__SNAPSHOTS_PATH="$XDG_DATA_HOME/claude/persistent_memory/qdrant/snapshots" \
	QDRANT__STORAGE__TEMP_PATH="$XDG_DATA_HOME/claude/persistent_memory/qdrant/tmp" \
	QDRANT__TELEMETRY_DISABLED=true qdrant
