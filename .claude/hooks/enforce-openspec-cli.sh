#!/bin/bash
# Hook: Warn when writing directly to openspec/changes/ without using /opsx:* commands
# This is a PostToolUse hook that adds a reminder after writes to openspec artifacts.
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=""

if [ "$TOOL_NAME" = "Write" ]; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
elif [ "$TOOL_NAME" = "Edit" ]; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
fi

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Check if the file is inside openspec/changes/ (but NOT in archive/)
if echo "$FILE_PATH" | grep -q "openspec/changes/" && ! echo "$FILE_PATH" | grep -q "openspec/changes/archive/"; then
  # Allow .openspec.yaml (created by CLI)
  if echo "$FILE_PATH" | grep -q "\.openspec\.yaml$"; then
    exit 0
  fi
  echo "REMINDER: When working with OpenSpec artifacts, always use 'openspec instructions <artifact> --change <name>' to get the correct template and format before writing. Use /opsx:propose to create new changes, /opsx:apply to implement, /opsx:archive to complete." >&2
fi

exit 0
