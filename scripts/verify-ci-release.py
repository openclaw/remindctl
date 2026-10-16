#!/usr/bin/env python3
"""Verify retained CI assets before executing the signed CLI without credentials."""
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import zipfile

assets, proof_path = map(Path, sys.argv[1:])
proof = json.loads(proof_path.read_text())
assert proof['sourceCommit'] == os.environ['EXPECTED_SHA']
assert proof['tag'] == os.environ['EXPECTED_TAG']
assert proof['dryRun'] == (os.environ['EXPECTED_DRY'] == 'true')
assert proof['repository'] == 'openclaw/remindctl'
assert proof['defaultBranch'] == 'main'
assert proof['tag'] == 'v' + proof['version']
assert (proof['tagObject'] is None) == proof['dryRun']
archive = assets / 'remindctl-macos.zip'
assert sorted(p.name for p in assets.iterdir()) == sorted([
    archive.name, 'checksums.txt', 'release-inventory.json'])
assert all(p.is_file() and not p.is_symlink() for p in assets.iterdir())
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
assert (assets / 'checksums.txt').read_text() == f'{digest}  {archive.name}\n'
expected = dict(schemaVersion=2, **proof, identifier='com.steipete.remindctl',
    teamIdentifier='FWJYW4S8P8', architectures=['arm64', 'x86_64'],
    assets=[dict(name=archive.name, sha256=digest, size=archive.stat().st_size)])
assert json.loads((assets / 'release-inventory.json').read_text()) == expected
with tempfile.TemporaryDirectory() as directory:
    with zipfile.ZipFile(archive) as zipped:
        assert zipped.namelist() == ['remindctl']
        info = zipped.infolist()[0]
        assert stat.S_ISREG(info.external_attr >> 16), 'Archive member must be a regular file'
        zipped.extractall(directory)
    binary = Path(directory) / 'remindctl'
    binary.chmod(0o755)
    subprocess.run(['scripts/verify-macos-binary.sh', str(binary), proof['version']], check=True)
    subprocess.run([str(binary), '--help'], check=True)
    subprocess.run([str(binary), 'completion', 'bash'], check=True, stdout=subprocess.DEVNULL)
print('Verified retained inventory, signature, notarization, version and native CLI smoke')
