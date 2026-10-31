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
  <welcome file="Welcome.html" mime-type="text/html"/>
  <conclusion file="Conclusion.html" mime-type="text/html"/>
  <choices-outline><line choice="app"/></choices-outline>
  <choice id="app" title="BarLuma" visible="false"><pkg-ref id="com.anazih.macos-topbar.preview"/></choice>
  <pkg-ref id="com.anazih.macos-topbar.preview" version="{version}" auth="none">BarLuma-component.pkg</pkg-ref>
  <pkg-ref id="com.anazih.macos-topbar.preview"><must-close><app id="com.anazih.macos-topbar"/></must-close></pkg-ref>
</installer-gui-script>
''')
style = '<meta charset="utf-8"><style>body{font:14px -apple-system,sans-serif;padding:12px;line-height:1.5}h1{font-size:24px}p{margin:12px 0}</style>'
(stage / 'resources/Welcome.html').write_text(style + f'''<h1>BarLuma {version}</h1>
<p>Network speed, CPU, RAM and local weather in your menu bar.</p>
<p>This installer places BarLuma in <b>your Applications folder</b> (<code>~/Applications</code>). It installs for your account only, without an administrator script, restart or license-acceptance screen.</p>
<p><b>Development preview:</b> this package is unsigned and its application is ad-hoc signed, sandboxed and hardened. It has not been notarized by Apple. macOS may block or warn about it. This installer does not change macOS security settings.</p>
<p>Free for personal, non-commercial use. Enterprise licensing: Abdullah.n.sy@gmail.com.</p>''')
(stage / 'resources/Conclusion.html').write_text(style + '''<h1>BarLuma is installed</h1>
<p>Open <b>BarLuma</b> from Spotlight or your Applications folder. It appears in the menu bar, with no Dock icon.</p>
<p>Allow location in the macOS prompt for automatic weather, or choose a city in Settings. You can uninstall from Settings.</p>
<p>Find future versions in About → Check for Updates…</p>''')
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
