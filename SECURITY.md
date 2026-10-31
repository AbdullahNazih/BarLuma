# Security policy

Report suspected vulnerabilities privately to **Abdullah.n.sy@gmail.com**. Include the version, macOS version, impact and a minimal reproduction. Do not include credentials, actual location history or private user files. Please avoid publishing exploitable details before a fix can be coordinated. No response-time or bounty commitment is offered.

## Scope and security design

BarLuma is a local monitor with optional weather requests. It does not inspect packet contents, listen on a port, execute subprocesses at runtime, load plugins, update itself, or require administrator access. It uses native Apple frameworks and has no external package dependencies.

Builds enable App Sandbox and Hardened Runtime. The only requested entitlements are outbound networking, location with macOS permission, and user-selected read/write access for removing the app during uninstall. No debugging, library-validation, JIT, unsigned-code or arbitrary-file-access exceptions are permitted by the build verifier.

Weather is untrusted input. The client restricts requests to two fixed HTTPS Open-Meteo routes, refuses redirects, retains platform TLS certificate validation, requires JSON/HTTP 200, and caps decoded response bodies at 128 KiB while streaming. Coordinates, city labels, temperature, day/night flags, WMO codes and cached timestamps are validated. Malformed values cannot flow into unbounded numeric display conversions. Automatic locations and automatic weather caches are not persisted. See [PRIVACY.md](PRIVACY.md).

The uninstaller accepts only the running bundle, requires confirmation and an explicit user-selected grant, and moves app-owned files to Trash. It has no privileged helper. macOS manages privacy databases, container metadata and system logs; the app does not bypass those protections.

## Development versus distribution

`scripts/build.sh` makes an ad-hoc signed, sandboxed **local development build**. A passing signature check is not a public publisher identity or a security certification. Do not upload this development ZIP as an official public binary.

`scripts/release.sh` requires Developer ID signing, a secure timestamp, matching Apple team, universal arm64/x86_64 binaries, successful Apple notarization, a stapled ticket and a passing Gatekeeper assessment before it creates a versioned distribution archive and SHA-256 checksum. It fails rather than silently substituting an unsigned/ad-hoc release. Apple credentials are required; they are not included in this repository. Notarization checks for known malicious components and is not a guarantee against vulnerabilities.

The executable and bundle identifier retain their original internal `TopBar` / `com.anazih.macos-topbar` values for continuity. The user-facing name is BarLuma. Early unsandboxed development builds may have preferences outside the sandbox; the sandboxed application does not request extra access to read or delete those legacy files.

## GitHub configuration after pushing

1. Protect the default branch: require pull-request review and the **Build and security checks** workflow; restrict direct pushes and workflow changes to trusted maintainers.
2. Enable GitHub private vulnerability reporting, secret scanning and push protection where available. Keep signing certificates, private keys and passwords out of commits; `.gitignore` is only a convenience, not an access control.
3. Create a `release` Actions environment restricted to the protected default branch. Require a trusted reviewer for deployments where the repository plan supports it. Add signing secrets only to that environment.
4. Review Dependabot updates before merging. All referenced Actions are pinned to full commit SHAs. Pull-request CI uses a read-only token, no signing secrets, no `pull_request_target`, no self-hosted runner and no shared build cache.
5. Keep macOS/Xcode updated, review security reports, and make patched releases. Security review is ongoing; automated tests and signing do not prove absence of vulnerabilities.

## Release environment variables and secrets

Environment variables:

* `APPLE_TEAM_ID`: the 10-character Apple Developer team identifier.
* `TOPBAR_SIGNING_IDENTITY`: exact `Developer ID Application: Name (TEAMID)` identity.

Environment secrets:

* `APPLE_CERTIFICATE_P12_BASE64`: base64-encoded Developer ID Application certificate and private key export.
* `APPLE_CERTIFICATE_PASSWORD`: password protecting that export.
* `APPLE_ID`: Apple account used for notarization.
* `APPLE_APP_SPECIFIC_PASSWORD`: app-specific password for notarization, not the Apple account password.

The manual **Signed and notarized release** workflow runs only against the default branch. It tests before loading secrets, creates an isolated temporary keychain with restricted file permissions, and deletes it on exit. It uploads only the notarized ZIP and checksum as a short-lived Actions artifact. Publishing that verified artifact as a GitHub Release is a separate maintainer action. Do not put secrets in workflow inputs, PR text, command tracing, artifacts or source files.

For a local public release, configure a `notarytool` keychain profile, export `TOPBAR_NOTARY_PROFILE`, `TOPBAR_SIGNING_IDENTITY` and `APPLE_TEAM_ID`, and run `zsh scripts/release.sh`. See [Apple's notarization documentation](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## Verification and limitations

Run `zsh scripts/test.sh`, `zsh scripts/build.sh`, and `zsh scripts/sandbox-smoke.sh`. The smoke test uses a known-readable, non-sensitive fixture outside the container to check denial, and verifies CPU/RAM access. Set `BARLUMA_REQUIRE_NETWORK=1` on a connected Mac to require network counter access as well. `zsh scripts/test.sh --live-weather` optionally checks the real API using fixed non-personal test inputs.

Current checks are not an independent penetration test. A new release should also be tested on clean user accounts, supported macOS releases, Intel and Apple silicon hardware, and with location denied/offline/sleep/wake/login-item/uninstall scenarios. The local build cannot validate the Apple notarization path without your credentials. Never work around a failed release check by disabling Gatekeeper, SIP, TLS validation, sandboxing or Hardened Runtime.
