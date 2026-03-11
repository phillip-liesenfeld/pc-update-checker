# PC-Update-Checker/modules/fetchers/WingetFetcher.psm1

function Get-WingetVersion {
    <#
    .SYNOPSIS
        Fetches the latest version of a package from Winget.
    .DESCRIPTION
        Uses the 'winget show' command to retrieve package details.
    .PARAMETER FetchConfig
        The fetching configuration object containing 'packageId'.
    .OUTPUTS
        [PSCustomObject] with Version, ReleaseDate, and DownloadUrl.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$FetchConfig
    )

    $PackageId = $FetchConfig.packageId

    if ([string]::IsNullOrWhiteSpace($PackageId)) {
        Throw "WingetFetcher: 'packageId' is missing in configuration."
    }

    # Check if winget is available
    if (-not (Get-Command "winget" -ErrorAction SilentlyContinue)) {
        Throw "WingetFetcher: 'winget' command not found. Please install App Installer."
    }

    # Run winget show
    # --accept-source-agreements avoids interactive prompts
    # --source winget ensures we check the upstream repository
    # --exact prevents ambiguous package matches
    try {
        $WingetOutput = winget show --id $PackageId --exact --source winget --accept-source-agreements 2>&1

        if ($LASTEXITCODE -ne 0) {
            $ErrorMsg = $WingetOutput | Out-String
            if ($ErrorMsg -match "No package found") {
                Throw "Winget package '$PackageId' not found."
            }
            Throw "Winget command failed for '$PackageId': $ErrorMsg"
        }
    }
    catch {
        Throw "Failed to execute winget for '$PackageId': $_"
    }

    # Parse Output
    # Typical output:
    # Found <Name> [Id]
    # Version: 1.2.3
    # Publisher: ...

    $OutputString = $WingetOutput | Out-String
    $Version = $null
    $Url = "winget install --id $PackageId"

    # Regex to find Version
    if ($OutputString -match 'Version:\s+([^\r\n]+)') {
        $Version = $matches[1].Trim()
    }

    if (-not $Version) {
        Throw "WingetFetcher: Could not parse version from winget output for '$PackageId'."
    }

    return [PSCustomObject]@{
        Version     = $Version
        ReleaseDate = $null
        DownloadUrl = $Url
    }
}

function Update-WingetComponent {
    <#
    .SYNOPSIS
        Updates a specific Winget package.
    .DESCRIPTION
        Runs 'winget upgrade' for the specified package ID.
    .PARAMETER PackageId
        The Winget package ID to update.
    .OUTPUTS
        [PSCustomObject] with Success (bool) and Message (string).
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$PackageId
    )

    $Result = [PSCustomObject]@{
        Success = $false
        Message = ""
    }

    try {
        # --silent may require admin privileges depending on the package
        $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
        $ProcessInfo.FileName = "winget"
        $ProcessInfo.Arguments = "upgrade --exact --id $PackageId --silent --accept-source-agreements --accept-package-agreements"
        $ProcessInfo.RedirectStandardOutput = $true
        $ProcessInfo.RedirectStandardError = $true
        $ProcessInfo.UseShellExecute = $false
        $ProcessInfo.CreateNoWindow = $true

        $Process = New-Object System.Diagnostics.Process
        $Process.StartInfo = $ProcessInfo
        $Process.Start() | Out-Null

        $StdOut = $Process.StandardOutput.ReadToEnd()
        $StdErr = $Process.StandardError.ReadToEnd()

        $Process.WaitForExit()

        if ($Process.ExitCode -eq 0) {
            $Result.Success = $true
            $Result.Message = "Update successful."
        }
        else {
            $Result.Success = $false
            $Output = "$StdOut`n$StdErr".Trim()
            $Result.Message = "Exit Code: $($Process.ExitCode). Output: $Output"
        }
    }
    catch {
        $Result.Success = $false
        $Result.Message = "Exception: $_"
    }

    return $Result
}

Export-ModuleMember -Function Get-WingetVersion, Update-WingetComponent
