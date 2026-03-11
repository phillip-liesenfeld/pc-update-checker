# PC-Update-Checker/modules/Comparator.psm1

function Compare-Version {
    <#
    .SYNOPSIS
        Compares a local version string against a remote version string.
    .DESCRIPTION
        Normalizes version strings and performs a comparison to determine if an update is available.
        Handles standard semantic versioning and attempts to handle some non-standard formats.
    .PARAMETER LocalVersion
        The version string currently installed.
    .PARAMETER RemoteVersion
        The version string found remotely.
    .OUTPUTS
        [PSCustomObject] containing IsUpdateAvailable (bool), Status (string), and Diff (string).
    #>
    param (
        [string]$LocalVersion,
        [string]$RemoteVersion
    )

    $Result = [PSCustomObject]@{
        IsUpdateAvailable = $false
        Status            = "Up to Date"
        Diff              = ""
    }

    # 1. Handle missing inputs
    if ([string]::IsNullOrWhiteSpace($LocalVersion)) {
        $Result.Status = "Not Installed"
        $Result.Diff = "N/A -> $RemoteVersion"
        return $Result
    }

    if ([string]::IsNullOrWhiteSpace($RemoteVersion)) {
        $Result.Status = "Error"
        $Result.Diff = "$LocalVersion -> ?"
        return $Result
    }

    # 2. Normalize versions
    # Remove common prefixes like 'v', 'V'
    # Remove whitespace
    function Normalize-VerString ($v) {
        if ($null -eq $v) { return "" }
        return $v.Trim().TrimStart('v', 'V')
    }

    $NormLocal = Normalize-VerString $LocalVersion
    $NormRemote = Normalize-VerString $RemoteVersion

    $Result.Diff = "$LocalVersion -> $RemoteVersion"

    # 3. Attempt System.Version comparison first (most robust for standard X.Y.Z.W)
    try {
        $VerLocal = [System.Version]$NormLocal
        $VerRemote = [System.Version]$NormRemote

        if ($VerRemote -gt $VerLocal) {
            $Result.IsUpdateAvailable = $true
            $Result.Status = "Update Available"
        }
        elseif ($VerRemote -eq $VerLocal) {
            $Result.Status = "Up to Date"
        }
        else {
            # Remote is older — treat as up to date to avoid noise
            $Result.Status = "Up to Date"
        }
        return $Result
    }
    catch {
        # Fallback to segment-based comparison for non-standard strings
        # e.g. "1.2.3-beta" or different segment counts that System.Version hates
    }

    # 4. Segment-based comparison
    # Split by dots, hyphens, or underscores
    $SplitPattern = "[\.\-_]"
    $SegsLocal = $NormLocal -split $SplitPattern
    $SegsRemote = $NormRemote -split $SplitPattern

    $MaxLen = [Math]::Max($SegsLocal.Count, $SegsRemote.Count)

    for ($i = 0; $i -lt $MaxLen; $i++) {
        # Get segments or default to 0
        $L = if ($i -lt $SegsLocal.Count) { $SegsLocal[$i] } else { "0" }
        $R = if ($i -lt $SegsRemote.Count) { $SegsRemote[$i] } else { "0" }

        # Try integer comparison
        if (($L -match '^\d+$') -and ($R -match '^\d+$')) {
            $IntL = [long]$L
            $IntR = [long]$R

            if ($IntR -gt $IntL) {
                $Result.IsUpdateAvailable = $true
                $Result.Status = "Update Available"
                return $Result
            }
            elseif ($IntL -gt $IntR) {
                $Result.Status = "Up to Date"
                return $Result
            }
        }
        else {
            # String comparison for non-numeric segments
            $Cmp = [string]::Compare($R, $L, [StringComparison]::OrdinalIgnoreCase)
            if ($Cmp -gt 0) {
                $Result.IsUpdateAvailable = $true
                $Result.Status = "Update Available"
                return $Result
            }
            elseif ($Cmp -lt 0) {
                $Result.Status = "Up to Date"
                return $Result
            }
        }
    }

    # If we get here, they are effectively equal
    $Result.Status = "Up to Date"
    return $Result
}

Export-ModuleMember -Function Compare-Version
