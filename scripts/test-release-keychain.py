#!/usr/bin/env python3
"""Exercise the actual workflow's keychain setup/cleanup with synthetic commands."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import textwrap
import unittest

WORKFLOW = (Path(__file__).resolve().parent.parent / '.github/workflows/release.yml').read_text()

def step(name):
    block = WORKFLOW.split('      - name: ' + name + '\n', 1)[1].split('\n      - ', 1)[0]
    return textwrap.dedent(block.split('        run: |\n', 1)[1])

STUB = r'''
import json, os, sys
from pathlib import Path
args = sys.argv[1:]
root = Path(os.environ['RUNNER_TEMP'])
if Path(sys.argv[0]).name == 'openssl':
    if args[0] == 'rand': print('synthetic-password')
    elif '-help' in args: print('-legacy')
    else: Path(args[args.index('-out') + 1]).write_text('synthetic material')
    sys.exit(0)
p = root / 'state.json'
s = json.loads(p.read_text())
command = args[0]
if command == 'list-keychains':
    if '-s' in args: s['search'] = args[args.index('-s') + 1:]
    else:
        for value in s['search']: print(json.dumps(value))
elif command == 'create-keychain':
    Path(args[-1]).touch()
    s['search'].append(args[-1])
elif command == 'delete-keychain':
    Path(args[-1]).unlink()
    s['search'] = [value for value in s['search'] if value != args[-1]]
elif command == 'import':
    if os.environ['SCENARIO'] == 'import-failure': sys.exit(1)
    s['imports'].append(Path(args[1]).name)
elif command == 'find-identity':
    assert args[-1] in s['search'], 'signing keychain must be searchable'
    assert s['imports'] == ['signing-certificate.pem', 'signing-private-key.pem']
    if os.environ['SCENARIO'] != 'missing-identity':
        print('  1) ' + 'A' * 40 + ' "Developer ID Application: OpenClaw Foundation (FWJYW4S8P8)"')
elif command not in ['set-keychain-settings', 'unlock-keychain', 'set-key-partition-list']:
    raise AssertionError(command)
p.write_text(json.dumps(s))
'''

class KeychainTests(unittest.TestCase):
    def scenario(self, scenario):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            original = ['login keychain-db', 'another keychain-db']
            (root / 'state.json').write_text(json.dumps(dict(search=original, imports=[])))
            binary = root / 'bin'
            binary.mkdir()
            for name in ['security', 'openssl']:
                script = binary / name
                script.write_text('#!' + sys.executable + '\n' + STUB)
                script.chmod(0o755)
            env = dict(PATH=str(binary) + ':' + os.environ['PATH'], RUNNER_TEMP=directory,
                       GITHUB_OUTPUT=str(root / 'output'), P12='Zml4dHVyZQ==',
                       P12_PASSWORD='synthetic', ASC_KEY='synthetic', SCENARIO=scenario)
            setup = subprocess.run(['/bin/bash', '-c', step('Import isolated signing credentials')],
                                   env=env, cwd=directory, capture_output=True, text=True)
            self.assertEqual(setup.returncode == 0, scenario == 'success', setup.stderr)
            if scenario == 'success':
                self.assertEqual((root / 'output').read_text(), 'identity=' + 'A' * 40 + '\n')
                self.assertIn(str(root / 'release.keychain-db'), json.loads((root / 'state.json').read_text())['search'])
            cleanup = subprocess.run(['/bin/bash', '-c', step('Remove signing material and restore keychain search list')],
                                     env=env, cwd=directory, capture_output=True, text=True)
            self.assertEqual(cleanup.returncode, 0, cleanup.stderr)
            self.assertEqual(json.loads((root / 'state.json').read_text())['search'], original)
            for name in ['release.keychain-db', 'signing.p12', 'signing-certificate.pem', 'signing-private-key.pem', 'AuthKey.p8']:
                self.assertFalse((root / name).exists(), name)

    def test_success(self): self.scenario('success')
    def test_import_failure(self): self.scenario('import-failure')
    def test_missing_identity(self): self.scenario('missing-identity')

if __name__ == '__main__': unittest.main()
