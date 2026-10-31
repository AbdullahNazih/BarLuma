#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
: "${TOPBAR_NOTARY_PROFILE:?Configure a notarytool keychain profile before making a public release.}"
export TOPBAR_BUILD_MODE=distribution
zsh scripts/build.sh
APP="$PWD/dist/BarLuma.app"
notary_arguments=(--keychain-profile "$TOPBAR_NOTARY_PROFILE")
if [[ -n "${TOPBAR_KEYCHAIN_PATH:-}" ]]; then notary_arguments+=(--keychain "$TOPBAR_KEYCHAIN_PATH"); fi
submission="$PWD/.build/BarLuma-notary-submission.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$submission"
xcrun notarytool submit "$submission" "${notary_arguments[@]}" --wait --timeout 20m --output-format json > .build/notary-result.json
python3 - <<'PY'
import json
from pathlib import Path
result = json.loads(Path('.build/notary-result.json').read_text())
if result.get('status') != 'Accepted':
    raise SystemExit('Apple did not accept this build. No distribution archive will be produced.')
PY
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"
python3 scripts/check-security.py "$APP" distribution
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
[[ "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || { echo 'Invalid release version.' >&2; exit 1; }
archive="BarLuma-v$version.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$PWD/dist/$archive"
cd dist
shasum -a 256 "$archive" > "$archive.sha256"
echo "Verified distribution archive: $archive"
