#Requires -Version 5.1

# Ralph Loop Setup Script (PowerShell)
# Creates state file for in-session Ralph loop

$ErrorActionPreference = "Stop"

# Parse arguments
$promptParts = @()
$maxIterations = 0
$completionPromise = "null"

$i = 0
while ($i -lt $args.Count) {
    $arg = $args[$i]

    switch -Regex ($arg) {
        "^(-h|--help)$" {
            @"
Ralph Loop - Interactive self-referential development loop

USAGE:
  /ralph-loop [PROMPT...] [OPTIONS]

ARGUMENTS:
  PROMPT...    Initial prompt to start the loop (can be multiple words without quotes)

OPTIONS:
  --max-iterations <n>           Maximum iterations before auto-stop (default: unlimited)
  --completion-promise '<text>'  Promise phrase (USE QUOTES for multi-word)
  -h, --help                     Show this help message

DESCRIPTION:
  Starts a Ralph Loop in your CURRENT session. The stop hook prevents
  exit and feeds your output back as input until completion or iteration limit.

  To signal completion, you must output: <promise>YOUR_PHRASE</promise>

  Use this for:
  - Interactive iteration where you want to see progress
  - Tasks requiring self-correction and refinement
  - Learning how Ralph works

EXAMPLES:
  /ralph-loop Build a todo API --completion-promise 'DONE' --max-iterations 20
  /ralph-loop --max-iterations 10 Fix the auth bug
  /ralph-loop Refactor cache layer  (runs forever)
  /ralph-loop --completion-promise 'TASK COMPLETE' Create a REST API

STOPPING:
  Only by reaching --max-iterations or detecting --completion-promise
  No manual stop - Ralph runs infinitely by default!

MONITORING:
  # View current iteration:
  Select-String '^iteration:' .claude/ralph-loop.local.md

  # View full state:
  Get-Content .claude/ralph-loop.local.md -TotalCount 10
"@
            exit 0
        }
        "^--max-iterations$" {
            $i++
            if ($i -ge $args.Count -or [string]::IsNullOrEmpty($args[$i])) {
                Write-Host "Error: --max-iterations requires a number argument" -ForegroundColor Red
                Write-Host ""
                Write-Host "   Valid examples:" -ForegroundColor Yellow
                Write-Host "     --max-iterations 10"
                Write-Host "     --max-iterations 50"
                Write-Host "     --max-iterations 0  (unlimited)"
                Write-Host ""
                Write-Host "   You provided: --max-iterations (with no number)" -ForegroundColor Yellow
                exit 1
            }
            $value = $args[$i]
            if ($value -notmatch '^\d+$') {
                Write-Host "Error: --max-iterations must be a positive integer or 0, got: $value" -ForegroundColor Red
                Write-Host ""
                Write-Host "   Valid examples:" -ForegroundColor Yellow
                Write-Host "     --max-iterations 10"
                Write-Host "     --max-iterations 50"
                Write-Host "     --max-iterations 0  (unlimited)"
                Write-Host ""
                Write-Host "   Invalid: decimals (10.5), negative numbers (-5), text" -ForegroundColor Yellow
                exit 1
            }
            $maxIterations = [int]$value
        }
        "^--completion-promise$" {
            $i++
            if ($i -ge $args.Count -or [string]::IsNullOrEmpty($args[$i])) {
                Write-Host "Error: --completion-promise requires a text argument" -ForegroundColor Red
                Write-Host ""
                Write-Host "   Valid examples:" -ForegroundColor Yellow
                Write-Host "     --completion-promise 'DONE'"
                Write-Host "     --completion-promise 'TASK COMPLETE'"
                Write-Host "     --completion-promise 'All tests passing'"
                Write-Host ""
                Write-Host "   You provided: --completion-promise (with no text)" -ForegroundColor Yellow
                Write-Host ""
                Write-Host "   Note: Multi-word promises must be quoted!" -ForegroundColor Yellow
                exit 1
            }
            $completionPromise = $args[$i]
        }
        default {
            # Non-option argument - collect as prompt part
            $promptParts += $arg
        }
    }
    $i++
}

# Join all prompt parts with spaces
$prompt = $promptParts -join " "

# Validate prompt is non-empty
if ([string]::IsNullOrWhiteSpace($prompt)) {
    Write-Host "Error: No prompt provided" -ForegroundColor Red
    Write-Host ""
    Write-Host "   Ralph needs a task description to work on." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   Examples:"
    Write-Host "     /ralph-loop Build a REST API for todos"
    Write-Host "     /ralph-loop Fix the auth bug --max-iterations 20"
    Write-Host "     /ralph-loop --completion-promise 'DONE' Refactor code"
    Write-Host ""
    Write-Host "   For all options: /ralph-loop --help"
    exit 1
}

# Create state directory if needed
if (-not (Test-Path ".claude")) {
    New-Item -ItemType Directory -Path ".claude" -Force | Out-Null
}

# Format completion promise for YAML
$completionPromiseYaml = if ($completionPromise -ne "null") {
    "`"$completionPromise`""
} else {
    "null"
}

# Get current timestamp in ISO format
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

# Create state file with YAML frontmatter
$stateContent = @"
---
active: true
iteration: 1
max_iterations: $maxIterations
completion_promise: $completionPromiseYaml
started_at: "$timestamp"
---

$prompt
"@

# Write state file with exactly one trailing newline to match bash behavior
Set-Content -Path ".claude/ralph-loop.local.md" -Value $stateContent -NoNewline
Add-Content -Path ".claude/ralph-loop.local.md" -Value ""

# Output setup message
$maxIterationsDisplay = if ($maxIterations -gt 0) { $maxIterations } else { "unlimited" }
$completionPromiseDisplay = if ($completionPromise -ne "null") {
    "$completionPromise (ONLY output when TRUE - do not lie!)"
} else {
    "none (runs forever)"
}

@"
Ralph loop activated in this session!

Iteration: 1
Max iterations: $maxIterationsDisplay
Completion promise: $completionPromiseDisplay

The stop hook is now active. When you try to exit, the SAME PROMPT will be
fed back to you. You'll see your previous work in files, creating a
self-referential loop where you iteratively improve on the same task.

To monitor: Get-Content .claude/ralph-loop.local.md -TotalCount 10

WARNING: This loop cannot be stopped manually! It will run infinitely
    unless you set --max-iterations or --completion-promise.

"@

# Output the initial prompt if provided
if (-not [string]::IsNullOrWhiteSpace($prompt)) {
    Write-Host ""
    Write-Host $prompt
}

# Display completion promise requirements if set
if ($completionPromise -ne "null") {
    @"

===================================================================
CRITICAL - Ralph Loop Completion Promise
===================================================================

To complete this loop, output this EXACT text:
  <promise>$completionPromise</promise>

STRICT REQUIREMENTS (DO NOT VIOLATE):
  * Use <promise> XML tags EXACTLY as shown above
  * The statement MUST be completely and unequivocally TRUE
  * Do NOT output false statements to exit the loop
  * Do NOT lie even if you think you should exit

IMPORTANT - Do not circumvent the loop:
  Even if you believe you're stuck, the task is impossible,
  or you've been running too long - you MUST NOT output a
  false promise statement. The loop is designed to continue
  until the promise is GENUINELY TRUE. Trust the process.

  If the loop should stop, the promise statement will become
  true naturally. Do not force it by lying.
===================================================================
"@
}
