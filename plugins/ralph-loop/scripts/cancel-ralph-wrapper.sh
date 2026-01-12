#!/bin/bash

# Ralph Loop Cancel Script - Cross-Platform Wrapper
# Detects OS and runs the appropriate script (bash or PowerShell)
#
# SECURITY NOTE: On Windows, this script uses -ExecutionPolicy Bypass to run
# PowerShell scripts. This is necessary because:
# 1. The script is part of a trusted Claude Code plugin installed by the user
# 2. PowerShell's default execution policy may block unsigned scripts
# 3. The bypass only applies to this specific script invocation
#
# The PowerShell scripts (cancel-ralph.ps1) only perform these safe operations:
# - Check if .claude/ralph-loop.local.md exists
# - Remove the state file
# - Output status messages to stdout

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect OS using uname
OS_TYPE=$(uname -s 2>/dev/null || echo "Unknown")

case "$OS_TYPE" in
  Linux*|Darwin*)
    # Unix/Linux/macOS - use bash script
    bash "$SCRIPT_DIR/cancel-ralph.sh"
    exit $?
    ;;
  MINGW*|MSYS*|CYGWIN*)
    # Windows with Git Bash/MSYS/Cygwin
    # Try PowerShell first, fall back to bash if PowerShell not available
    if command -v pwsh &> /dev/null; then
      pwsh -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT_DIR/cancel-ralph.ps1"
      exit $?
    elif command -v powershell &> /dev/null; then
      powershell -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT_DIR/cancel-ralph.ps1"
      exit $?
    else
      # Fall back to bash script (Git Bash environment)
      bash "$SCRIPT_DIR/cancel-ralph.sh"
      exit $?
    fi
    ;;
  *)
    # Unknown OS - try bash as fallback
    bash "$SCRIPT_DIR/cancel-ralph.sh"
    exit $?
    ;;
esac
