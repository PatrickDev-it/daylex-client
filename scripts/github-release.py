import json
import os
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
directory = root / 'release-input'
inventory = json.loads(json.loads((directory / 'delivery.json').read_text())['payload'])
packages = inventory['packages']
tag = f'v{packages[0]["version"]}-b{packages[0]["build"]}'
assets = {name for p in packages for name in (p['archive'], p['installer'], p['installer'] + '.sha256', p['platform'] + '.json')}
notes = directory / 'notes.txt'
notes.write_text('Desktop release. Published to https://daylex.it and the signed in-app update channel.\n\nPlatforms: '
                 + ', '.join(p['platform'] for p in packages)
                 + '\nWindows installer is currently unsigned (Authenticode). macOS is included only when notarized.\n')
if subprocess.run(['gh', 'release', 'view', tag], capture_output=True).returncode:
    subprocess.run(['gh', 'release', 'create', tag, '--target', os.environ['GITHUB_SHA'], '--title', f'Daylex {tag}',
                    '--notes-file', str(notes), *[str(directory / n) for n in sorted(assets)]], check=True)
