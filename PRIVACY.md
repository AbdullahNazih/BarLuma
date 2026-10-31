# BarLuma privacy notice

Effective 31 October 2026.

BarLuma has no advertising, analytics, accounts, remote control, packet capture or listening server. CPU, RAM and network byte counters are read locally and are not uploaded.

**Check for Updates…** opens the project's GitHub Releases page in your browser. BarLuma does not poll GitHub in the background, download executables or install updates. GitHub/browser privacy settings apply when you visit that page.

## Weather and location

Weather is optional. macOS asks before automatic location access is granted. BarLuma requests a coarse, one-shot fix, rounds coordinates to two decimal places (roughly 1 km), and sends only those rounded coordinates to Open-Meteo for weather and Apple's geocoder for a city label. The location service itself is managed by macOS.

Automatic locations and their weather cache stay in process memory and are discarded when the app quits. They are not written to BarLuma's preferences. A manually selected city and its most recent weather response are stored locally in the app's sandbox. City search sends the submitted city name to Open-Meteo. Manual city preferences are not encrypted by BarLuma; protect your macOS account and disk as appropriate.

API providers can see the connecting IP address and request parameters. Their processing is governed by their own policies, including [Open-Meteo's privacy notice](https://open-meteo.com/en/terms) and [Apple's privacy policy](https://www.apple.com/legal/privacy/). HTTPS protects requests in transit; it does not hide them from their recipients. The app does not add a stable user or device identifier.

Turning weather off stops weather refreshes and location requests and removes the persisted weather-response cache. Selecting a fixed city disables automatic location requests. macOS Location Services permission can be revoked in System Settings. Uninstall clears BarLuma's saved preferences and app-owned caches. macOS retains control of system privacy records, container metadata and logs.

## Permissions and file access

App Sandbox limits access to the app's container, outbound network requests, location with permission, and files you explicitly select. BarLuma does not request administrator access, Full Disk Access, Accessibility or Screen Recording. Uninstall asks you to select the running app so macOS can authorize moving that one application to Trash; no ongoing file-access bookmark is saved.

## Contact

Privacy and security enquiries: Abdullah.n.sy@gmail.com.
