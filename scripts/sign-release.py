"""Sign with the existing Ed25519 trust root; never rotate it implicitly."""
import base64
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import tarfile
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

root = Path(__file__).resolve().parents[1]
directory = root / 'release-input'
key = serialization.load_pem_private_key(os.environ['RELEASE_SIGNING_KEY'].encode(), password=None)
assert isinstance(key, Ed25519PrivateKey), 'Expected Ed25519 key'
configured = re.search(r"releasePublicKey = '([^']+)'", (root / 'app/lib/features/update/update_channel.g.dart').read_text())[1]
assert base64.b64encode(key.public_key().public_bytes_raw()).decode() == configured, 'Signing key does not match installed clients'

def sign(payload):
    text = json.dumps(payload, ensure_ascii=False, separators=(',', ':'))
    return dict(payload=text, signature=base64.b64encode(key.sign(text.encode())).decode())

def digest(path):
    with path.open('rb') as source:
        return hashlib.file_digest(source, 'sha256').hexdigest()

packages = [json.loads(file.read_text()) for file in sorted(directory.glob('*-package.json'))]
assert {p['platform'] for p in packages} >= {'windows', 'linux'}, 'Required packages missing'
assert len({(p['version'], p['build'], p['commit']) for p in packages}) == 1, 'Mixed release builds'
files = set()
published = datetime.now(timezone.utc).isoformat()
for package in packages:
    platform = package['platform']
    assert platform in ('windows', 'linux', 'macos')
    assert platform != 'macos' or package['notarized'], 'Mac must be notarized'
    assert package['commit'] == os.environ['GITHUB_SHA'], 'Artifacts from another commit'
    archive = directory / package['archive']
    installer = directory / package['installer']
    assert archive.name == package['archive'] and installer.name == package['installer']
    assert digest(installer) == package['installer_sha256']
    payload = dict(platform=platform, version=package['version'], build=package['build'],
                   file=archive.name, size=archive.stat().st_size, sha256=digest(archive),
                   notes='Aggiornamento automatico Daylex', published=published)
    manifest = directory / f'{platform}.json'
    manifest.write_text(json.dumps(sign(payload), ensure_ascii=False) + '\n', encoding='utf-8')
    files.update((archive.name, installer.name, manifest.name, installer.name + '.sha256', archive.name + '.sha256'))
inventory = directory / 'delivery.json'
inventory.write_text(json.dumps(sign(dict(packages=packages, published=published))), encoding='utf-8')
files.add(inventory.name)
with tarfile.open(root / 'delivery.tar', 'w') as output:
    for name in sorted(files):
        output.add(directory / name, arcname=name, recursive=False)
print(f'Signed {len(packages)} platform releases; build {packages[0]["build"]}')
