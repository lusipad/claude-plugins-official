---
description: "Cancel active Ralph Loop"
allowed-tools: ["Bash(${CLAUDE_PLUGIN_ROOT}/scripts/cancel-ralph-wrapper.sh:*)"]
hide-from-slash-command-tool: "true"
---

# Cancel Ralph

Execute the cancel script to stop the Ralph loop:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/cancel-ralph-wrapper.sh"
```

This will check if a Ralph loop is active and cancel it, reporting the iteration it was at.
