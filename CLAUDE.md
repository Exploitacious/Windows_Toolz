# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

Windows_Toolz is Umbrella IT Group's MSP PowerShell toolkit for Windows 10/11/Server 2016+. It contains production scripts for endpoint management, RMM platform integration (Ninja and Datto), software lifecycle management, security auditing, and system maintenance. Scripts are designed for deployment via RMM agents or curl-able one-liners. Licensed under Unlicense (public domain).

## Architecture

- **Curl-able/** — Self-contained, downloadable script suites with curl-able entry points (e.g., `curl -L cleanup.umbrellaitgroup.com`). Each subfolder is a complete workflow with a CMD launcher, PS1 workers, and README.
  - `Windows_Debloat/` — System optimization and bloatware removal (OS-aware Win10/11/Server). `Main-Stager.ps1` orchestrates execution. `Comb-HKCU-Reference.txt` is a draft pattern for consolidating HKCU scripts.
  - `Windows_Update_Reset/` — Reset Windows Update components
  - `Windows_Events_Audit/` — Security forensic timeline generation from Event Logs + Edge history
  - `Windows_Device_Decommission/` — Device deprovisioning
- **NinjaRMM/** — Scripts optimized for Ninja RMM (custom fields, Ninja alert functions, `$env:` variable injection). Active platform.
  - `z.NinjaScriptingTemplatePrompt/` — Script template + AI prompt for generating new Ninja scripts
- **Datto-To-Ninja/** — Datto RMM scripts pending migration to Ninja. Contains both feature-specific folders (BSOD, Dell OMSA 9 subsystems, reboots, updates, WAU) and category folders imported from Scratch (Monitoring, Remediation, Security, Infrastructure).
- **Software-Management/** — Third-party software install/uninstall/monitor scripts organized by vendor (BitDefender, BlackPoint, Chrome, CloudRadial, DNSFilter, MDE, Nodeware, PrinterLogic, ScreenConnect, Teams, Threatlocker, Zoom, etc.). Also contains RMM-specific scripting templates in `DattoRMM/a.DRMM-ScriptingTemplates/`.
- **Compliance/** — Intune compliance validation scripts per vendor (BlackPoint, NinjaRMM, Nodeware) with JSON validation schemas.
- **Utilities/** — Platform-agnostic tools: cleanup/debloat, decommission, Office shared activation, MXVPN, SARA, M365 phishing purge, ODT, OneDrive, PS modules, Winget, DNS enum, speedtest, Autopilot upload, TLS upgrade, and misc system utilities.
- **Windows-Server/** — Server infrastructure: DC setup (2019 explicit + DSC), AD tools (GPO reports, LGPO backup/restore, admin list, AAD Connect test, UPN conversion, user attributes).
- **Workstation-Provisioning/** — New machine setup: Dell Command updates, Lenovo setup, NTP sync, Windows Management Framework.
- **Helpers/** — Binary dependencies (CloudRadial DataAgent, SQLite DLLs) and shared module (`UniversalAdminFunctions.psm1` — logging, reboot detection, software inventory, compression).
- **TODELETE/** — Dev artifacts and obsolete drafts pending review.

## Key Technical Details

- **Language:** PowerShell 5.1 (113 scripts), CMD/BAT launchers (9), Shell scripts (3 for Linux)
- **Line endings:** LF enforced via `.gitattributes`
- **RMM integration patterns:**
  - **Ninja:** Uses `Ninja-Property-Set` for custom fields, `$env:` variables for script parameters injected by RMM
  - **Datto:** Writes to UDFs via `New-ItemProperty "HKLM:\Software\CentraStage" -Name "CustomN"`, uses Datto alert functions
- **Curl-able pattern:** CMD launcher downloads PS1 scripts from GitHub raw URLs, executes in sequence. URLs map through Umbrella DNS (e.g., `cleanup.umbrellaitgroup.com`)
- **Software-Management pattern:** Each vendor folder follows `[Vendor]-Install.ps1` / `[Vendor]-Uninstall.ps1` / `[Vendor]-Monitor.ps1` convention
- **No build system or test framework** — scripts are standalone and independently deployable

## Working With This Repo

- Scripts must be self-contained and independently deployable via RMM or direct execution. No inter-file dependencies except within Curl-able workflow suites.
- When writing PowerShell: target PS 5.1, use comment-based help (`.SYNOPSIS`, `.DESCRIPTION`), avoid external module dependencies unless the script installs them at runtime.
- New Ninja scripts should follow the template in `NinjaRMM/z.NinjaScriptingTemplatePrompt/Template.ps1`.
- New software management scripts should follow the Install/Uninstall/Monitor pattern in existing vendor folders.
- Datto-To-Ninja scripts need their Datto-specific integration points (UDF writes, alert functions) adapted to Ninja equivalents before deployment.

## Known Issue

`Curl-able/Windows_Debloat/1Click-1Line-Launcher.cmd` has a structural bug: `goto :CheckAdmin` at the end creates an infinite loop. A fix exists in `TODELETE/Dev-Artifacts/1Click-1Line-Launcher-BUGFIX.txt` (adds retry logic and proper flow control) but references non-existent file paths — needs manual reconciliation.
