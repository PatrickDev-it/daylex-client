"""Sign only tracked presentation assets; live downloads and inventory stay server-owned."""
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import tarfile
import zipfile
from cryptography.hazmat.primitives import serialization

root = Path(__file__).resolve().parents[1]
source = root / 'site'
files = subprocess.check_output(['git', 'ls-files', '-z', 'site'], cwd=root).decode().split('\0')
assets = {Path(name).relative_to('site').as_posix(): hashlib.sha256((root / name).read_bytes()).hexdigest()
          for name in files if name}
assert 'release.json' not in assets
build = int(os.environ['SITE_BUILD'])
directory = root / 'release-input'
directory.mkdir(exist_ok=True)
archive = directory / f'daylex-site-b{build}.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as bundle:
    for name in sorted(assets): bundle.write(source / name, arcname=name)
key = serialization.load_pem_private_key(os.environ['RELEASE_SIGNING_KEY'].encode(), password=None)
configured = re.search(r"releasePublicKey = '([^']+)'", (root / 'app/lib/features/update/update_channel.g.dart').read_text())[1]
assert base64.b64encode(key.public_key().public_bytes_raw()).decode() == configured
payload = json.dumps(dict(kind='site', build=build, commit=os.environ['GITHUB_SHA'], file=archive.name,
    size=archive.stat().st_size, sha256=hashlib.sha256(archive.read_bytes()).hexdigest(), assets=assets), separators=(',', ':'))
inventory = directory / 'delivery.json'
inventory.write_text(json.dumps(dict(payload=payload, signature=base64.b64encode(key.sign(payload.encode())).decode())))
with tarfile.open(root / 'delivery.tar', 'w') as output:
    output.add(archive, arcname=archive.name)
    output.add(inventory, arcname=inventory.name)
print(f'Signed presentation b{build}: {len(assets)} assets')
