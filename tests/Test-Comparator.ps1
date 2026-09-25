# tests/Test-Comparator.ps1 -- plain PowerShell, no Pester needed. Exit 0 = all pass.
#   pwsh -File tests/Test-Comparator.ps1
# Cases marked (report) are version pairs taken from real UpdateReport output.
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\modules\Comparator.psm1') -Force

$cases = @(
    # local,                          remote,        update?, note
    @('1.105.1',                        '1.106.1',     $true,  'VS Code (report)'),
    @('1.98.804269',                    '1.97.791262', $false, 'Logitech Options+ (report): remote older'),
    @('1.9',                            '1.10',        $true,  'numeric, not string, per segment'),
    @('v2.0.0',                         '2.0.0',       $false, 'v prefix ignored'),
    @('566.36',                         '566.14',      $false, 'remote older'),
    @('2023.10',                        '2024.1',      $true,  'year-style'),
    # A missing trailing component is zero. [System.Version] calls it -1, so
    # 1.2 < 1.2.0 and a registry 1.20.3 looked older than winget's 1.20.3.0.
    @('1.2',                            '1.2.0',       $false, 'trailing .0 is equal'),
    @('1.20.3',                         '1.20.3.0',    $false, 'registry vs winget padding'),
    @('1.2.0.0',                        '1.2',         $false, 'padding, other direction'),
    @('1.2',                            '1.2.1',       $true,  'padding does not hide a real bump'),
    # SemVer: a pre-release is older than its release; +build is ignored.
    @('2.0.0-beta',                     '2.0.0',       $true,  'release is newer than its beta'),
    @('2.0.0',                          '2.0.0-beta',  $false, 'beta is not newer than the release'),
    @('2.0.0-beta.2',                   '2.0.0-beta.10', $true, 'numeric pre-release identifiers'),
    @('2.0.0-alpha',                    '2.0.0-beta',  $true,  'alpha < beta'),
    @('11.4.10+44d1eb445ca204331db64a82e560876f8abd3150', '11.4.9',  $false, 'Razer Cortex (report): +build ignored, remote older'),
    @('11.4.10+44d1eb445ca204331db64a82e560876f8abd3150', '11.4.11', $true,  'Razer Cortex (report): real bump'),
    @('11.4.10+44d1eb445ca204331db64a82e560876f8abd3150', '11.4.10', $false, 'Razer Cortex (report): same version'),
    @('1.2.3a',                         '1.2.3b',      $true,  'non-standard falls back to segment compare')
)

$fail = 0
foreach ($c in $cases) {
    $r = Compare-Version -LocalVersion $c[0] -RemoteVersion $c[1]
    $ok = $r.IsUpdateAvailable -eq $c[2]
    if (-not $ok) { $fail++ }
    '{0}  {1,-22} -> {2,-16} want update={3,-5} got={4,-5}  {5}' -f $(if ($ok) { 'ok  ' } else { 'FAIL' }),
        ($c[0].Substring(0, [Math]::Min(22, $c[0].Length))), $c[1], $c[2], $r.IsUpdateAvailable, $c[3]
}

# Missing inputs keep their statuses.
$ni = Compare-Version -LocalVersion '' -RemoteVersion '1.0'
$er = Compare-Version -LocalVersion '1.0' -RemoteVersion ''
if ($ni.Status -ne 'Not Installed') { $fail++; "FAIL  empty local should be 'Not Installed', got '$($ni.Status)'" } else { "ok    empty local -> Not Installed" }
if ($er.Status -ne 'Error')         { $fail++; "FAIL  empty remote should be 'Error', got '$($er.Status)'" }      else { "ok    empty remote -> Error" }

"`n$($cases.Count + 2 - $fail) passed, $fail failed"
exit ([int]($fail -gt 0))
