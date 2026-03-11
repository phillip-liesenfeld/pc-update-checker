# PC-Update-Checker/UpdateChecker.ps1
# Main entry point for the PC Update Checker application.

[CmdletBinding()]
param (
    [string]$ConfigPath
)

# Determine ConfigPath if not provided
if ([string]::IsNullOrEmpty($ConfigPath)) {
    if ($PSScriptRoot) {
        $ConfigPath = Join-Path -Path $PSScriptRoot -ChildPath "config.json"
    } else {
        # Fallback if PSScriptRoot is somehow empty (e.g. running content directly)
        $ConfigPath = Join-Path -Path (Get-Location) -ChildPath "config.json"
    }
}

# Ensure we are running in the script's directory context
if ($PSScriptRoot) {
    Set-Location $PSScriptRoot
}

# Import Modules
try {
    Write-Host "Importing modules..." -ForegroundColor Cyan
    Import-Module "$PSScriptRoot/modules/Logger.psm1" -Force -ErrorAction Stop
    Import-Module "$PSScriptRoot/modules/VersionDetector.psm1" -Force -ErrorAction Stop
    Import-Module "$PSScriptRoot/modules/SystemScanner.psm1" -Force -ErrorAction Stop
    Import-Module "$PSScriptRoot/modules/VersionFetcher.psm1" -Force -ErrorAction Stop
    Import-Module "$PSScriptRoot/modules/fetchers/GameManifestFetcher.psm1" -Force -ErrorAction Stop
    Import-Module "$PSScriptRoot/modules/Updater.psm1" -Force -ErrorAction Stop
    Import-Module "$PSScriptRoot/modules/Orchestrator.psm1" -Force -ErrorAction Stop
    Import-Module "$PSScriptRoot/modules/Comparator.psm1" -Force -ErrorAction Stop
    Import-Module "$PSScriptRoot/modules/ReportGenerator.psm1" -Force -ErrorAction Stop
}
catch {
    Write-Error "Failed to import required modules: $_"
    exit 1
}

# Run the Orchestrator
try {
    $Report = Invoke-UpdateCheck -ConfigPath $ConfigPath
    Write-Host "Process completed successfully." -ForegroundColor Green
    Write-Host "Report location: $Report" -ForegroundColor Green
}
catch {
    Write-Error "An unexpected error occurred during execution: $_"
    exit 1
}
