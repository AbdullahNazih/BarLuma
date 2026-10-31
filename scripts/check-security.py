#!/usr/bin/env python3
"""Fail closed if the built application loses required security protections."""
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys

app = Path(sys.argv[1]).resolve()
mode = sys.argv[2] if len(sys.argv) > 2 else "local"
def require(condition, message):
    if not condition:
        raise SystemExit(message)

require(mode in {"local", "distribution"}, "Unknown verification mode")
subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
details = subprocess.run(["codesign", "-dvvv", str(app)], check=True, capture_output=True, text=True).stderr
require("runtime" in details, "Hardened Runtime is required")
entitlements_result = subprocess.run(["codesign", "-d", "--xml", "--entitlements", "-", str(app)], check=True, capture_output=True)
entitlements = plistlib.loads(entitlements_result.stdout)
required = {"com.apple.security.app-sandbox", "com.apple.security.network.client",
            "com.apple.security.personal-information.location", "com.apple.security.files.user-selected.read-write"}
require(all(entitlements.get(key) is True for key in required), "Required sandbox permissions are missing")
identity_metadata = {"com.apple.application-identifier", "com.apple.developer.team-identifier"}
require(set(entitlements) <= required | identity_metadata, "Unexpected entitlement")
info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
require("NSAppTransportSecurity" not in info, "Do not weaken App Transport Security")
require(info["CFBundleIdentifier"] == "com.anazih.macos-topbar", "Unexpected bundle identifier")
require(info["CFBundleDisplayName"] == "BarLuma", "Unexpected product name")
require(info["BarLumaRepositoryURL"] == "https://github.com/AbdullahNazih/BarLuma", "Unexpected release destination")
require((app / "Contents/Resources/License.txt").is_file(), "Missing license")
require((app / "Contents/Resources/Privacy.md").is_file(), "Missing privacy notice")
if mode == "distribution":
    require("Signature=adhoc" not in details, "Public releases must not be ad-hoc signed")
    require(f"TeamIdentifier={os.environ['APPLE_TEAM_ID']}" in details, "Unexpected signing team")
    require("Authority=Developer ID Application:" in details, "Developer ID Application certificate required")
    require(re.search(r"^Timestamp=", details, re.M), "A secure signing timestamp is required")
    architectures = subprocess.check_output(["lipo", "-archs", str(app / "Contents/MacOS/TopBar")], text=True)
    require("arm64" in architectures and "x86_64" in architectures, "A universal distribution build is required")
print(f"PASS: {mode} signature, Hardened Runtime, sandbox, permissions and notices")
