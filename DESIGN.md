# PC Update Checker - Architecture Design Document

## 1. Overview
This document defines the architecture for the PC Update Checker, a modular PowerShell tool designed to identify updates for drivers, BIOS, and software. The system uses a pipeline approach where a "Component" object is passed through various stages (Discovery, Version Extraction, Remote Fetching, Comparison, Reporting).

## 2. Configuration Schema (`config.json`)
The configuration file drives the entire process. It contains global settings and a list of components to check.

```json
{
  "global": {
    "timeoutSeconds": 30,
    "parallelExecution": true,
    "maxThreads": 5,
    "reportPath": "./Reports",
    "userAgent": "PCUpdateChecker/1.0",
    "logging": {
      "path": "./Logs",
      "level": "Info"
    }
  },
  "components": [
    {
      "id": "nvidia-driver",
      "name": "NVIDIA Graphics Driver",
      "category": "Driver",
      "priority": "High",
      "autoUpdate": false,
      "detection": {
        "method": "WMI",
        "query": "SELECT DriverVersion FROM Win32_VideoController WHERE Name LIKE '%NVIDIA%'",
        "property": "DriverVersion",
        "transformRegex": "^(\\d+\\.\\d+)" 
      },
      "fetching": {
        "method": "Scrape",
        "url": "https://www.nvidia.com/Download/processDriver.aspx?psid=101&pfid=816&rpf=1",
        "regex": "Version: ([0-9.]+)"
      }
    },
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
    },
    {
      "id": "powertoys",
      "name": "PowerToys",
      "category": "Software",
      "priority": "Low",
      "detection": {
        "method": "Registry",
        "path": "HKLM:\\SOFTWARE\\Microsoft\\PowerToys",
        "key": "Version"
      },
      "fetching": {
        "method": "GitHub",
        "repo": "microsoft/PowerToys",
        "assetRegex": "PowerToysSetup-.*-x64\\.exe"
      }
    }
  ]
}
```

### Supported Methods
*   **Detection Methods:** `WMI`, `Registry`, `File`, `Command`, `SteamManifest`, `EpicManifest`
*   **Fetching Methods:** `Winget`, `GitHub`, `Scrape`, `API`, `Chocolatey`

## 3. Data Structures
The core data structure is a PowerShell Custom Object (`PSCustomObject`) representing a single component. This object is enriched as it moves through the pipeline.

### The `Component` Object
| Property | Type | Origin | Description |
| :--- | :--- | :--- | :--- |
| `Id` | String | Config | Unique identifier (e.g., "vscode") |
| `Name` | String | Config | Display name |
| `Category` | String | Config | "Driver", "BIOS", "Software" |
| `Priority` | String | Config | "High", "Medium", "Low" |
| `AutoUpdate` | Boolean | Config | If true, attempts to update automatically |
| `IsInstalled` | Boolean | Scanner | True if found locally |
| `LocalVersion` | Version/String | Scanner | The currently installed version |
| `RemoteVersion` | Version/String | Fetcher | The latest available version online |
| `ReleaseDate` | DateTime | Fetcher | Date of the remote release (if available) |
| `DownloadUrl` | String | Fetcher | Direct link to the update |
| `UpdateAvailable`| Boolean | Comparator | True if Remote > Local |
| `VersionDiff` | String | Comparator | Textual representation of the update (e.g., "1.0 -> 2.0") |
| `UpdateStatus` | String | Updater | "NotAttempted", "Success", "Failed" |
| `State` | String | System | "Pending", "Checked", "Updated", "Error", "Skipped" |
| `ErrorMessage` | String | System | Details if State is "Error" |

## 4. Module Interfaces

### 4.1 Orchestrator (`Orchestrator.psm1`)
The entry point that coordinates the entire workflow.
*   **Function:** `Invoke-UpdateCheck`
*   **Input:**
    *   `ConfigPath` (string): Path to `config.json`.
*   **Output:**
    *   Returns the path to the generated HTML report.

### 4.2 System Scanner (`SystemScanner.psm1`)
Iterates through the config and determines what is installed.
*   **Function:** `Get-InstalledComponents`
*   **Input:**
    *   `Config` (PSCustomObject): The parsed configuration object.
*   **Output:**
    *   `[PSCustomObject[]]`: Array of Component objects with `IsInstalled` and `LocalVersion` populated.

### 4.3 Version Detector (`VersionDetector.psm1`)
Helper module used by SystemScanner to extract versions from the OS.
*   **Function:** `Get-LocalVersion`
*   **Input:**
    *   `DetectionConfig` (PSCustomObject): The `detection` block from config.
*   **Output:**
    *   `[String]`: The raw version string, or $null if not found.

### 4.4 Version Fetcher (`VersionFetcher.psm1`)
Connects to remote sources to find the latest versions.
*   **Function:** `Get-RemoteVersion`
*   **Input:**
    *   `FetchConfig` (PSCustomObject): The `fetching` block from config.
*   **Output:**
    *   `[PSCustomObject]`: `{ Version, ReleaseDate, DownloadUrl }`

### 4.5 Comparator (`Comparator.psm1`)
Compares local and remote versions. Handles semantic versioning and date-based versioning.
*   **Function:** `Compare-Versions`
*   **Input:**
    *   `LocalVersion` (string)
    *   `RemoteVersion` (string)
*   **Output:**
    *   `[PSCustomObject]`: `{ IsNewer (bool), Diff (string) }`

### 4.6 Report Generator (`ReportGenerator.psm1`)
Generates the final HTML output.
*   **Function:** `New-HtmlReport`
*   **Input:**
    *   `Components` (PSCustomObject[]): The fully processed list of components.
    *   `OutputPath` (string): Where to save the report.
*   **Output:**
    *   `[FileInfo]`: The generated file.
*   **Changes:**
    *   Support for "Updated Successfully" status (Blue).
    *   Separate list for items that were successfully updated vs. those needing manual attention.

### 4.7 Logger (`Logger.psm1`)
Standardized logging.
*   **Function:** `Write-Log`
*   **Input:**
    *   `Message` (string)
    *   `Level` (string): "Info", "Warning", "Error"
    *   `ComponentId` (string, optional)

### 4.8 Game Manifest Fetcher (`GameManifestFetcher.psm1`)
Specialized module for detecting installed game versions from store manifests.
*   **Function:** `Get-GameVersion`
*   **Input:**
    *   `Path` (string): Path to the library or manifest file.
    *   `Platform` (string): "Steam" or "Epic".
*   **Logic:**
    *   **Steam:** Parses `appmanifest_<appid>.acf` looking for the `buildid` key.
    *   **Epic:** Parses `.item` files in the `Manifests` folder looking for the `BuildVersion` key.

### 4.9 Updater (`Updater.psm1`)
Handles the execution of updates for supported components.
*   **Function:** `Invoke-Update`
*   **Input:**
    *   `Component` (PSCustomObject): The component to update.
*   **Logic:**
    *   Checks if `AutoUpdate` is true and `UpdateAvailable` is true.
    *   Delegates to the appropriate fetcher (e.g., `WingetFetcher`) to perform the update.
    *   **WingetFetcher** must expose an `Update-Component` function.
*   **Output:**
    *   `[Boolean]`: True if successful, False otherwise.

## 5. Error Handling Strategy
To ensure robustness, the system uses a **Per-Component Isolation** strategy.

1.  **Try/Catch Blocks:** The Orchestrator wraps the processing of *each* component in a `try/catch` block (or uses `ForEach-Object -Parallel` with internal error handling).
2.  **State Tracking:** If a module fails (e.g., `VersionFetcher` cannot reach GitHub):
    *   The exception is caught.
    *   `Logger` records the full stack trace.
    *   The component's `State` is set to `Error`.
    *   The component's `ErrorMessage` is populated with a user-friendly error.
3.  **Pipeline Continuation:** The failure of one component (e.g., a timeout on a specific website) **does not** stop the execution of others.
4.  **Reporting:** The final HTML report will have a dedicated "Errors/Warnings" section to highlight checks that failed, ensuring the user is aware of incomplete data.

## 6. Workflow Diagram

```mermaid
graph TD
    A[Start] --> B[Load Config]
    B --> C[System Scanner]
    C --> D{Parallel Loop}
    D -->|Component 1| E[Version Fetcher]
    D -->|Component 2| E
    D -->|Component N| E
    E --> F[Comparator]
    F --> G{AutoUpdate & Available?}
    G -->|Yes| H[Updater]
    G -->|No| I[Update Component Object]
    H --> I
    I --> J{All Done?}
    J -->|No| D
    J -->|Yes| K[Report Generator]
    K --> L[End]