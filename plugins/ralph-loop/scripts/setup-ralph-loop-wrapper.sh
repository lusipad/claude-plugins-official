#!/bin/bash

# Ralph Loop Setup Script - Cross-Platform Wrapper
# Detects OS and runs the appropriate script (bash or PowerShell)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect OS using uname
OS_TYPE=$(uname -s 2>/dev/null || echo "Unknown")

case "$OS_TYPE" in
  Linux*|Darwin*)
    # Unix/Linux/macOS - use bash script
    bash "$SCRIPT_DIR/setup-ralph-loop.sh" "$@"
    exit $?
    ;;
  MINGW*|MSYS*|CYGWIN*)
    # Windows with Git Bash/MSYS/Cygwin
    # Try PowerShell first, fall back to bash if PowerShell not available
    if command -v pwsh &> /dev/null; then
      pwsh -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT_DIR/setup-ralph-loop.ps1" "$@"
      exit $?
    elif command -v powershell &> /dev/null; then
      powershell -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT_DIR/setup-ralph-loop.ps1" "$@"
      exit $?
    else
      # Fall back to bash script (Git Bash environment)
      bash "$SCRIPT_DIR/setup-ralph-loop.sh" "$@"
      exit $?
    fi
    ;;
  *)
    # Unknown OS - try bash as fallback
    bash "$SCRIPT_DIR/setup-ralph-loop.sh" "$@"
    exit $?
    ;;
esac
