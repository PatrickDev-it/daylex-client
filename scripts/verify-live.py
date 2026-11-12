import base64
import hashlib
import json
from pathlib import Path
import re
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey
from live_http import open_live as get

root = Path(__file__).resolve().parents[1]
public = re.search(r"releasePublicKey = '([^']+)'", (root / 'app/lib/features/update/update_channel.g.dart').read_text())[1]
key = Ed25519PublicKey.from_public_bytes(base64.b64decode(public))
for file in (root / 'release-input').glob('*-package.json'):
    package = json.loads(file.read_text())
    with get(f'https://api.daylex.it/updates/{package["platform"]}.json') as response:
        signed = json.load(response)
    key.verify(base64.b64decode(signed['signature']), signed['payload'].encode())
    release = json.loads(signed['payload'])
    assert release['build'] == package['build'], 'Old update manifest'
    with get('https://api.daylex.it/updates/' + release['file']) as response:
        assert hashlib.file_digest(response, 'sha256').hexdigest() == release['sha256'], 'Update download differs'
    with get('https://daylex.it/downloads/' + package['installer']) as response:
        assert hashlib.file_digest(response, 'sha256').hexdigest() == package['installer_sha256'], 'Website download differs'
    with get('https://daylex.it/') as response:
        assert package['installer'] in response.read().decode(), 'Website points to old installer'
    print(f'LIVE: {package["platform"]} build {package["build"]}, website and signed updater verified')
