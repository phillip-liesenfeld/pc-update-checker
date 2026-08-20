# PC-Update-Checker/modules/Orchestrator.psm1

# Import required modules
# Note: In a real scenario, we might rely on the caller to import these, or use #Requires
# For now, we assume they are available or will be loaded by the main script.

function Invoke-UpdateCheck {
    <#
    .SYNOPSIS
        Coordinates the update check process.
    .DESCRIPTION
        Loads configuration, initializes logging, and runs the update pipeline
        (Scanner -> Fetcher -> Comparator -> Report).
    .PARAMETER ConfigPath
        Path to the configuration JSON file.
    .OUTPUTS
        [System.IO.FileInfo] The generated report file.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath
    )

    # 1. Load Configuration
    if (-not (Test-Path -Path $ConfigPath)) {
        Throw "Configuration file not found at: $ConfigPath"
    }

    try {
        $ConfigJson = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json
    }
    catch {
        Throw "Failed to parse configuration file: $_"
    }

    # 2. Initialize Logger
    # We assume the Logger module is already imported by the calling script
    $LogPath = if ($ConfigJson.global.logging.path) { $ConfigJson.global.logging.path } else { "./Logs" }
    $LogLevel = if ($ConfigJson.global.logging.level) { $ConfigJson.global.logging.level } else { "Info" }
    
    # Resolve relative paths for logging
    if (-not [System.IO.Path]::IsPathRooted($LogPath)) {
        $LogPath = Join-Path -Path (Get-Location) -ChildPath $LogPath
    }

    Initialize-Logger -Path $LogPath -Level $LogLevel
    Write-Log -Message "Starting PC Update Checker..." -Level "Info"
    Write-Log -Message "Loaded configuration from $ConfigPath" -Level "Info"

    # 3. Pipeline Execution
    
    # --- Step 1: System Scanner ---
    # The System Scanner now handles the initial iteration and detection
    Write-Log -Message "Starting System Scan..." -Level "Info"
    $ScannedComponents = Invoke-SystemScan -Config $ConfigJson
    
    $ProcessedComponents = @()

    # Determine execution mode
    $Parallel = $ConfigJson.global.parallelExecution
    $MaxThreads = if ($ConfigJson.global.maxThreads) { $ConfigJson.global.maxThreads } else { 5 }

    Write-Log -Message "Starting update check for $(@($ScannedComponents).Count) components." -Level "Info"

    # Define the processing block for a single component (Fetcher + Comparator)
    $ProcessComponentBlock = {
        param ($Component)
        
        # We need to re-import modules in parallel threads if we use ForEach-Object -Parallel
        # For this skeleton, we'll simulate the flow.
        
        try {
            # --- Step 2: Version Fetcher ---
            if ($Component.IsInstalled) {
                $RemoteInfo = Get-RemoteVersion -FetchConfig $Component.FetchingConfig
                $Component.RemoteVersion = $RemoteInfo.Version
                $Component.ReleaseDate = $RemoteInfo.ReleaseDate
                $Component.DownloadUrl = $RemoteInfo.DownloadUrl
            }

            # --- Step 3: Comparator ---
            if ($Component.LocalVersion -and $Component.RemoteVersion) {
                $Comparison = Compare-Version -LocalVersion $Component.LocalVersion -RemoteVersion $Component.RemoteVersion
                $Component.UpdateAvailable = $Comparison.IsUpdateAvailable
                $Component.VersionDiff = $Comparison.Diff
                # $Component.Status = $Comparison.Status # Optional: Use status from comparator
            }

            # --- Step 4: Updater (Hybrid Mode) ---
            # If update is available and auto-update is enabled, try to update
            if ($Component.UpdateAvailable) {
                $Component = Invoke-Update -Component $Component
            }

            # Update state if not already Error
            if ($Component.State -ne "Error") {
                $Component.State = "Checked"
            }
        }
        catch {
            $Component.State = "Error"
            $Component.ErrorMessage = $_.Exception.Message
            # We can't easily write to the main log from a parallel thread without synchronization
            # In a real implementation, we might return the log message as part of the object
            # or use a thread-safe logging mechanism.
            # For now, we'll just capture the error in the object.
        }

        return $Component
    }

    if ($Parallel -and $PSVersionTable.PSVersion.Major -ge 7) {
        # PowerShell 7+ Parallel Execution
        Write-Log -Message "Executing in Parallel mode (MaxThreads: $MaxThreads)" -Level "Info"
        
        # Note: In a real parallel implementation, we need to ensure modules are available in the runspaces.
        # Since we are just building the skeleton, we will use a standard loop for now to avoid complexity
        # with module loading in this phase, but structure it so it can be easily switched.
        
        # $ProcessedComponents = $ScannedComponents | ForEach-Object -Parallel $ProcessComponentBlock -ThrottleLimit $MaxThreads -ArgumentList $_
        
        # Fallback to sequential for the skeleton to ensure stability until modules exist
        foreach ($Comp in $ScannedComponents) {
            $ProcessedComponents += & $ProcessComponentBlock -Component $Comp
        }
    }
    else {
        # Sequential Execution
        Write-Log -Message "Executing in Sequential mode" -Level "Info"
        foreach ($Comp in $ScannedComponents) {
            $ProcessedComponents += & $ProcessComponentBlock -Component $Comp
        }
    }

    # 4. Report Generation
    Write-Log -Message "Generating report..." -Level "Info"
    
    $ReportPath = if ($ConfigJson.global.reportPath) { $ConfigJson.global.reportPath } else { "./Reports" }
    if (-not [System.IO.Path]::IsPathRooted($ReportPath)) {
        $ReportPath = Join-Path -Path (Get-Location) -ChildPath $ReportPath
    }

    $ReportFile = New-HtmlReport -Components $ProcessedComponents -OutputPath $ReportPath
    Write-Log -Message "Report generated at: $($ReportFile.FullName)" -Level "Info"
    
    # 5. Notifications & Open Report
    if ($ReportFile) {
        # Open in default browser
        Start-Process $ReportFile.FullName

        # Desktop Notification (BurntToast or Native)
        $UpdateCount = ($ProcessedComponents | Where-Object { $_.UpdateAvailable -eq $true }).Count
        $Title = "PC Update Checker"
        $Text = if ($UpdateCount -gt 0) { "$UpdateCount updates available!" } else { "All systems go! No updates found." }

        try {
            if (Get-Module -ListAvailable -Name BurntToast) {
                New-BurntToastNotification -Text $Title, $Text
            } else {
                # Native .NET fallback
                Add-Type -AssemblyName System.Windows.Forms
                $Icon = [System.Windows.Forms.ToolTipIcon]::Info
                $Notify = New-Object System.Windows.Forms.NotifyIcon
                $Notify.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon((Get-Process -Id $PID).Path)
                $Notify.BalloonTipIcon = $Icon
                $Notify.BalloonTipTitle = $Title
                $Notify.BalloonTipText = $Text
                $Notify.Visible = $true
                $Notify.ShowBalloonTip(5000)
                # Cleanup after a short delay to ensure toast shows
                Start-Sleep -Seconds 5
                $Notify.Dispose()
            }
        }
        catch {
            Write-Log -Message "Failed to send notification: $_" -Level "Warning"
        }
    }

    Write-Log -Message "Update check completed." -Level "Info"
    
    return $ReportFile
}

Export-ModuleMember -Function Invoke-UpdateCheck