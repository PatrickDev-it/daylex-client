import base64
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import re
import urllib.parse
import urllib.request
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

root = Path(__file__).resolve().parents[1]
public = re.search(r"releasePublicKey = '([^']+)'", (root / 'app/lib/features/update/update_channel.g.dart').read_text())[1]
key = Ed25519PublicKey.from_public_bytes(base64.b64decode(public))
def fetch(path):
    return urllib.request.urlopen(urllib.request.Request('https://daylex.it' + path,
                                 headers={'Cache-Control': 'no-cache'}), timeout=60)
with fetch('/app/web-release.json') as response:
    signed = json.load(response)
key.verify(base64.b64decode(signed['signature']), signed['payload'].encode())
expected = json.loads((root / 'release-input/delivery.json').read_text())
assert signed == expected, 'Published web inventory differs'
release = json.loads(signed['payload'])
def check(item):
    name, sha = item
    with fetch('/app/' + urllib.parse.quote(name)) as response:
        assert hashlib.file_digest(response, 'sha256').hexdigest() == sha, f'Public asset differs: {name}'
        if name.endswith(('.js', '.mjs')): assert 'javascript' in response.headers.get('Content-Type', ''), name
with ThreadPoolExecutor(max_workers=4) as pool:
    list(pool.map(check, release['assets'].items()))
with fetch('/') as response:
    assert 'href="/app/"' in response.read().decode(), 'Website lacks PWA link'
print(f'LIVE: PWA b{release["build"]}, signed inventory and {len(release["assets"])} public assets verified')
