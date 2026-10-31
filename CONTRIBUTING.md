# Contributing to BarLuma

BarLuma is source-available under the personal-use terms in [LICENSE.txt](LICENSE.txt). Business/enterprise use requires separate terms. Please discuss substantial changes before submitting a pull request.

Use a current macOS/Xcode or Command Line Tools installation with Swift 6.2 or newer. Run:

```sh
zsh scripts/test.sh
zsh scripts/build.sh
zsh scripts/sandbox-smoke.sh
```

Tests must use synthetic locations and non-sensitive fixtures. The optional `zsh scripts/test.sh --live-weather` uses fixed test inputs and contacts Open-Meteo; ordinary tests do not need internet access. Never commit certificates, keys, tokens, credentials, real location data or a local development ZIP.

Preserve platform TLS checks, sandboxing and Hardened Runtime. New entitlements or network endpoints need explicit justification and review. Add adversarial-input tests for parsing changes and test denied permissions/offline behavior for UI changes. Do not add install-time license prompts or silently enable login items.

Report vulnerabilities privately as described in [SECURITY.md](SECURITY.md). A passing CI run is not permission to publish a binary; official release artifacts must complete the separate signing/notarization process.
