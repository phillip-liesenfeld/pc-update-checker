# PC-Update-Checker/modules/SystemScanner.psm1

function Invoke-SystemScan {
    <#
    .SYNOPSIS
        Scans the system for installed components defined in the configuration.
    .DESCRIPTION
        Iterates through the configuration's component list.
        Uses VersionDetector to check for installation and local version.
        Returns a list of component objects enriched with status.
    .PARAMETER Config
        The full configuration object containing the 'components' list.
    .OUTPUTS
        [PSCustomObject[]] Array of component objects.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Config
    )

    $Components = @()

    if (-not $Config.components) {
        Write-Log -Message "No components defined in configuration." -Level "Warning"
        return $Components
    }

    foreach ($CompConfig in $Config.components) {
        # Create the initial Component Object
        $Component = [PSCustomObject]@{
            Id            = $CompConfig.id
            Name          = $CompConfig.name
            Category      = $CompConfig.category
            Priority      = $CompConfig.priority
            AutoUpdate    = $CompConfig.autoUpdate
            IsInstalled   = $false
            LocalVersion  = $null
            RemoteVersion = $null
            ReleaseDate   = $null
            DownloadUrl   = $null
            UpdateAvailable = $false
            VersionDiff   = $null
            State         = "Pending"
            ErrorMessage  = $null
            # Store config sections for subsequent pipeline stages
            DetectionConfig = $CompConfig.detection
            FetchingConfig = $CompConfig.fetching
        }

        Write-Log -Message "Scanning for $($Component.Name)..." -Level "Info" -ComponentId $Component.Id

        try {
            # Call VersionDetector
            $LocalVersion = Get-InstalledVersion -DetectionConfig $CompConfig.detection

            if (-not [string]::IsNullOrEmpty($LocalVersion)) {
                $Component.LocalVersion = $LocalVersion
                $Component.IsInstalled = $true
                Write-Log -Message "Found version: $LocalVersion" -Level "Info" -ComponentId $Component.Id
            } else {
                $Component.IsInstalled = $false
                Write-Log -Message "Not installed or version not found." -Level "Info" -ComponentId $Component.Id
            }

            $Component.State = "Scanned"
        }
        catch {
            $Component.State = "Error"
            $Component.ErrorMessage = $_.Exception.Message
            Write-Log -Message "Error scanning: $($_.Exception.Message)" -Level "Error" -ComponentId $Component.Id
        }

        $Components += $Component
    }

    return $Components
}

Export-ModuleMember -Function Invoke-SystemScan