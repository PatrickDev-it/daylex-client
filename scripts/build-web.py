"""Build a self-hosted PWA: no CDN dependencies, credentials or API responses in its cache."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parents[1]
app = root / 'app'
out = app / 'build/web'
subprocess.run(['flutter.bat' if os.name == 'nt' else 'flutter', 'build', 'web', '--release',
                '--base-href', '/app/', '--no-web-resources-cdn', '--no-pub'], cwd=app, check=True)
vendor = out / 'vendor/pdfjs'
vendor.mkdir(parents=True, exist_ok=True)
pdfjs = root / 'web-tools/node_modules/pdfjs-dist'
for name in ('pdf.min.mjs', 'pdf.worker.min.mjs'):
    shutil.copy2(pdfjs / 'build' / name, vendor / name)
shutil.copy2(pdfjs / 'LICENSE', vendor / 'LICENSE')
assets = sorted(file.relative_to(out).as_posix() for file in out.rglob('*')
                if file.is_file() and file.name not in ('service-worker.js', 'flutter_service_worker.js'))
version = hashlib.sha256(b''.join(hashlib.sha256((out / name).read_bytes()).digest() for name in assets)).hexdigest()[:20]
worker = (root / 'scripts/web-service-worker.js').read_text()
cached = {name: hashlib.sha256((out / name).read_bytes()).hexdigest() for name in assets
          if not name.endswith('.map') and 'skwasm' not in name}
(out / 'service-worker.js').write_text(worker.replace('__VERSION__', version).replace('__ASSETS__', json.dumps(cached)))
print(f'PWA built: {len(assets)} local assets, cache {version}')
