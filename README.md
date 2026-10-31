# BarLuma

A native macOS menu bar companion for network speed, CPU, memory and local weather. Previously developed as **MAC OSx - TopBar**.

**Free for personal, non-commercial use.** Source-available under [LICENSE.txt](LICENSE.txt). For business, institutional or enterprise use, contact **Abdullah.n.sy@gmail.com**. This is not an unrestricted open-source license.

| Module | Menu bar display |
| --- | --- |
| Network | Download and upload throughput in **Mbps** |
| CPU | Total processor utilization, **0–100%** |
| Memory | Physical RAM utilization, **0–100%** |
| Weather | Sun, moon, cloud, fog, rain, snow or storm icon; optional **°C** |

Each module has its own on/off switch. Click a reading to open the movable dashboard. Drag its title bar to reposition it, or close it with the close button. Screen margins and scrolling keep controls accessible on smaller displays. Settings also includes About, refresh speed, optional launch at login and uninstall. When all modules are off, a small control icon remains available.

## Getting started without an Apple Developer account

### Single-file preview installer

For a local preview, run `zsh scripts/package-preview.sh` to produce `dist/BarLuma-1.1.1-preview.pkg`. Double-click that file and follow macOS Installer's prompts. It installs the universal Apple silicon/Intel app into **your `~/Applications` folder**. Open BarLuma from Spotlight or that folder after installation. No Terminal commands are needed by the installer user, and there is no license-acceptance screen or install script.

This package is **unsigned and not notarized**. macOS may warn or block it; packaging does not change its trust status. It is a development preview, not the future verified public distribution build. The installer does not alter Gatekeeper or other security settings. It records a standard macOS package receipt; those OS-managed receipts may remain after app uninstall.

### Build from source

You can publish this source repository, run CI, and build locally without a paid Apple Developer account. Requires macOS 13 or later and Swift 6.2 or newer. Install Apple's Command Line Tools if needed:

```sh
xcode-select --install
```

From the project folder:

```sh
zsh scripts/test.sh
zsh scripts/build.sh
zsh scripts/sandbox-smoke.sh
open "dist/BarLuma.app"
```

The local build uses your Mac's architecture and is **ad-hoc signed for local development**. It still enables App Sandbox and Hardened Runtime. It is not Developer ID signed or Apple-notarized; do not present it as an official public release. Source users can build locally. Do not disable Gatekeeper, SIP or other macOS protections to distribute a development binary.

To keep your local build installed, quit it, move it to Applications, and reopen it there. No license key, acceptance screen or activation step is required. About opens only when selected.

## Security and public distribution

BarLuma uses native Apple frameworks, no third-party package dependencies, no runtime shell commands, no analytics and no server component. App Sandbox permits only outbound networking, location with permission, and explicitly selected files for uninstall. The weather client uses fixed HTTPS endpoints, refuses redirects, caps decoded responses at 128 KiB and validates external/cached values.

The included GitHub CI workflow runs functional/adversarial checks, builds the sandboxed application and verifies both its signing protections and sandbox isolation. It uses read-only permissions, pinned Action commits and no signing secrets. No ad-hoc build artifacts are uploaded by PR CI.

A separate **manual** release workflow is provided for later use with an Apple Developer account. It requires Developer ID credentials, builds arm64 and Intel binaries, signs with Hardened Runtime, notarizes with Apple, staples the ticket, checks Gatekeeper and produces a versioned ZIP with a SHA-256 checksum. Missing credentials or failed checks stop the release. It does not run automatically when you push source or open a pull request.

Read [SECURITY.md](SECURITY.md) for reporting, repository protection, release environment setup, threat boundaries and test limitations. Credentials are intentionally absent. The Apple notarization path cannot be verified until you supply your own Developer ID/account. No security certification or guarantee is claimed.

## Weather and privacy

Automatic location is the default. Allow location in the macOS prompt, or select a fixed city in Settings. The app requests a coarse one-shot location on launch and at most every six hours while weather is active, or when you choose Update location. Coordinates are rounded to two decimal places before being sent to Open-Meteo for weather and Apple for a city label. Automatic locations and automatic weather responses stay in memory and are not saved to preferences.

Turning off automatic location clears that location; search and select a city for fixed-city weather. A manually selected city and its latest weather response are saved locally inside the sandbox. Weather refreshes every 15 minutes, handles offline errors, and marks old data unavailable. Turning weather off stops weather/location work and clears the persisted response cache. See [PRIVACY.md](PRIVACY.md), also available in About.

Weather data by [Open-Meteo](https://open-meteo.com/), licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The public API is free for noncommercial use and needs no key. Enterprise deployment may require separate commercial provider access. The app's enterprise license does not override the provider's terms.

## Measurement and energy behavior

Network readings use 64-bit byte counters on the primary physical connection, including local network traffic. VPN tunnel interfaces are excluded to avoid double counting. This is traffic throughput, not an active internet speed test. **1 Mbps = 1,000,000 bits per second.** Connection changes and counter resets establish a new baseline instead of showing spikes.

CPU is utilization across all cores, normalized to 100%. RAM includes app, wired and compressed memory and excludes purgeable caches; readings may differ slightly from Activity Monitor.

One coalescible timer samples enabled local metrics every 3 seconds by default. Choose 2, 3, 5 or 10 seconds. Disabled modules are not sampled. The timer is removed when all local modules are off. Sampling pauses during sleep and resets baselines on wake. Low Power Mode uses at least a 10-second interval. Hidden dashboard, Settings and About views are released. Battery impact depends on settings and use; zero impact is not promised.

## Uninstall

Choose **Settings → Uninstall BarLuma…** and confirm. Because the app is sandboxed, macOS then asks you to select the running BarLuma application to authorize its removal. Selecting another app is rejected. Canceling either step leaves the app installed.

The app unregisters its login item, stops work, moves app-owned caches/support files and the selected app to Trash, clears its saved preferences, then quits. There is no privileged uninstaller. macOS controls container metadata, privacy records and system logs. Source files, installers and other app copies remain. Early unsandboxed development versions may have separate preferences outside the container; the sandboxed app does not request broad access to those legacy files.

## Verification and contributing

`zsh scripts/test.sh` runs seventeen checks including weather icon colors, malicious numeric inputs, endpoint/redirect/response-size policy, location persistence, uninstall authorization, display placement, metric calculations and real macOS metric readers. `zsh scripts/sandbox-smoke.sh` checks CPU/RAM access and denial of a known-readable file outside the sandbox; use `BARLUMA_REQUIRE_NETWORK=1` on a connected Mac to also require network counter access.

The optional `zsh scripts/test.sh --live-weather` validates real weather and city-search responses with fixed, non-personal inputs. Tests do not replace independent review or clean-machine testing on all supported systems. See [CONTRIBUTING.md](CONTRIBUTING.md).

The internal executable remains `TopBar` and the bundle identifier remains `com.anazih.macos-topbar` for continuity. The displayed application name is BarLuma.

## Update notifications

Choose **About → Check for Updates…** to open the [latest GitHub release](https://github.com/AbdullahNazih/BarLuma/releases). To receive GitHub notifications, open the [repository](https://github.com/AbdullahNazih/BarLuma), choose **Watch → Custom**, enable **Releases**, and save. GitHub delivers notifications according to your account settings. A new commit alone is not an update notification; a maintainer publishes a new Release.

The current app performs no background update checks and does not download or execute updates. Initial GitHub releases provide source and local build instructions. Developer ID signing/notarization and a securely signed updater can be added later; an Apple Developer account does not itself implement an updater. See [UPDATING.md](UPDATING.md).
