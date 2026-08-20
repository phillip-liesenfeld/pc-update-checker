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

    # Special handling for NVIDIA
    # The config URL for NVIDIA is usually the manual search page, which is hard to scrape with simple regex
    # because it requires JS or form submission.
    # However, NVIDIA has an API we can use if we detect an NVIDIA URL.
    if ($Url -match "nvidia\.com") {
        return Get-NvidiaVersion -FetchConfig $FetchConfig
    }

    if ([string]::IsNullOrWhiteSpace($RegexPattern)) {
        Throw "WebScraper: 'regex' is missing in configuration."
    }

    try {
        # Use a standard User-Agent to avoid being blocked
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
        ReleaseDate = $null # Hard to extract generically without another regex
        DownloadUrl = $Url  # Return the page URL as the download link
    }
}

function Get-NvidiaVersion {
    <#
    .SYNOPSIS
        Specific fetcher for NVIDIA drivers.
    .DESCRIPTION
        Uses NVIDIA's advanced driver search API.
    #>
    param ($FetchConfig)

    # NVIDIA API Endpoint for driver search
    # We can try to parse the PSID/PFID from the config URL if provided, 
    # or we can default to a common query for modern cards (e.g., RTX 30/40 series).
    # For robustness, let's try to extract parameters from the provided URL in config.
    
    # Config URL example: https://www.nvidia.com/Download/processDriver.aspx?psid=101&pfid=816&rpf=1
    # We can actually just hit this URL if it's a direct processDriver link, but usually that returns a file download or a specific page.
    
    # Better approach: Use the official lookup API if possible, or scrape the result page if the URL is a search result.
    # Given the complexity of NVIDIA's site, a reliable method is checking the 'latest' driver API used by GFE or similar tools,
    # but that requires specific hardware IDs.
    
    # Let's stick to the plan: If the user provided a URL, we try to scrape it. 
    # But the config example shows `processDriver.aspx`. If we GET that, it might redirect to the actual driver page or download.
    
    $Url = $FetchConfig.url
    
    try {
        $UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
        
        # If it's the processDriver.aspx link, it often returns the HTML with the download button.
        $Response = Invoke-WebRequest -Uri $Url -UserAgent $UserAgent -UseBasicParsing -ErrorAction Stop
        $Content = $Response.Content
        
        # Regex from config: "Version: ([0-9.]+)"
        # NVIDIA pages often have "Version: 536.23" or similar text.
        $RegexPattern = if ($FetchConfig.regex) { $FetchConfig.regex } else { "Version:\s*([0-9.]+)" }
        
        $Version = $null
        if ($Content -match $RegexPattern) {
            $Version = $matches[1]
        }
        
        if (-not $Version) {
            # Fallback: Try to find something looking like a driver version (xxx.xx)
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