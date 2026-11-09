"""Verify signed source receipt, public assets and live download links after CI publication."""
import base64
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import urllib.request
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

root = Path(__file__).resolve().parents[1]
def fetch(path):
    with urllib.request.urlopen('https://daylex.it/' + path, timeout=60) as response: return response.read()
receipt = json.loads(fetch('site-release.json'))
key = re.search(r"releasePublicKey = '([^']+)'", (root / 'app/lib/features/update/update_channel.g.dart').read_text())[1]
Ed25519PublicKey.from_public_bytes(base64.b64decode(key)).verify(base64.b64decode(receipt['signature']), receipt['payload'].encode())
assert receipt == json.loads((root / 'release-input/delivery.json').read_text()), 'Site receipt differs'
release = json.loads(receipt['payload'])
for name, digest in release['assets'].items():
    if name not in ('index.html', 'tecnica.html'):  # These two receive live desktop release metadata.
        assert hashlib.sha256(fetch(name)).hexdigest() == digest, name
info = json.loads(fetch('release.json'))
class Links(HTMLParser):
    def __init__(self): super().__init__(); self.downloads = []
    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        if tag == 'a' and 'data-download' in values: self.downloads.append((values['data-download'], values['href']))
home = Links(); home.feed(fetch('index.html').decode())
assert sorted(platform for platform, _ in home.downloads) == ['linux', 'macos', 'windows', 'windows']
technical = fetch('tecnica.html').decode()
for platform, url in home.downloads:
    assert url == info[platform]['url'] and url in technical
    with urllib.request.urlopen(urllib.request.Request('https://daylex.it/' + url, method='HEAD'), timeout=60) as response:
        assert int(response.headers['Content-Length']) == info[platform]['bytes']
assert b'Installa' in fetch('app/installa.html')
print(f'LIVE: website b{release["build"]}, source assets and live installers verified')
