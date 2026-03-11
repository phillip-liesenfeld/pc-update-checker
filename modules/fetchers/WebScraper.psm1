# PC-Update-Checker/modules/fetchers/WebScraper.psm1

function Get-ScrapedVersion {
    <#
    .SYNOPSIS
        Fetches the latest version by scraping a webpage.
    .DESCRIPTION
        Downloads the HTML content of a URL and applies a regex to extract the version.
        Includes specific logic for NVIDIA drivers if the generic scraper is insufficient.
    .PARAMETER FetchConfig
        The fetching configuration object containing 'url' and 'regex'.
    .OUTPUTS
        [PSCustomObject] with Version, ReleaseDate, and DownloadUrl.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$FetchConfig
    )

    $Url = $FetchConfig.url
    $RegexPattern = $FetchConfig.regex

    if ([string]::IsNullOrWhiteSpace($Url)) {
        Throw "WebScraper: 'url' is missing in configuration."
    }

    # Special handling for NVIDIA — their download pages require JavaScript or form submission,
    # so we delegate to a dedicated function that handles NVIDIA's response format.
    if ($Url -match "nvidia\.com") {
        return Get-NvidiaVersion -FetchConfig $FetchConfig
    }

    if ([string]::IsNullOrWhiteSpace($RegexPattern)) {
        Throw "WebScraper: 'regex' is missing in configuration."
    }

    try {
        $UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"

        $Response = Invoke-WebRequest -Uri $Url -UserAgent $UserAgent -UseBasicParsing -ErrorAction Stop
        $Content = $Response.Content
    }
    catch {
        Throw "WebScraper: Failed to fetch URL '$Url'. $_"
    }

    $Version = $null

    if ($Content -match $RegexPattern) {
        # If the regex has a capture group, use it. Otherwise use the whole match.
        if ($matches.Count -gt 1) {
            $Version = $matches[1]
        }
        else {
            $Version = $matches[0]
        }
    }
    else {
        Throw "WebScraper: Regex pattern '$RegexPattern' did not match any content on '$Url'."
    }

    return [PSCustomObject]@{
        Version     = $Version
        ReleaseDate = $null
        DownloadUrl = $Url
    }
}

function Get-NvidiaVersion {
    <#
    .SYNOPSIS
        Specific fetcher for NVIDIA drivers.
    .DESCRIPTION
        Uses NVIDIA's driver search page to extract the current driver version.
        Falls back to a pattern match for the standard xxx.xx version format.
    #>
    param ($FetchConfig)

    $Url = $FetchConfig.url

    try {
        $UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"

        $Response = Invoke-WebRequest -Uri $Url -UserAgent $UserAgent -UseBasicParsing -ErrorAction Stop
        $Content = $Response.Content

        $RegexPattern = if ($FetchConfig.regex) { $FetchConfig.regex } else { "Version:\s*([0-9.]+)" }

        $Version = $null
        if ($Content -match $RegexPattern) {
            $Version = $matches[1]
        }

        if (-not $Version) {
            # Fallback: match a driver version in xxx.xx format
            if ($Content -match "\b(\d{3}\.\d{2})\b") {
                $Version = $matches[1]
            }
        }

        if (-not $Version) {
            Throw "NvidiaFetcher: Could not extract version from '$Url'."
        }

        return [PSCustomObject]@{
            Version     = $Version
            ReleaseDate = $null
            DownloadUrl = $Url
        }
    }
    catch {
        Throw "NvidiaFetcher: Failed to fetch NVIDIA page. $_"
    }
}

Export-ModuleMember -Function Get-ScrapedVersion
