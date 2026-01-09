---
description: "Cancel active Ralph Loop"
allowed-tools: ["Bash(test -f .claude/ralph-loop.local.md:*)", "Bash(rm .claude/ralph-loop.local.md)", "Bash(Remove-Item .claude/ralph-loop.local.md -Force)", "Bash(Test-Path .claude/ralph-loop.local.md)", "Read(.claude/ralph-loop.local.md)"]
hide-from-slash-command-tool: "true"
---

# Cancel Ralph

To cancel the Ralph loop:

1. Check if `.claude/ralph-loop.local.md` exists using Bash: `test -f .claude/ralph-loop.local.md && echo "EXISTS" || echo "NOT_FOUND"`
   - On Windows PowerShell, use: `if (Test-Path .claude/ralph-loop.local.md) { echo "EXISTS" } else { echo "NOT_FOUND" }`

2. **If NOT_FOUND**: Say "No active Ralph loop found."

3. **If EXISTS**:
   - Read `.claude/ralph-loop.local.md` to get the current iteration number from the `iteration:` field
   - Remove the file using Bash: `rm .claude/ralph-loop.local.md`
     - On Windows PowerShell, use: `Remove-Item .claude/ralph-loop.local.md -Force`
   - Report: "Cancelled Ralph loop (was at iteration N)" where N is the iteration value
