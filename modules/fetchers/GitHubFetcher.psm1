# PC-Update-Checker/modules/fetchers/GitHubFetcher.psm1

function Get-GitHubVersion {
    <#
    .SYNOPSIS
        Fetches the latest release version from a GitHub repository.
    .DESCRIPTION
        Queries the GitHub Releases API for the latest release.
    .PARAMETER FetchConfig
        The fetching configuration object containing 'repo' and optional 'assetRegex'.
    .OUTPUTS
        [PSCustomObject] with Version, ReleaseDate, and DownloadUrl.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$FetchConfig
    )

    $Repo = $FetchConfig.repo
    $AssetRegex = $FetchConfig.assetRegex

    if ([string]::IsNullOrWhiteSpace($Repo)) {
        Throw "GitHubFetcher: 'repo' is missing in configuration."
    }

    $ApiUrl = "https://api.github.com/repos/$Repo/releases/latest"
    
    # Basic headers
    # GitHub API requires a User-Agent
    $Headers = @{
        "User-Agent" = "PCUpdateChecker/1.0"
        "Accept"     = "application/vnd.github.v3+json"
    }

    try {
        $Response = Invoke-RestMethod -Uri $ApiUrl -Headers $Headers -Method Get -ErrorAction Stop
    }
    catch {
        # Handle 404 (Repo not found or no releases) or Rate Limits
        if ($_.Exception.Response.StatusCode -eq [System.Net.HttpStatusCode]::NotFound) {
            Throw "GitHubFetcher: Repository '$Repo' not found or has no releases."
        }
        elseif ($_.Exception.Response.StatusCode -eq [System.Net.HttpStatusCode]::Forbidden) {
            Throw "GitHubFetcher: API Rate limit exceeded or access denied."
        }
        else {
            Throw "GitHubFetcher: Failed to query GitHub API. $($_.Exception.Message)"
        }
    }

    # Extract Version
    # Usually 'tag_name', often prefixed with 'v'
    $Version = $Response.tag_name
    if ($Version -match "^v(\d.*)") {
        $Version = $matches[1]
    }

    # Extract Release Date
    $ReleaseDate = $null
    if ($Response.published_at) {
        $ReleaseDate = [DateTime]::Parse($Response.published_at)
    }

    # Extract Download URL
    # If assetRegex is provided, find the matching asset. Otherwise, use the html_url of the release.
    $DownloadUrl = $Response.html_url

    if (-not [string]::IsNullOrWhiteSpace($AssetRegex) -and $Response.assets) {
        $MatchingAsset = $Response.assets | Where-Object { $_.name -match $AssetRegex } | Select-Object -First 1
        if ($MatchingAsset) {
            $DownloadUrl = $MatchingAsset.browser_download_url
        }
    }

    return [PSCustomObject]@{
        Version     = $Version
        ReleaseDate = $ReleaseDate
        DownloadUrl = $DownloadUrl
    }
}

Export-ModuleMember -Function Get-GitHubVersion