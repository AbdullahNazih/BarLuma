# Using BarLuma

[Download](https://github.com/AbdullahNazih/BarLuma/releases/tag/v1.1.1-preview.1) · [Back to the overview](../README.md)

## Install and open

Download `BarLuma-1.1.1-preview.pkg`, double-click it and follow macOS Installer. It installs for your account into `~/Applications`. Open BarLuma with Spotlight or from that folder. The current installer is an **unsigned, unnotarized preview**; macOS may warn or block it. Packaging and the included checksum do not establish a verified publisher identity. Do not disable macOS security protections to use it.

Requires macOS 13 or later. The installer includes Apple silicon and Intel versions. Close a running copy if Installer asks you to do so. Installation does not automatically grant location access or enable launch at login.

## Where is the window?

BarLuma lives in the **menu bar**, near the clock and battery. It has no Dock icon. Click any reading for the dashboard, then select Settings. Reopening the app also opens Settings. If all modules are off, a small control icon remains so you can turn them back on. A crowded menu bar or a display notch can limit space; try hiding unneeded modules.

## Customize the readings

Use the switches in the dashboard or Settings to show or hide Network, CPU, RAM and Weather. Drag the dashboard's title bar to move it. The close button dismisses it while monitoring continues. Settings offers 2-, 3-, 5- or 10-second refresh intervals and an optional Open at login switch. Slower intervals reduce polling overhead.

## Weather and location

Allow the macOS location prompt for automatic weather. If permission was denied, manage it in **System Settings → Privacy & Security → Location Services**. To avoid automatic location, turn off **Use my location automatically**, search for a city and select a result. Switching modes clears the previous location selection.

Conditions refresh about every 15 minutes. Use the refresh button in Settings to retry after a connection problem. Out-of-date weather is marked unavailable; an icon alone does not guarantee a fresh report. Temperature is currently Celsius. Weather represents model-based local conditions and may differ from what you see outside.

Automatic locations are not saved by BarLuma. Fixed-city preferences are stored locally. Weather providers receive rounded coordinates and the connection's IP address. [Full privacy notice](../PRIVACY.md).

## Why do readings differ from other apps?

**Mbps** means megabits per second, not megabytes: 8 Mbps is about 1 MB/s. Network measures traffic through the active physical connection, including local network transfers; it is not an internet speed test. VPN tunnel interfaces are excluded to avoid counting traffic twice. A dash can appear while a new sampling baseline is established or a connection is unavailable.

CPU is normalized across all cores to 0–100%. RAM includes app, wired and compressed memory; caches and sampling differences can make its value differ from Activity Monitor. These values are system-wide, not just BarLuma's usage.

## Get updates

Use **About → Check for Updates…** to browse stable and preview releases. To subscribe, sign into GitHub and choose **Watch → Custom → Releases** on the repository. GitHub handles notifications according to your account preferences. BarLuma does not automatically download or install updates. Read each release's compatibility and signing notes before installing it.

## Uninstall

Open **Settings → Uninstall BarLuma…**. Confirm, then select the running BarLuma application when macOS asks for file access. Only that app can be selected for removal. Canceling either step leaves it installed.

Uninstall removes its login item, saved preferences and app-owned caches, moves the app to Trash and quits. macOS-managed package receipts, container metadata, privacy records and system logs may remain. Other app copies and downloaded installers are not removed.

## Need help?

Use [bug reports](https://github.com/AbdullahNazih/BarLuma/issues/new?template=bug_report.yml) for reproducible problems and [feature requests](https://github.com/AbdullahNazih/BarLuma/issues/new?template=feature_request.yml) for suggestions. Include the BarLuma version from About, macOS version, Mac type and steps to reproduce. Redact personal details from screenshots. Never post passwords, precise locations or sensitive logs.

For security issues, use [private vulnerability reporting](https://github.com/AbdullahNazih/BarLuma/security/advisories/new) or email Abdullah.n.sy@gmail.com. Enterprise licensing enquiries use the same email address.
