#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
export TOPBAR_BUILD_MODE=local
export BARLUMA_UNIVERSAL=1
zsh scripts/build.sh
APP="$PWD/dist/BarLuma.app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")
[[ "$version" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || exit 1
stage=$(mktemp -d "$PWD/.build/preview-installer.XXXXXX")
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/root" "$stage/packages" "$stage/resources"
ditto "$APP" "$stage/root/BarLuma.app"
pkgbuild --analyze --root "$stage/root" "$stage/components.plist"
python3 - "$stage" "$version" <<'PY'
import plistlib, sys
from pathlib import Path
stage = Path(sys.argv[1])
version = sys.argv[2]
components = plistlib.loads((stage / 'components.plist').read_bytes())
if len(components) != 1 or components[0]['RootRelativeBundlePath'] != 'BarLuma.app':
    raise SystemExit('Unexpected installer component')
for item in components:
    item['BundleIsRelocatable'] = False
    item['BundleIsVersionChecked'] = True
    item['BundleOverwriteAction'] = 'upgrade'
(stage / 'components.plist').write_bytes(plistlib.dumps(components))
(stage / 'Distribution.xml').write_text(f'''<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
  <title>BarLuma {version} Preview</title>
  <options customize="never" require-scripts="false" rootVolumeOnly="false" hostArchitectures="arm64,x86_64"/>
  <domains enable_anywhere="false" enable_currentUserHome="true" enable_localSystem="false"/>
  <volume-check><allowed-os-versions><os-version min="13.0"/></allowed-os-versions></volume-check>
  <welcome file="Welcome.rtf" mime-type="text/rtf"/>
  <conclusion file="Conclusion.rtf" mime-type="text/rtf"/>
  <choices-outline><line choice="app"/></choices-outline>
  <choice id="app" title="BarLuma" visible="false"><pkg-ref id="com.anazih.macos-topbar.preview"/></choice>
  <pkg-ref id="com.anazih.macos-topbar.preview" version="{version}" auth="none">BarLuma-component.pkg</pkg-ref>
  <pkg-ref id="com.anazih.macos-topbar.preview"><must-close><app id="com.anazih.macos-topbar"/></must-close></pkg-ref>
</installer-gui-script>
''')
def rtf(title, paragraphs):
    def escape(text):
        return text.replace('\\', '\\\\').replace('{', '\\{').replace('}', '\\}')
    return (r'{\rtf1\ansi\deff0{\fonttbl{\f0 Helvetica;}}\f0\fs38\b ' + escape(title) +
            r'\b0\fs26\par\par ' + r'\par\par '.join(map(escape, paragraphs)) + r'\par}')
(stage / 'resources/Welcome.rtf').write_text(rtf(f'BarLuma {version}', [
    'Network speed, CPU, RAM and local weather in your menu bar.',
    'Installs for your account only in your Applications folder (~/Applications). No administrator install script, restart or license-acceptance screen.',
    'Development preview: this installer is unsigned and the app is ad-hoc signed, sandboxed and hardened. Apple has not notarized it. macOS may warn or block it. Your security settings are not changed.',
    'Free for personal, non-commercial use. Enterprise licensing: Abdullah.n.sy@gmail.com.'
]))
(stage / 'resources/Conclusion.rtf').write_text(rtf('BarLuma is installed', [
    'Open BarLuma from Spotlight or your Applications folder. It appears in the menu bar, with no Dock icon.',
    'Allow location in the macOS prompt for automatic weather, or choose a city in Settings. Uninstall is available in Settings.',
    'Find future versions in About > Check for Updates.'
]))
PY
pkgbuild --root "$stage/root" --component-plist "$stage/components.plist" \
    --identifier com.anazih.macos-topbar.preview --version "$version" \
    --install-location /Applications --ownership recommended "$stage/packages/BarLuma-component.pkg"
OUTPUT="$PWD/dist/BarLuma-$version-preview.pkg"
productbuild --distribution "$stage/Distribution.xml" --package-path "$stage/packages" \
    --resources "$stage/resources" "$OUTPUT"
python3 scripts/check-installer.py "$OUTPUT"
cd dist
shasum -a 256 "${OUTPUT:t}" > "${OUTPUT:t}.sha256"
echo "Built unsigned, user-only preview installer: $OUTPUT"
