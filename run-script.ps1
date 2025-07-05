#!/usr/bin/env pwsh
param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

# Forward to the organized script runner
& ".\scripts\run.ps1" @Arguments 