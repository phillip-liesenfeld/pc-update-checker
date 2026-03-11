# PC-Update-Checker/modules/VersionDetector.psm1

function Get-InstalledVersion {
    <#
    .SYNOPSIS
        Detects the installed version of a component based on the provided configuration.
    .DESCRIPTION
        Supports various detection methods including WMI, Registry, File, Command, Winget, and Chocolatey.
        Applies regex transformation if specified.
    .PARAMETER DetectionConfig
        The 'detection' block from the component configuration.
    .OUTPUTS
        [string] The detected version, or $null if not found.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$DetectionConfig
    )

    $Method = $DetectionConfig.method
    $Version = $null

    try {
        switch ($Method) {
            "WMI" {
                $Query = $DetectionConfig.query
                $Property = $DetectionConfig.property
                # Use Get-CimInstance for modern PowerShell compatibility
                $Result = Get-CimInstance -Query $Query -ErrorAction Stop | Select-Object -First 1
                if ($Result -and $Result.$Property) {
                    $Version = $Result.$Property
                }
            }
            "Registry" {
                $Path = $DetectionConfig.path
                $Key = $DetectionConfig.key
                if (Test-Path $Path) {
                    $Item = Get-ItemProperty -Path $Path -Name $Key -ErrorAction SilentlyContinue
                    if ($Item -and $Item.$Key) {
                        $Version = $Item.$Key
                    }
                }
            }
            "File" {
                $Path = $DetectionConfig.path
                $Property = $DetectionConfig.property
                if (Test-Path $Path) {
                    $Item = Get-Item -Path $Path -ErrorAction Stop
                    if ($Property -eq "ProductVersion" -or $Property -eq "FileVersion") {
                        $Version = $Item.VersionInfo.$Property
                    } else {
                        $Version = $Item.$Property
                    }
                }
            }
            "Command" {
                $Cmd = $DetectionConfig.command
                $Args = $DetectionConfig.args

                $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
                $ProcessInfo.FileName = $Cmd
                if ($Args) { $ProcessInfo.Arguments = $Args }
                $ProcessInfo.RedirectStandardOutput = $true
                $ProcessInfo.RedirectStandardError = $true
                $ProcessInfo.UseShellExecute = $false
                $ProcessInfo.CreateNoWindow = $true

                $Process = [System.Diagnostics.Process]::Start($ProcessInfo)
                $Process.WaitForExit()

                $Output = $Process.StandardOutput.ReadToEnd()
                if (-not $Output) { $Output = $Process.StandardError.ReadToEnd() }

                $Version = $Output.Trim()
            }
            "Winget" {
                $Id = $DetectionConfig.packageId
                # Use winget list to find the installed package
                $Output = winget list -e --id $Id --accept-source-agreements 2>$null
                if ($Output) {
                    # Parse output to find the version
                    # Typical output: Name Id Version Available Source
                    $Lines = $Output -split "`n"
                    foreach ($Line in $Lines) {
                        if ($Line -match "$Id\s+([^\s]+)") {
                            $Version = $Matches[1]
                            break
                        }
                    }
                }
            }
            "Chocolatey" {
                $Id = $DetectionConfig.packageId
                $Output = choco list --local-only --exact $Id --limit-output 2>$null
                # Output format: package|version
                if ($Output) {
                    $Parts = $Output -split "\|"
                    if ($Parts.Count -ge 2) {
                        $Version = $Parts[1]
                    }
                }
            }
            "SteamManifest" {
                $AppId = $DetectionConfig.appId
                $SteamPath = if ($DetectionConfig.steamPath) { $DetectionConfig.steamPath } else { "C:\Program Files (x86)\Steam" }
                $Version = Get-SteamManifestVersion -AppId $AppId -SteamPath $SteamPath
            }
            "EpicManifest" {
                $AppName = $DetectionConfig.appName
                $ManifestsPath = if ($DetectionConfig.manifestsPath) { $DetectionConfig.manifestsPath } else { "C:\ProgramData\Epic\EpicGamesLauncher\Data\Manifests" }
                $Version = Get-EpicManifestVersion -AppName $AppName -ManifestsPath $ManifestsPath
            }
            Default {
                Write-Log -Message "Unknown detection method: $Method" -Level "Warning"
            }
        }

        # Apply Transform Regex if present and version was found
        if ($Version -and $DetectionConfig.transformRegex) {
            if ($Version -match $DetectionConfig.transformRegex) {
                if ($Matches.Count -gt 1) {
                    $Version = $Matches[1]
                } else {
                    $Version = $Matches[0]
                }
            }
        }
    }
    catch {
        Write-Log -Message "Error detecting version using $Method : $_" -Level "Warning"
    }

    return $Version
}

Export-ModuleMember -Function Get-InstalledVersion
