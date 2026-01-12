#Requires -Version 5.1

# Ralph Loop Stop Hook (PowerShell)
# Prevents session exit when a ralph-loop is active
# Feeds Claude's output back as input to continue the loop

$ErrorActionPreference = "Stop"

# Read hook input from stdin
$hookInput = $input | Out-String

# Check if ralph-loop is active
$ralphStateFile = ".claude/ralph-loop.local.md"

if (-not (Test-Path $ralphStateFile)) {
    # No active loop - allow exit
    exit 0
}

# Read state file content and normalize line endings to LF
$stateContent = (Get-Content $ralphStateFile -Raw) -replace "`r`n", "`n"

# Parse markdown frontmatter (YAML between ---)
$frontmatterMatch = [regex]::Match($stateContent, '(?s)^---\n(.*?)\n---')
if (-not $frontmatterMatch.Success) {
    Write-Error "Ralph loop: State file corrupted - no valid frontmatter"
    Remove-Item $ralphStateFile -Force
    exit 0
}

$frontmatter = $frontmatterMatch.Groups[1].Value

# Extract values from frontmatter using multiline anchors to target only frontmatter lines
$iterationMatch = [regex]::Match($frontmatter, '(?m)^iteration:\s*(\d+)')
$maxIterationsMatch = [regex]::Match($frontmatter, '(?m)^max_iterations:\s*(\d+)')
$completionPromiseMatch = [regex]::Match($frontmatter, '(?m)^completion_promise:\s*"?([^"\r\n]+)"?')

if (-not $iterationMatch.Success) {
    Write-Host "Warning: Ralph loop: State file corrupted" -ForegroundColor Yellow
    Write-Host "   File: $ralphStateFile" -ForegroundColor Yellow
    Write-Host "   Problem: 'iteration' field is not valid" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   This usually means the state file was manually edited or corrupted." -ForegroundColor Yellow
    Write-Host "   Ralph loop is stopping. Run /ralph-loop again to start fresh." -ForegroundColor Yellow
    Remove-Item $ralphStateFile -Force
    exit 0
}

if (-not $maxIterationsMatch.Success) {
    Write-Host "Warning: Ralph loop: State file corrupted" -ForegroundColor Yellow
    Write-Host "   File: $ralphStateFile" -ForegroundColor Yellow
    Write-Host "   Problem: 'max_iterations' field is not valid" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   This usually means the state file was manually edited or corrupted." -ForegroundColor Yellow
    Write-Host "   Ralph loop is stopping. Run /ralph-loop again to start fresh." -ForegroundColor Yellow
    Remove-Item $ralphStateFile -Force
    exit 0
}

$iteration = [int]$iterationMatch.Groups[1].Value
$maxIterations = [int]$maxIterationsMatch.Groups[1].Value
$completionPromise = if ($completionPromiseMatch.Success -and $completionPromiseMatch.Groups[1].Value -cne "null") {
    $completionPromiseMatch.Groups[1].Value
} else {
    $null
}

# Check if max iterations reached
if ($maxIterations -gt 0 -and $iteration -ge $maxIterations) {
    Write-Host "Ralph loop: Max iterations ($maxIterations) reached." -ForegroundColor Red
    Remove-Item $ralphStateFile -Force
    exit 0
}

# Get transcript path from hook input with proper validation
try {
    $hookData = $hookInput | ConvertFrom-Json

    # Validate JSON structure
    if (-not $hookData.PSObject.Properties['transcript_path']) {
        throw "Missing 'transcript_path' property in hook input"
    }

    $transcriptPath = $hookData.transcript_path

    if (-not ($transcriptPath -is [string]) -or [string]::IsNullOrWhiteSpace($transcriptPath)) {
        throw "Invalid 'transcript_path' value: expected non-empty string"
    }
} catch {
    Write-Host "Warning: Ralph loop: Failed to parse hook input" -ForegroundColor Yellow
    Write-Host "   Error: $_" -ForegroundColor Yellow
    Remove-Item $ralphStateFile -Force
    exit 0
}

if (-not (Test-Path $transcriptPath)) {
    Write-Host "Warning: Ralph loop: Transcript file not found" -ForegroundColor Yellow
    Write-Host "   Expected: $transcriptPath" -ForegroundColor Yellow
    Write-Host "   This is unusual and may indicate a Claude Code internal issue." -ForegroundColor Yellow
    Write-Host "   Ralph loop is stopping." -ForegroundColor Yellow
    Remove-Item $ralphStateFile -Force
    exit 0
}

# Read transcript (JSONL format - one JSON per line)
$transcriptLines = Get-Content $transcriptPath

# Find last assistant message
$lastAssistantLine = $null
foreach ($line in $transcriptLines) {
    if ($line -match '"role"\s*:\s*"assistant"') {
        $lastAssistantLine = $line
    }
}

if (-not $lastAssistantLine) {
    Write-Host "Warning: Ralph loop: No assistant messages found in transcript" -ForegroundColor Yellow
    Write-Host "   Transcript: $transcriptPath" -ForegroundColor Yellow
    Write-Host "   This is unusual and may indicate a transcript format issue" -ForegroundColor Yellow
    Write-Host "   Ralph loop is stopping." -ForegroundColor Yellow
    Remove-Item $ralphStateFile -Force
    exit 0
}

# Parse JSON and extract text content
try {
    $messageData = $lastAssistantLine | ConvertFrom-Json
    $textContents = $messageData.message.content | Where-Object { $_.type -ceq "text" } | ForEach-Object { $_.text }
    $lastOutput = $textContents -join "`n"
} catch {
    Write-Host "Warning: Ralph loop: Failed to parse assistant message JSON" -ForegroundColor Yellow
    Write-Host "   Error: $_" -ForegroundColor Yellow
    Write-Host "   This may indicate a transcript format issue" -ForegroundColor Yellow
    Write-Host "   Ralph loop is stopping." -ForegroundColor Yellow
    Remove-Item $ralphStateFile -Force
    exit 0
}

if ([string]::IsNullOrWhiteSpace($lastOutput)) {
    Write-Host "Warning: Ralph loop: Assistant message contained no text content" -ForegroundColor Yellow
    Write-Host "   Ralph loop is stopping." -ForegroundColor Yellow
    Remove-Item $ralphStateFile -Force
    exit 0
}

# Check for completion promise (only if set)
if ($completionPromise) {
    # Extract text from <promise> tags
    $promiseMatch = [regex]::Match($lastOutput, '(?s)<promise>(.*?)</promise>')
    if ($promiseMatch.Success) {
        $promiseText = $promiseMatch.Groups[1].Value.Trim()
        # Normalize whitespace
        $promiseText = $promiseText -replace '\s+', ' '

        # Use case-sensitive comparison (-ceq) to match bash behavior
        if ($promiseText -ceq $completionPromise) {
            Write-Host "Ralph loop: Detected <promise>$completionPromise</promise>" -ForegroundColor Green
            Remove-Item $ralphStateFile -Force
            exit 0
        }
    }
}

# Not complete - continue loop with SAME PROMPT
$nextIteration = $iteration + 1

# Extract prompt (everything after the closing ---)
# Don't use TrimStart() to maintain consistency with bash behavior
$promptMatch = [regex]::Match($stateContent, '(?s)^---\n.*?\n---\n(.*)$')
if (-not $promptMatch.Success -or [string]::IsNullOrWhiteSpace($promptMatch.Groups[1].Value)) {
    Write-Host "Warning: Ralph loop: State file corrupted or incomplete" -ForegroundColor Yellow
    Write-Host "   File: $ralphStateFile" -ForegroundColor Yellow
    Write-Host "   Problem: No prompt text found" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   This usually means:" -ForegroundColor Yellow
    Write-Host "     * State file was manually edited" -ForegroundColor Yellow
    Write-Host "     * File was corrupted during writing" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   Ralph loop is stopping. Run /ralph-loop again to start fresh." -ForegroundColor Yellow
    Remove-Item $ralphStateFile -Force
    exit 0
}

# Keep prompt text as-is without trimming (matches bash awk behavior)
$promptText = $promptMatch.Groups[1].Value

# Update iteration in state file using multiline anchor
$updatedContent = $stateContent -replace '(?m)^iteration:\s*\d+', "iteration: $nextIteration"
# Write with trailing newline to match bash behavior
Set-Content -Path $ralphStateFile -Value $updatedContent -NoNewline
Add-Content -Path $ralphStateFile -Value ""

# Build system message with iteration count and completion promise info
if ($completionPromise) {
    $systemMsg = "Ralph iteration $nextIteration | To stop: output <promise>$completionPromise</promise> (ONLY when statement is TRUE - do not lie to exit!)"
} else {
    $systemMsg = "Ralph iteration $nextIteration | No completion promise set - loop runs infinitely"
}

# Output JSON to block the stop and feed prompt back
$outputObject = @{
    decision = "block"
    reason = $promptText
    systemMessage = $systemMsg
}

$outputObject | ConvertTo-Json -Compress

# Exit 0 for successful hook execution
exit 0
