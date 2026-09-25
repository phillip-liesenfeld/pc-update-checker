# check.ps1 - what every change to this repo must pass. CI runs exactly this.
#
#   pwsh ./check.ps1        # exit 0 means every check ran and passed
#
# Checks: every .ps1/.psm1 parses, config.json parses, and the test scripts
# in tests/ pass. Needs PowerShell 7 (pwsh) and git.
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$script:pass = 0
$script:fail = 0
function Ok($m)  { $script:pass++; Write-Host "  ok    $m" }
function Bad($m) { $script:fail++; Write-Host "  FAIL  $m" }

# Tracked files only, filtered here rather than globbed (pwsh expands
# unquoted globs itself on Linux and macOS).
$tracked = @(git -c core.quotePath=false ls-files)

Write-Host '== PowerShell (parses)'
foreach ($f in $tracked | Where-Object { $_ -like '*.ps1' -or $_ -like '*.psm1' }) {
    $errs = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path -LiteralPath $f).Path, [ref]$null, [ref]$errs)
    if ($errs.Count -eq 0) { Ok $f } else { Bad "$f ($($errs.Count) parse errors)" }
}

Write-Host '== config.json (parses)'
try { Get-Content -Raw -LiteralPath config.json | ConvertFrom-Json | Out-Null; Ok 'config.json' }
catch { Bad 'config.json is not valid JSON' }

Write-Host '== tests'
foreach ($t in $tracked | Where-Object { $_ -like 'tests/Test-*.ps1' }) {
    # Each test script runs in its own pwsh so a module it imports cannot leak
    # into the next one, and its exit code is the verdict.
    pwsh -NoProfile -File $t | Out-Host
    if ($LASTEXITCODE -eq 0) { Ok $t } else { Bad "$t (exit $LASTEXITCODE)" }
}

Write-Host ''
Write-Host "$script:pass passed, $script:fail failed"
exit [int]($script:fail -gt 0)
