#Requires -Version 5.1

# Ralph Loop Cancel Script (PowerShell)
# Cancels an active Ralph loop by removing the state file

$ErrorActionPreference = "Stop"

$ralphStateFile = ".claude/ralph-loop.local.md"

if (-not (Test-Path $ralphStateFile)) {
    Write-Host "No active Ralph loop found."
    exit 0
}

# Read and parse state file to get iteration
$stateContent = (Get-Content $ralphStateFile -Raw) -replace "`r`n", "`n"
$iterationMatch = [regex]::Match($stateContent, '(?m)^iteration:\s*(\d+)')

$iteration = if ($iterationMatch.Success) {
    $iterationMatch.Groups[1].Value
} else {
    "unknown"
}

# Remove state file
Remove-Item $ralphStateFile -Force

Write-Host "Cancelled Ralph loop (was at iteration $iteration)"
