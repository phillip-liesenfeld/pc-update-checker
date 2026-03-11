# PC-Update-Checker/modules/fetchers/GameManifestFetcher.psm1

function Get-SteamManifestVersion {
    <#
    .SYNOPSIS
        Gets the installed build ID of a Steam game from its manifest file.
    .DESCRIPTION
        Reads the appmanifest_<appid>.acf file to find the "buildid".
    .PARAMETER AppId
        The Steam App ID of the game.
    .PARAMETER SteamPath
        Optional. The path to the Steam installation. Defaults to "C:\Program Files (x86)\Steam".
    .OUTPUTS
        [string] The build ID, or $null if not found.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppId,

        [string]$SteamPath = "C:\Program Files (x86)\Steam"
    )

    $ManifestPath = Join-Path -Path $SteamPath -ChildPath "steamapps\appmanifest_$AppId.acf"

    if (-not (Test-Path $ManifestPath)) {
        Write-Log -Message "Steam manifest not found at: $ManifestPath" -Level "Debug"
        return $null
    }

    Write-Log -Message "Reading Steam Manifest for AppId $AppId..." -Level "Info"

    try {
        $Content = Get-Content -Path $ManifestPath -Raw -ErrorAction Stop
        # Regex to find "buildid"		"123456"
        if ($Content -match '"buildid"\s+"(\d+)"') {
            return $Matches[1]
        }
    }
    catch {
        Write-Log -Message "Error reading Steam manifest for AppId $AppId : $_" -Level "Warning"
    }

    return $null
}

function Get-EpicManifestVersion {
    <#
    .SYNOPSIS
        Gets the installed build version of an Epic Games title from local manifests.
    .DESCRIPTION
        Iterates through .item files in the Epic Manifests directory to find the matching AppName.
    .PARAMETER AppName
        The Epic Games AppName (e.g., "Fortnite").
    .PARAMETER ManifestsPath
        Optional. The path to Epic manifests. Defaults to "C:\ProgramData\Epic\EpicGamesLauncher\Data\Manifests".
    .OUTPUTS
        [string] The BuildVersion, or $null if not found.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$AppName,

        [string]$ManifestsPath = "C:\ProgramData\Epic\EpicGamesLauncher\Data\Manifests"
    )

    if (-not (Test-Path $ManifestsPath)) {
        Write-Log -Message "Epic manifests directory not found at: $ManifestsPath" -Level "Debug"
        return $null
    }

    Write-Log -Message "Reading Epic Manifests for $AppName..." -Level "Info"

    try {
        $ManifestFiles = Get-ChildItem -Path $ManifestsPath -Filter "*.item" -ErrorAction Stop

        foreach ($File in $ManifestFiles) {
            try {
                $JsonContent = Get-Content -Path $File.FullName -Raw | ConvertFrom-Json
                if ($JsonContent.AppName -eq $AppName) {
                    return $JsonContent.BuildVersion
                }
            }
            catch {
                # Ignore malformed JSON files
                continue
            }
        }
    }
    catch {
        Write-Log -Message "Error searching Epic manifests for AppName $AppName : $_" -Level "Warning"
    }

    return $null
}

Export-ModuleMember -Function Get-SteamManifestVersion, Get-EpicManifestVersion
