# Updates through GitHub

## For users

Open **About → Check for Updates…** to visit [the latest release](https://github.com/AbdullahNazih/BarLuma/releases). Compare its version with the version in About and read the release notes.

For notifications, sign into GitHub, open [BarLuma](https://github.com/AbdullahNazih/BarLuma), choose **Watch → Custom → Releases**, and save. GitHub uses your notification preferences for web, email or mobile notifications. This subscription is optional; you can view public releases without subscribing.

There is no in-app polling, push notification permission, hidden downloader or automatic installation in this version. Source releases include instructions for building locally. Preserve your settings by keeping the bundle identifier unchanged when building updated source.

## For maintainers

1. Update `CFBundleShortVersionString` and increment `CFBundleVersion` in `Resources/Info.plist`; update the changelog.
2. Run local tests, sandbox smoke checks and CI. Review all changes before releasing. Security-sensitive issues should be coordinated privately.
3. Publish a GitHub Release from the reviewed, passing commit with a version tag such as `v1.1.0`. Include what changed, security fixes, compatibility notes and installation/build instructions.
4. While there is no Apple Developer account, publish **source-only releases** using GitHub's generated source archives. Do not attach the ad-hoc development `.app` as a notarized or official signed download.
5. Publishing the Release lets users who subscribed to Releases receive GitHub notifications. Pushing commits or tags without a published Release is insufficient for this channel.

After Developer ID credentials are available, the separate manual release workflow can create verified notarized distribution archives. Review its result, then attach only its ZIP and checksum to a GitHub Release. The source CI never uploads a development binary for public distribution.

## Future automatic updates

An Apple Developer account enables Developer ID signing and notarization, not automatic updates by itself. A future updater needs its own implementation and authenticated update metadata/archive verification. For direct distribution, evaluate a maintained framework such as [Sparkle](https://sparkle-project.org/documentation/) with its current signing requirements, including EdDSA update signatures and Apple code signing. Store private update-signing keys separately from the repository, test rollback/key-rotation behavior, obtain appropriate user consent, and add the updater's dependencies/permissions to security review. Do not replace this browser link with code that downloads and executes an unverified GitHub asset.

## Preview installers

Unsigned `.pkg` files may be explicitly offered as **development previews**, clearly labeled unsigned/not notarized with the same limitations as local builds. They contain the verified sandboxed/hardened app, install only for the current user, and have no install scripts or license gate. They are not a substitute for the Developer ID/notarization path and must not be represented as verified official distribution binaries. The in-app link opens all releases so users can also see these preview versions.
