#!/usr/bin/env python3
"""Inspect the actual expanded installer; never installs it or executes payload scripts."""
from pathlib import Path
import plistlib
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

package = Path(sys.argv[1]).resolve()
def require(condition, message):
    if not condition:
        raise SystemExit(message)

with tempfile.TemporaryDirectory(prefix='barluma-package-check-') as temporary:
    expanded = Path(temporary) / 'expanded'
    subprocess.run(['pkgutil', '--expand-full', str(package), str(expanded)], check=True)
    distribution = ET.parse(expanded / 'Distribution').getroot()
    domains = distribution.find('domains')
    require(domains is not None and domains.get('enable_currentUserHome') == 'true', 'User-home installation is required')
    require(domains.get('enable_localSystem') == 'false' and domains.get('enable_anywhere') == 'false', 'System/other-volume installation is prohibited')
    require(distribution.find('license') is None, 'No license acceptance screen is permitted')
    require(distribution.find('script') is None, 'No distribution scripts are permitted')
    for name in ['Welcome.rtf', 'Conclusion.rtf']:
        resources = list(expanded.rglob(name))
        require(len(resources) == 1 and resources[0].read_bytes().startswith(b'{\\rtf1'), 'Native RTF installer text is required')
    infos = list(expanded.rglob('PackageInfo'))
    require(len(infos) == 1, 'Exactly one payload component is required')
    info = ET.parse(infos[0]).getroot()
    require(info.get('identifier') == 'com.anazih.macos-topbar.preview', 'Unexpected package identity')
    require(info.get('install-location') == '/Applications', 'Unexpected installation path')
    require(info.find('scripts') is None and not list(expanded.rglob('Scripts')), 'Install scripts are prohibited')
    require(info.get('relocatable') == 'false' and not info.findall('relocate/bundle'), 'Payload relocation is prohibited')
    payload = infos[0].parent / 'Payload'
    require(sorted(p.name for p in payload.iterdir()) == ['BarLuma.app'], 'Unexpected payload files')
    app = payload / 'BarLuma.app'
    bundle = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    require(bundle['CFBundleIdentifier'] == 'com.anazih.macos-topbar', 'Unexpected app identity')
    executable = app / 'Contents/MacOS/TopBar'
    architectures = subprocess.check_output(['lipo', '-archs', str(executable)], text=True)
    require('arm64' in architectures and 'x86_64' in architectures, 'A universal application is required')
    subprocess.run([sys.executable, 'scripts/check-security.py', str(app), 'local'], check=True)
print('PASS: user-only, script-free installer; no license gate; verified universal sandboxed app payload')
