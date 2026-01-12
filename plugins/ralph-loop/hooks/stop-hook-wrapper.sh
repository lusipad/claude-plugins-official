#!/bin/bash

# Ralph Loop Stop Hook - Cross-Platform Wrapper
# Detects OS and runs the appropriate script (bash or PowerShell)
#
# SECURITY NOTE: On Windows, this script uses -ExecutionPolicy Bypass to run
# PowerShell scripts. This is necessary because:
# 1. The script is part of a trusted Claude Code plugin installed by the user
# 2. PowerShell's default execution policy may block unsigned scripts
# 3. The bypass only applies to this specific script invocation
#
# The PowerShell scripts (stop-hook.ps1) only perform these safe operations:
# - Read/write to .claude/ralph-loop.local.md state file
# - Read transcript files provided by Claude Code
# - Output JSON to stdout

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read stdin and store it (need to pass to the actual script)
STDIN_CONTENT=$(cat)

# Detect OS using uname
OS_TYPE=$(uname -s 2>/dev/null || echo "Unknown")

case "$OS_TYPE" in
  Linux*|Darwin*)
    # Unix/Linux/macOS - use bash script
    echo "$STDIN_CONTENT" | bash "$SCRIPT_DIR/stop-hook.sh"
    exit $?
    ;;
  MINGW*|MSYS*|CYGWIN*)
    # Windows with Git Bash/MSYS/Cygwin
    # Try PowerShell first, fall back to bash if PowerShell not available
    if command -v pwsh &> /dev/null; then
      echo "$STDIN_CONTENT" | pwsh -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT_DIR/stop-hook.ps1"
      exit $?
    elif command -v powershell &> /dev/null; then
      echo "$STDIN_CONTENT" | powershell -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT_DIR/stop-hook.ps1"
      exit $?
    else
      # Fall back to bash script (Git Bash environment)
      echo "$STDIN_CONTENT" | bash "$SCRIPT_DIR/stop-hook.sh"
      exit $?
    fi
    ;;
  *)
    # Unknown OS - try bash as fallback
    echo "$STDIN_CONTENT" | bash "$SCRIPT_DIR/stop-hook.sh"
    exit $?
    ;;
esac
