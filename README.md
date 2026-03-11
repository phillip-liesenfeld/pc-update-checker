# PC Update Checker

A modular PowerShell tool that audits your Windows machine for outdated software, drivers, and games — then generates a clean, filterable HTML report.

---

## What It Does

Keeping a gaming or development PC up to date is tedious. GPU drivers, peripheral software, game launchers, and productivity tools all update independently, with no unified dashboard.

PC Update Checker solves this by:

- **Scanning** your system for installed software using multiple detection methods (WMI, Registry, file metadata, game store manifests)
- **Fetching** the latest available versions from multiple upstream sources: Winget, the GitHub Releases API, and targeted web scraping
- **Comparing** local vs. remote versions using a normalization-aware comparator that handles semantic versioning, non-standard formats, and `v`-prefixed tags
- **Auto-updating** any component that has `autoUpdate: true` in config, via `winget upgrade`
- **Generating** a timestamped HTML report with per-component status cards, summary statistics, and a live search/filter UI

The default `config.json` covers 13 components across drivers, gaming peripherals, game launchers, and titles (NVIDIA driver, VS Code, PowerToys, ASUS Armoury Crate, GeForce Experience, Razer Synapse, Razer Cortex, Logitech Options+, Steam, Epic Games Launcher, Battle.net, Cyberpunk 2077, Fortnite).

---

## Why I Built It

I got tired of manually checking whether my NVIDIA driver, Razer Synapse, and a handful of other tools were current. Most solutions either required a paid app, only covered software in a single store, or didn't handle games at all.

I built this as a practical PowerShell exercise: a real problem, solved with a system I could actually use and extend. After running it on my own machine and iterating on the failure modes (scraping fragility, Winget edge cases, version string normalization edge cases), it grew into something worth sharing.

---

## AI-Assisted Development

This project was built using AI-assisted development with Claude (Anthropic).

In practice, that means:

- **Problem decomposition:** I identified the architecture — the pipeline of Scanner → Fetcher → Comparator → Reporter — and defined the interfaces between each module before any code was written.
- **Directing the agent:** I wrote detailed prompts that specified behavior, edge cases, and failure modes. The agent produced module skeletons; I reviewed, ran them, and fed back what broke.
- **Validation and iteration:** When scraping strategies failed on real sites (NVIDIA's JS-rendered pages, Razer's marketing redirects), I diagnosed the root cause and directed targeted fixes — including the multi-strategy fallback architecture documented in `ANALYSIS_AND_PLAN.md`.
- **Ownership of decisions:** What to check, how to structure the config schema, which failure modes to handle gracefully, and how to present output were all my decisions. The agent accelerated implementation; I directed the outcome.

This is the way I think AI tooling should be used in engineering: not as a replacement for design judgment, but as a force multiplier for execution.

---

## How to Use It

### Requirements

- **PowerShell 5.1** or later (PowerShell 7+ recommended for performance)
- **Winget** (Windows Package Manager — included by default on Windows 11; install via App Installer on Windows 10)
- Internet access for fetching remote versions
- **No admin rights required** for read-only checks; admin is needed if `autoUpdate: true` is set for any component

### Run

```powershell
# Navigate to the project folder
cd path\to\pc-update-checker

# Run with default config
.\UpdateChecker.ps1

# Run with a custom config
.\UpdateChecker.ps1 -ConfigPath "C:\path\to\my-config.json"
```

If you see an execution policy error:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
```

### Output

After execution:

- An HTML report is saved to `./Reports/UpdateReport_<timestamp>.html` and opened automatically in your default browser
- A desktop notification summarizes how many updates were found
- A log file is written to `./Logs/UpdateChecker_<date>.log`

The report shows each component as a card with:
- Local version vs. latest available version
- Status badge (Up to Date / Update Available / Updated / Error / Not Installed)
- A download link when available
- Live search and filter controls by status

### Customizing `config.json`

To add a new component, append an entry to the `components` array:

```json
{
  "id": "my-app",
  "name": "My App",
  "category": "Software",
  "priority": "Medium",
  "autoUpdate": false,
  "detection": {
    "method": "File",
    "path": "C:\\Program Files\\MyApp\\myapp.exe",
    "property": "ProductVersion"
  },
  "fetching": {
    "method": "Winget",
    "packageId": "Publisher.MyApp"
  }
}
```

**Detection methods:** `File`, `Registry`, `WMI`, `Command`, `SteamManifest`, `EpicManifest`

**Fetching methods:** `Winget`, `GitHub`, `Scrape` — or use `strategies` for ordered fallback:

```json
"fetching": {
  "strategies": [
    { "method": "Winget", "packageId": "Publisher.MyApp" },
    { "method": "GitHub", "repo": "publisher/myapp" }
  ]
}
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | PowerShell 5.1 / 7+ |
| System introspection | WMI (`Get-CimInstance`), Registry (`Get-ItemProperty`), file metadata (`VersionInfo`) |
| Package resolution | Winget CLI (`winget show`, `winget upgrade`) |
| Remote fetching | GitHub Releases REST API, `Invoke-WebRequest` for scraping |
| Game manifests | Steam `.acf` manifest parsing, Epic Games `.item` JSON parsing |
| Reporting | Self-contained HTML + vanilla JS (no external dependencies) |
| Notifications | BurntToast (if installed) with `.NET` `NotifyIcon` fallback |

---

## What It Demonstrates

**For a technical hiring audience:**

- **PowerShell systems programming** — WMI queries, registry reads, process spawning, version metadata extraction across multiple Windows APIs
- **Modular design** — nine single-responsibility modules with defined interfaces, allowing each stage to be replaced or extended independently
- **Robust error handling** — per-component isolation means one failed network request or missing binary doesn't abort the entire run; errors surface in the report without crashing the pipeline
- **Multi-strategy resilience** — the fetching layer supports an ordered strategy list (Winget → GitHub → Scrape), with each method tried in sequence until one succeeds
- **Version normalization** — the comparator handles `v`-prefixed tags, inconsistent segment counts, and non-numeric pre-release segments without false positives
- **Practical systems thinking** — the `ANALYSIS_AND_PLAN.md` document captures a real debugging cycle: identifying why scraping failed on specific sites, proposing the multi-strategy architecture, and verifying Winget package IDs as replacements
- **HTML report generation** — templated output with dynamic stat cards, color-coded status, and a live search/filter UI built in vanilla JS, all generated entirely within PowerShell
- **AI-assisted development workflow** — experience directing an LLM agent for implementation while retaining ownership of architecture, validation, and iteration decisions
