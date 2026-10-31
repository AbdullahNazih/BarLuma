# Changelog

## 1.1.1 — 31 October 2026

* Colored weather icons in the menu bar, dashboard and Settings: yellow sun, silver-gray moon/clouds, blue rain and cyan snow.
* Single-file unsigned preview installer for Apple silicon and Intel. Installs only in the current user's Applications folder, without install scripts or a license-acceptance screen.
* Installer inspection and color regression checks added to CI. Official notarized binary releases still require Developer ID credentials.

## 1.1.0 — 31 October 2026

Initial public source release under the name **BarLuma**, previously MAC OSx - TopBar.

* Native menu bar download/upload Mbps, CPU percentage, RAM percentage and optional local weather.
* Independent module switches, optional Celsius temperature, adjustable refresh speed and optional launch at login.
* Movable dashboard with screen margins, scrolling and close controls; responsive Settings.
* About, personal-use license, enterprise contact and an in-app privacy notice.
* GitHub release link and instructions for subscribing to release notifications; no automatic downloader.
* App Sandbox and Hardened Runtime, with a verified minimal entitlement set.
* Fixed HTTPS weather routes, redirect refusal, bounded responses and validation of network/cache values.
* Automatic locations/weather kept out of saved preferences; rounded coordinates for weather and city lookup.
* Confirmed uninstall with explicit user-selected authorization for the running app.
* Adversarial-input tests, sandbox smoke checks, pinned least-privilege CI and an optional future Developer ID/notarization release workflow.

This release provides source for local builds. Public notarized binaries are not available yet. Apple Developer credentials are not included.
