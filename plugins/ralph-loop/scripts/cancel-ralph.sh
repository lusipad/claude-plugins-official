#!/bin/bash

# Ralph Loop Cancel Script
# Cancels an active Ralph loop by removing the state file

set -euo pipefail

RALPH_STATE_FILE=".claude/ralph-loop.local.md"

if [[ ! -f "$RALPH_STATE_FILE" ]]; then
    echo "No active Ralph loop found."
    exit 0
fi

# Extract iteration from frontmatter
ITERATION=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$RALPH_STATE_FILE" | grep '^iteration:' | sed 's/iteration: *//')

# Remove state file
rm "$RALPH_STATE_FILE"

echo "Cancelled Ralph loop (was at iteration $ITERATION)"
