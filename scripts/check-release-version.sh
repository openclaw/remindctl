#!/usr/bin/env bash
# Credential-free source metadata checks run by the archetype on Linux.
set -euo pipefail
[[ $# == 1 ]] || { echo "Usage: $0 vX.Y.Z" >&2; exit 2; }
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
python3 - "$1" <<'CHECK'
from pathlib import Path
import re
import sys
version = sys.argv[1].removeprefix('v')
assert re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', version), 'Expected stable release version'
import json
import plistlib
assert re.search(r'^MARKETING_VERSION=(.+)$', Path('version.env').read_text(), re.M)[1] == version
assert json.loads(Path('package.json').read_text())['version'] == version, 'package.json version mismatch'
assert f'static let current = "{version}"' in Path('Sources/remindctl/Version.swift').read_text()
plist = plistlib.loads(Path('Sources/remindctl/Resources/Info.plist').read_bytes())
assert plist['CFBundleIdentifier'] == 'com.steipete.remindctl'
assert plist['CFBundleShortVersionString'] == version
CHECK
