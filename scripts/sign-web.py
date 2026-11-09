"""Sign a complete static web build for the same restricted deployment receiver."""
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import tarfile
import zipfile
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

root = Path(__file__).resolve().parents[1]
directory = root / 'release-input'
directory.mkdir(exist_ok=True)
key = serialization.load_pem_private_key(os.environ['RELEASE_SIGNING_KEY'].encode(), password=None)
assert isinstance(key, Ed25519PrivateKey)
configured = re.search(r"releasePublicKey = '([^']+)'", (root / 'app/lib/features/update/update_channel.g.dart').read_text())[1]
assert base64.b64encode(key.public_key().public_bytes_raw()).decode() == configured
build = int(os.environ['WEB_BUILD'])
source = root / 'app/build/web'
assets = {file.relative_to(source).as_posix(): hashlib.sha256(file.read_bytes()).hexdigest()
          for file in sorted(source.rglob('*')) if file.is_file()}
cached = json.loads(re.search(r'^const ASSETS = (.*);$', (source / 'service-worker.js').read_text(), re.M)[1])
assert cached and all(assets.get(name) == sha for name, sha in cached.items()), 'Service worker references missing or changed assets'
archive = directory / f'daylex-web-b{build}.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as bundle:
    for name in assets: bundle.write(source / name, arcname=name)
payload = json.dumps(dict(kind='web', build=build, commit=os.environ['GITHUB_SHA'], file=archive.name,
                          size=archive.stat().st_size, sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),
                          assets=assets), separators=(',', ':'))
inventory = directory / 'delivery.json'
inventory.write_text(json.dumps(dict(payload=payload, signature=base64.b64encode(key.sign(payload.encode())).decode())))
with tarfile.open(root / 'delivery.tar', 'w') as output:
    output.add(archive, arcname=archive.name)
    output.add(inventory, arcname=inventory.name)
print(f'Signed web b{build}: {len(assets)} assets')
