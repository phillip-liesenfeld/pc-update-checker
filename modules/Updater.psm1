# PC-Update-Checker/modules/Updater.psm1

# Update-WingetComponent lives in fetchers/WingetFetcher.psm1. VersionFetcher.psm1 also
# imports it, but that import is scoped to VersionFetcher's own module session state and
# does not leak here, so it must be imported directly.
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Import-Module (Join-Path -Path $ScriptDir -ChildPath "fetchers/WingetFetcher.psm1") -Force

function Invoke-Update {
    <#
    .SYNOPSIS
        Checks if an update is required and authorized, then triggers it.
    .DESCRIPTION
        If UpdateAvailable is true and AutoUpdate is true for the component,
        this function attempts to update the component using the appropriate fetcher/updater.
    .PARAMETER Component
        The component object to check and update.
    .OUTPUTS
        [PSCustomObject] The updated component object with UpdateStatus.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Component
    )

    # Initialize UpdateStatus if not present
    if (-not ($Component | Get-Member -Name "UpdateStatus" -ErrorAction SilentlyContinue)) {
        $Component | Add-Member -MemberType NoteProperty -Name "UpdateStatus" -Value "NotAttempted"
    }

    # Check conditions: Update Available AND AutoUpdate enabled
    if ($Component.UpdateAvailable -and $Component.AutoUpdate) {
        
        # Determine if we can update this component
        # Currently only supporting Winget
        
        $WingetId = $null
        
        # Check if fetching config is direct Winget
        if ($Component.FetchingConfig.method -eq 'Winget') {
            $WingetId = $Component.FetchingConfig.packageId
        }
        # Check if fetching config has strategies, and one is Winget
        elseif ($Component.FetchingConfig.strategies) {
            $WingetStrategy = $Component.FetchingConfig.strategies | Where-Object { $_.method -eq 'Winget' } | Select-Object -First 1
            if ($WingetStrategy) {
                $WingetId = $WingetStrategy.packageId
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($WingetId)) {
            try {
                Write-Log -Message "Updating $($Component.Name) via Winget..." -Level "Info" -ComponentId $Component.Id
                
                # Call Update-WingetComponent
                # We assume the WingetFetcher module is loaded and this function is exported.
                $Result = Update-WingetComponent -PackageId $WingetId
                
                if ($Result.Success) {
                    $Component.UpdateStatus = "Success"
                }
                else {
                    $Component.UpdateStatus = "Failed"
                    # Append error message if it exists
                    if ($Component.ErrorMessage) {
                        $Component.ErrorMessage += "; Update Failed: $($Result.Message)"
                    } else {
                        $Component.ErrorMessage = "Update Failed: $($Result.Message)"
                    }
                }
            }
            catch {
                $Component.UpdateStatus = "Failed"
                $ErrorMsg = $_.Exception.Message
                if ($Component.ErrorMessage) {
                    $Component.ErrorMessage += "; Update Exception: $ErrorMsg"
                } else {
                    $Component.ErrorMessage = "Update Exception: $ErrorMsg"
                }
            }
        }
        else {
            $Component.UpdateStatus = "Skipped (No Winget ID)"
        }
    }
    
    return $Component
}

Export-ModuleMember -Function Invoke-Update