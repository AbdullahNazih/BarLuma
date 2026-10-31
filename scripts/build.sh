#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swift-cache"
BUILD_MODE="${TOPBAR_BUILD_MODE:-local}"
case "$BUILD_MODE" in
    local) ;;
    distribution)
        [[ "${TOPBAR_SIGNING_IDENTITY:-}" == 'Developer ID Application: '* ]] || { echo 'A Developer ID Application signing identity is required.' >&2; exit 1; }
        [[ "${APPLE_TEAM_ID:-}" =~ '^[A-Z0-9]{10}$' ]] || { echo 'APPLE_TEAM_ID must identify your Apple Developer team.' >&2; exit 1; }
        ;;
    *) echo 'TOPBAR_BUILD_MODE must be local or distribution.' >&2; exit 1 ;;
esac
if [[ "$BUILD_MODE" == distribution ]]; then
    binaries=()
    for architecture in arm64 x86_64; do
        swift build -c release --arch "$architecture" --disable-sandbox --cache-path .build/cache
        binary_directory=$(swift build -c release --arch "$architecture" --show-bin-path --disable-sandbox --cache-path .build/cache)
        binaries+=("$binary_directory/TopBar")
    done
    lipo -create "${binaries[@]}" -output .build/BarLuma-universal
    BINARY="$PWD/.build/BarLuma-universal"
else
    swift build -c release --disable-sandbox --cache-path .build/cache
    binary_directory=$(swift build -c release --show-bin-path --disable-sandbox --cache-path .build/cache)
    BINARY="$binary_directory/TopBar"
fi
APP="$PWD/dist/BarLuma.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/TopBar.next"
mv -f "$APP/Contents/MacOS/TopBar.next" "$APP/Contents/MacOS/TopBar"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp LICENSE.txt "$APP/Contents/Resources/License.txt"
cp PRIVACY.md "$APP/Contents/Resources/Privacy.md"
if [[ -f Resources/AppIcon.icns ]]; then
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
    /usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string AppIcon' "$APP/Contents/Info.plist"
fi
sign_arguments=(--force --options runtime --entitlements Resources/TopBar.entitlements)
if [[ "$BUILD_MODE" == distribution ]]; then
    sign_arguments+=(--sign "$TOPBAR_SIGNING_IDENTITY" --timestamp)
    if [[ -n "${TOPBAR_KEYCHAIN_PATH:-}" ]]; then sign_arguments+=(--keychain "$TOPBAR_KEYCHAIN_PATH"); fi
else
    sign_arguments+=(--sign - --timestamp=none)
fi
codesign "${sign_arguments[@]}" "$APP"
python3 scripts/check-security.py "$APP" "$BUILD_MODE"
echo "Built ($BUILD_MODE): $APP"
