# PC Update Checker

## Project Overview
PC Update Checker is a modular PowerShell tool designed to automate the process of checking for updates for various software, drivers, and components on your Windows PC. It compares the currently installed versions against the latest available versions fetched from multiple sources (Winget, GitHub, Web Scraper) and generates a comprehensive HTML report.

## Quick Start

1.  **Prerequisites**: Ensure you have PowerShell 5.1 or later (PowerShell 7+ recommended).
2.  **Navigate to the directory**: Open a PowerShell terminal in the `PC-Update-Checker` folder.
3.  **Run the script**:
    ```powershell
    .\UpdateChecker.ps1
    ```
    *   If you encounter an execution policy error, see the [Troubleshooting](#troubleshooting) section.

## Configuration

The tool is driven by the `config.json` file. You can add or modify components to check by editing this file.

### Structure
The configuration consists of `global` settings and a list of `components`.

### Adding a New Component
To add a new software or driver, add a new object to the `components` array. Here is an example configuration for checking **Visual Studio Code**:

```json
{
  "id": "vscode",
  "name": "Visual Studio Code",
  "category": "Software",
  "priority": "Medium",
  "detection": {
    "method": "File",
    "path": "C:\\Program Files\\Microsoft VS Code\\Code.exe",
    "property": "ProductVersion"
  },
  "fetching": {
    "method": "Winget",
    "packageId": "Microsoft.VisualStudioCode"
  }
}
```

**Detection Methods:**
*   `File`: Checks version metadata of a specific file (exe/dll).
*   `Registry`: Checks a registry key value.
*   `WMI`: Queries Windows Management Instrumentation.
*   `Command`: Runs a CLI command to get the version.

**Fetching Methods:**
*   `Winget`: Uses the Windows Package Manager.
*   `GitHub`: Checks the latest release tag of a GitHub repository.
*   `Scrape`: Scrapes a webpage using Regex to find the version string.

## Report

After the script finishes execution, an HTML report is generated.

*   **Location**: By default, reports are saved in the `./Reports` directory with a timestamped filename (e.g., `UpdateReport_20231027_103000.html`).
*   **Status Indicators**:
    *   **Green**: Up to date.
    *   **Red**: Outdated (Update available).
    *   **Yellow**: Warning (Version mismatch or check failed).
    *   **Gray**: Skipped or Error.

## Troubleshooting

### Execution Policy Errors
If you see an error like "running scripts is disabled on this system", you need to temporarily allow script execution. Run the following command in your PowerShell session:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
```

### Network Errors
If the tool fails to fetch versions:
1.  Check your internet connection.
2.  Ensure that `winget` is installed and working if using Winget fetchers.
3.  For GitHub limits, ensure you are not being rate-limited (though unauthenticated requests usually suffice for low volume).

### "Module not found"
Ensure all files are in the correct directory structure as downloaded. The `UpdateChecker.ps1` script relies on the `modules` folder being in the same directory.