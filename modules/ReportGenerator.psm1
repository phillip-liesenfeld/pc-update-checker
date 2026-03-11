# PC-Update-Checker/modules/ReportGenerator.psm1

function New-HtmlReport {
    <#
    .SYNOPSIS
        Generates an HTML report from the processed components.
    .DESCRIPTION
        Reads the HTML template, populates it with component data, and saves the result.
    .PARAMETER Components
        Array of processed component objects.
    .PARAMETER OutputPath
        Directory to save the report.
    .OUTPUTS
        [System.IO.FileInfo] The generated report file.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [array]$Components,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    # 1. Ensure output directory exists
    if (-not (Test-Path -Path $OutputPath)) {
        New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    }

    # 2. Load Template
    # Resolve template path relative to the module location to be robust against CWD changes
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
    $TemplatePath = Join-Path -Path $ProjectRoot -ChildPath "templates/report.html"

    if (-not (Test-Path -Path $TemplatePath)) {
        Throw "Report template not found at: $TemplatePath"
    }
    $TemplateContent = Get-Content -Path $TemplatePath -Raw

    # 3. Calculate Stats
    $Stats = @{
        Total = $Components.Count
        Updated = ($Components | Where-Object { $_.UpdateStatus -eq "Success" }).Count
        Updates = ($Components | Where-Object { $_.UpdateAvailable -eq $true -and $_.UpdateStatus -ne "Success" }).Count
        UpToDate = ($Components | Where-Object { $_.State -eq "Checked" -and $_.UpdateAvailable -ne $true }).Count
        Errors = ($Components | Where-Object { $_.State -eq "Error" -or $_.UpdateStatus -eq "Failed" }).Count
    }

    # 4. Generate Stats HTML
    $StatsHtml = @"
    <div class="stat-card">
        <div class="stat-value" style="color: var(--text-primary)">$($Stats.Total)</div>
        <div class="stat-label">Total Checked</div>
    </div>
    <div class="stat-card">
        <div class="stat-value" style="color: var(--primary-color)">$($Stats.Updated)</div>
        <div class="stat-label">Auto-Updated</div>
    </div>
    <div class="stat-card">
        <div class="stat-value" style="color: var(--warning-color)">$($Stats.Updates)</div>
        <div class="stat-label">Updates Available</div>
    </div>
    <div class="stat-card">
        <div class="stat-value" style="color: var(--success-color)">$($Stats.UpToDate)</div>
        <div class="stat-label">Up to Date</div>
    </div>
    <div class="stat-card">
        <div class="stat-value" style="color: var(--error-color)">$($Stats.Errors)</div>
        <div class="stat-label">Errors</div>
    </div>
"@

    # 5. Generate Items HTML
    $ItemsHtml = ""
    foreach ($Comp in $Components) {
        # Determine Status String for CSS class and display
        $StatusClass = "status-up-to-date"
        $StatusText = "Up to Date"

        if ($Comp.UpdateStatus -eq "Success") {
            $StatusClass = "status-updated"
            $StatusText = "Updated"
        }
        elseif ($Comp.UpdateStatus -eq "Failed") {
            $StatusClass = "status-error"
            $StatusText = "Update Failed"
        }
        elseif ($Comp.State -eq "Error") {
            $StatusClass = "status-error"
            $StatusText = "Error"
        }
        elseif ($Comp.UpdateAvailable) {
            $StatusClass = "status-update-available"
            $StatusText = "Update Available"
        }
        elseif (-not $Comp.IsInstalled) {
            $StatusClass = "status-not-installed"
            $StatusText = "Not Installed"
        }

        # Safe values for HTML
        $LocalVer = if ($Comp.LocalVersion) { $Comp.LocalVersion } else { "-" }
        $RemoteVer = if ($Comp.RemoteVersion) { $Comp.RemoteVersion } else { "-" }
        $Diff = if ($Comp.VersionDiff) { $Comp.VersionDiff } else { "" }
        $ErrorMsg = if ($Comp.ErrorMessage) { "<div style='color:var(--error-color); font-size:0.875rem; margin-top:0.5rem;'>Error: $($Comp.ErrorMessage)</div>" } else { "" }

        $ActionBtn = ""
        if ($Comp.DownloadUrl) {
            $ActionBtn = "<a href='$($Comp.DownloadUrl)' target='_blank' class='btn btn-primary'>Download Update</a>"
        }

        $ItemHtml = @"
        <div class="component-card $StatusClass" data-name="$($Comp.Name)" data-category="$($Comp.Category)" data-status="$StatusText">
            <div class="card-header">
                <div>
                    <div class="component-name">$($Comp.Name)</div>
                    <div class="component-category">$($Comp.Category)</div>
                </div>
                <div class="status-badge">$StatusText</div>
            </div>
            <div class="card-body">
                <div class="version-row">
                    <span class="version-label">Local Version:</span>
                    <span class="version-value">$LocalVer</span>
                </div>
                <div class="version-row">
                    <span class="version-label">Latest Version:</span>
                    <span class="version-value">$RemoteVer</span>
                </div>
                $ErrorMsg
            </div>
            <div class="card-footer">
                $ActionBtn
            </div>
        </div>
"@
        $ItemsHtml += $ItemHtml
    }

    # 6. Replace Placeholders
    $ReportContent = $TemplateContent.Replace("{{GENERATED_DATE}}", (Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))
    $ReportContent = $ReportContent.Replace("{{SUMMARY_STATS}}", $StatsHtml)
    $ReportContent = $ReportContent.Replace("{{ITEMS_HTML}}", $ItemsHtml)

    # 7. Save File
    $FileName = "UpdateReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
    $FilePath = Join-Path -Path $OutputPath -ChildPath $FileName
    $ReportContent | Set-Content -Path $FilePath -Encoding UTF8

    return (Get-Item $FilePath)
}

Export-ModuleMember -Function New-HtmlReport
