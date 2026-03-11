# PC-Update-Checker/modules/VersionFetcher.psm1

# Import sub-modules
# In a real module manifest, these would be nested modules.
# Here we assume they are in the 'fetchers' subdirectory relative to this file.

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$FetchersDir = Join-Path -Path $ScriptDir -ChildPath "fetchers"

# Import all fetchers
Get-ChildItem -Path $FetchersDir -Filter "*.psm1" | ForEach-Object {
    Import-Module $_.FullName -Force
}

function Get-RemoteVersion {
    <#
    .SYNOPSIS
        Dispatches the version fetching request to the appropriate specific fetcher.
    .DESCRIPTION
        Analyzes the 'fetching.method' property of the configuration and calls the corresponding function.
    .PARAMETER FetchConfig
        The 'fetching' block from the component configuration.
    .OUTPUTS
        [PSCustomObject] with Version, ReleaseDate, and DownloadUrl.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$FetchConfig
    )

    # Support for multiple strategies
    $Strategies = @()
    if ($FetchConfig.strategies) {
        $Strategies = $FetchConfig.strategies
    } else {
        # Legacy/Single strategy support
        $Strategies = @($FetchConfig)
    }

    $Errors = @()

    foreach ($Strategy in $Strategies) {
        $Method = $Strategy.method

        if ([string]::IsNullOrWhiteSpace($Method)) {
            $Errors += "Strategy skipped: Method not specified."
            continue
        }

        try {
            switch ($Method) {
                "Winget" {
                    return Get-WingetVersion -FetchConfig $Strategy
                }
                "GitHub" {
                    return Get-GitHubVersion -FetchConfig $Strategy
                }
                "Scrape" {
                    return Get-ScrapedVersion -FetchConfig $Strategy
                }
                Default {
                    $Errors += "Unknown fetching method '$Method'."
                }
            }
        }
        catch {
            $Errors += "Strategy '$Method' failed: $_"
        }
    }

    # If we are here, all strategies failed
    Throw "All fetching strategies failed. Errors: $($Errors -join '; ')"
}

Export-ModuleMember -Function Get-RemoteVersion
