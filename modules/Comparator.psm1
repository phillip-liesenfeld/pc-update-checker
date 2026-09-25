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

    # 3. Numeric versions, optionally SemVer-shaped: 1.2.3[.4...][-pre.release][+build]
    #    This replaces a [System.Version] comparison, which treats a missing component
    #    as -1: 1.2 < 1.2.0, so a registry "1.20.3" looked older than winget's
    #    "1.20.3.0" and reported a false update. Rules here:
    #      - a missing trailing component is 0
    #      - a pre-release is older than its release (2.0.0-beta < 2.0.0)
    #      - +build metadata is ignored (Razer Cortex reports "11.4.10+44d1eb4...")
    function Split-SemVer ($v) {
        if ($v -notmatch '^(\d+(?:\.\d+)*)(?:-([0-9A-Za-z.\-]+))?(?:\+[0-9A-Za-z.\-]+)?$') { return $null }
        return [PSCustomObject]@{ Core = [long[]]($Matches[1] -split '\.'); Pre = $Matches[2] }
    }

    # -1 / 0 / 1 for remote vs local, SemVer precedence for pre-release identifiers.
    function Compare-SemVer ($l, $r) {
        $n = [Math]::Max($l.Core.Count, $r.Core.Count)
        for ($i = 0; $i -lt $n; $i++) {
            $a = if ($i -lt $l.Core.Count) { $l.Core[$i] } else { 0 }
            $b = if ($i -lt $r.Core.Count) { $r.Core[$i] } else { 0 }
            if ($b -ne $a) { return [Math]::Sign($b - $a) }
        }
        if (-not $l.Pre -and -not $r.Pre) { return 0 }
        if (-not $r.Pre) { return 1 }     # remote is the release of local's pre-release
        if (-not $l.Pre) { return -1 }    # remote is a pre-release of local's release
        $pl = $l.Pre -split '\.'; $pr = $r.Pre -split '\.'
        for ($i = 0; $i -lt [Math]::Min($pl.Count, $pr.Count); $i++) {
            $x = $pl[$i]; $y = $pr[$i]
            $xn = $x -match '^\d+$'; $yn = $y -match '^\d+$'
            if ($xn -and $yn) { $c = [Math]::Sign([long]$y - [long]$x) }
            elseif ($xn) { $c = 1 }       # numeric identifiers sort before alphanumeric
            elseif ($yn) { $c = -1 }
            else { $c = [Math]::Sign([string]::CompareOrdinal($y, $x)) }
            if ($c -ne 0) { return $c }
        }
        return [Math]::Sign($pr.Count - $pl.Count)
    }

    $SvLocal = Split-SemVer $NormLocal
    $SvRemote = Split-SemVer $NormRemote
    if ($SvLocal -and $SvRemote) {
        if ((Compare-SemVer $SvLocal $SvRemote) -gt 0) {
            $Result.IsUpdateAvailable = $true
            $Result.Status = "Update Available"
        }
        else {
            # Equal, or remote is older - treat as up to date to avoid noise
            $Result.Status = "Up to Date"
        }
        return $Result
    }
    # Otherwise fall through to segment-based comparison for non-standard strings

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
