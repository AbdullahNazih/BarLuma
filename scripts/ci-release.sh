#!/bin/zsh
set -euo pipefail
umask 077
cd "$(dirname "$0")/.."
: "${APPLE_CERTIFICATE_P12_BASE64:?Missing certificate secret}"
: "${APPLE_CERTIFICATE_PASSWORD:?Missing certificate password secret}"
: "${APPLE_ID:?Missing Apple ID secret}"
: "${APPLE_TEAM_ID:?Missing Apple team ID}"
: "${APPLE_APP_SPECIFIC_PASSWORD:?Missing notarization secret}"
: "${TOPBAR_SIGNING_IDENTITY:?Missing Developer ID signing identity}"
signing_directory=$(mktemp -d "${RUNNER_TEMP:?This script requires an ephemeral CI runner}/barluma-signing.XXXXXX")
keychain="$signing_directory/release.keychain-db"
cleanup() {
    security delete-keychain "$keychain" >/dev/null 2>&1 || true
    rm -rf "$signing_directory"
}
trap cleanup EXIT
keychain_password=$(openssl rand -hex 32)
printf '%s' "$APPLE_CERTIFICATE_P12_BASE64" | base64 --decode > "$signing_directory/certificate.p12"
security create-keychain -p "$keychain_password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
security import "$signing_directory/certificate.p12" -k "$keychain" -P "$APPLE_CERTIFICATE_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$keychain" >/dev/null
xcrun notarytool store-credentials barluma-ci --keychain "$keychain" --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD"
rm -f "$signing_directory/certificate.p12"
unset APPLE_CERTIFICATE_P12_BASE64 APPLE_CERTIFICATE_PASSWORD APPLE_APP_SPECIFIC_PASSWORD APPLE_ID
export TOPBAR_KEYCHAIN_PATH="$keychain"
export TOPBAR_NOTARY_PROFILE=barluma-ci
zsh scripts/release.sh
