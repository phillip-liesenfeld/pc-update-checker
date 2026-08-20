# PC-Update-Checker/modules/Logger.psm1

# Script-scope variables to hold configuration
$script:LogPath = $null
$script:MinLogLevel = "Info"
$script:CurrentLogFile = $null

function Initialize-Logger {
    <#
    .SYNOPSIS
        Initializes the logging module.
    .DESCRIPTION
        Sets the log path and minimum log level. Creates the log directory if it doesn't exist.
    .PARAMETER Path
        The directory path where log files will be stored.
    .PARAMETER Level
        The minimum log level to record (Info, Warning, Error).
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [string]$Level = "Info"
    )

    $script:LogPath = $Path
    $script:MinLogLevel = $Level

    if (-not (Test-Path -Path $script:LogPath)) {
        New-Item -ItemType Directory -Path $script:LogPath -Force | Out-Null
    }

    # Create a new log file for the day
    $script:CurrentLogFile = Join-Path -Path $script:LogPath -ChildPath "UpdateChecker_$(Get-Date -Format 'yyyyMMdd').log"
}

function Write-Log {
    <#
    .SYNOPSIS
        Writes a message to the log file and console.
    .DESCRIPTION
        Logs a message with a timestamp, level, and optional component ID.
        Writes to the console with appropriate colors and appends to the log file.
    .PARAMETER Message
        The message to log.
    .PARAMETER Level
        The severity level of the message (Info, Warning, Error).
    .PARAMETER ComponentId
        Optional ID of the component related to the log message.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Info", "Warning", "Error", "Debug")]
        [string]$Level,

        [string]$ComponentId
    )

    # Determine if we should log based on level hierarchy
    # Debug (0) < Info (1) < Warning (2) < Error (3)
    $Levels = @("Debug", "Info", "Warning", "Error")
    $msgIndex = $Levels.IndexOf($Level)
    $configIndex = $Levels.IndexOf($script:MinLogLevel)

    if ($msgIndex -lt $configIndex) {
        return
    }

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $FormattedMessage = "[$Timestamp] [$Level]"
    
    if (-not [string]::IsNullOrEmpty($ComponentId)) {
        $FormattedMessage += " [$ComponentId]"
    }
    
    $FormattedMessage += " $Message"

    # Write to Console with Color
    switch ($Level) {
        "Debug"   { Write-Host $FormattedMessage -ForegroundColor Gray }
        "Info"    { Write-Host $FormattedMessage -ForegroundColor Cyan }
        "Warning" { Write-Host $FormattedMessage -ForegroundColor Yellow }
        "Error"   { Write-Host $FormattedMessage -ForegroundColor Red }
    }

    # Write to File
    if ($script:CurrentLogFile) {
        try {
            Add-Content -Path $script:CurrentLogFile -Value $FormattedMessage -ErrorAction Stop
        }
        catch {
            Write-Host "Failed to write to log file: $_" -ForegroundColor Red
        }
    }
}

Export-ModuleMember -Function Initialize-Logger, Write-Log