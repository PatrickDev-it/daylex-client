#!/usr/bin/python3
"""Root-owned forced SSH command. Accepts only a signed, bounded release tar on stdin.

Installed administratively, never overwritten by CI. No arbitrary remote command or path.
All payloads are verified before any public pointer changes. Old downloads remain valid.
"""
import base64
import fcntl
import hashlib
import html
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tarfile
import tempfile
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

PUBLIC_KEY = 'zd/PmMt2KpSg0aGGUaPqr8/PKgEjrtWiw2VZRO5vnng='
UPDATES = Path('/opt/paperagent/updates')
SITE = Path('/srv/daylex-site')
STATE = Path('/srv/daylex-release')

def digest(path):
    with path.open('rb') as file:
        return hashlib.file_digest(file, 'sha256').hexdigest()

def verified(path, public=PUBLIC_KEY):
    outer = json.loads(path.read_text(encoding='utf-8'))
    Ed25519PublicKey.from_public_bytes(base64.b64decode(public)).verify(
        base64.b64decode(outer['signature']), outer['payload'].encode())
    return json.loads(outer['payload'])

def receive(stream, dest):
    total = 0
    names = set()
    with tarfile.open(fileobj=stream, mode='r|') as archive:
        for item in archive:
            if not item.isfile() or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]{0,180}', item.name):
                raise ValueError('Only plain, flat release files are accepted')
            if item.name in names or len(names) >= 30:
                raise ValueError('Duplicate or excessive files')
            names.add(item.name)
            total += item.size
            if item.size > 1024**3 or total > 3 * 1024**3:
                raise ValueError('Release exceeds upload limits')
            with (dest / item.name).open('wb') as output:
                shutil.copyfileobj(archive.extractfile(item), output)

def validate(src, updates, public=PUBLIC_KEY):
    inventory = verified(src / 'delivery.json', public)
    packages = inventory['packages']
    if not 1 <= len(packages) <= 3 or len({p['platform'] for p in packages}) != len(packages):
        raise ValueError('Invalid platform inventory')
    if len({(p['version'], p['build'], p['commit']) for p in packages}) != 1:
        raise ValueError('Mixed release versions')
    for p in packages:
        platform = p['platform']
        if platform not in ('windows', 'macos', 'linux'):
            raise ValueError('Unsupported platform')
        if not re.fullmatch(r'\d+\.\d+\.\d+', p['version']) or not isinstance(p['build'], int) or p['build'] <= 0:
            raise ValueError('Invalid version')
        expected = f'daylex-{platform}-{p["version"]}-b{p["build"]}.zip'
        if p['archive'] != expected or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]{0,180}', p['installer']):
            raise ValueError('Invalid artifact name')
        if platform == 'macos' and p.get('notarized') is not True:
            raise ValueError('Mac release requires notarization')
        release = verified(src / f'{platform}.json', public)
        if any(release[k] != p[k] for k in ('platform', 'version', 'build')) or release['file'] != expected:
            raise ValueError('Update manifest and inventory disagree')
        for name, size, sha in ((p['archive'], release['size'], release['sha256']),
                                (p['installer'], p['installer_size'], p['installer_sha256'])):
            file = src / name
            if file.stat().st_size != size or digest(file) != sha:
                raise ValueError('Artifact integrity mismatch')
        previous = updates / f'{platform}.json'
        if previous.exists():
            old = verified(previous, public)
            if old['build'] > release['build'] or (old['build'] == release['build'] and old['sha256'] != release['sha256']):
                raise ValueError('Rollback or mutation of a published build refused')
    return packages

def article(p):
    platform = p['platform']
    label, requirements, instructions = {
        'windows': ('Windows', 'Windows 10 / 11 · Intel o AMD a 64 bit',
                    'Versione di anteprima. Installer non ancora firmato digitalmente: Windows potrebbe mostrare un avviso.'),
        'macos': ('macOS', 'Mac Intel e Apple Silicon',
                  'Apri il file .dmg e trascina Daylex in Applicazioni. Pacchetto firmato e notarizzato da Apple.'),
        'linux': ('Linux', f'Ubuntu {html.escape(p.get("linux_minimum", "24.04"))} o successivo · x86-64 · portachiavi di sistema',
                  'Estrai lo ZIP in una cartella e avvia bash install.sh. Richiede GTK 3, libsecret, unzip e un portachiavi di sistema attivo.'),
    }[platform]
    name = html.escape(p['installer'], quote=True)
    size = f'{p["installer_size"] / 1_000_000:.1f}'.replace('.', ',')
    return (f'<article id="{platform}"><h2>Pronto per {label}.</h2><p>{requirements}</p>'
            f'<dl class="release-facts"><div><dt>Versione</dt><dd>{p["version"]} · build {p["build"]}</dd></div>'
            f'<div><dt>Download</dt><dd>{size} MB</dd></div></dl>'
            f'<a class="button" href="downloads/{name}" download>Scarica per {label}</a>'
            f'<p class="note">{instructions}</p>'
            f'<a class="small-link" href="downloads/{name}.sha256" download>Scarica il codice di verifica SHA-256</a></article>')

def render_site(dest, packages):
    index = dest / 'index.html'
    text = index.read_text(encoding='utf-8')
    info = json.loads((dest / 'release.json').read_text())
    for p in packages:
        platform = p['platform']
        pattern = rf'<article id="{platform}">.*?</article>'
        if re.search(pattern, text, re.S):
            text = re.sub(pattern, lambda _: article(p), text, count=1, flags=re.S)
        elif platform == 'linux':
            text = text.replace('</article>', '</article>' + article(p), 1)
        else:
            raise ValueError('Website platform section missing')
        info[platform] = dict(url='downloads/' + p['installer'], bytes=p['installer_size'],
                              sha256=p['installer_sha256'], version=p['version'], build=p['build'],
                              authenticode=p.get('authenticode', False), notarized=p.get('notarized', False))
    info.update(version=packages[0]['version'], build=packages[0]['build'])
    if any(p['platform'] == 'linux' for p in packages):
        if 'data-platform="linux"' not in text:
            text = text.replace('data-platform="macos">macOS</a>', 'data-platform="macos">macOS</a><a href="#linux" data-platform="linux">Linux</a>', 1)
        text = text.replace('Posso installarlo su Windows ARM o Linux?', 'Quali sistemi sono supportati?')
        text = text.replace('Il pacchetto attuale è destinato a Windows con processore Intel o AMD a 64 bit. Windows ARM e Linux non sono ancora verificati per questa distribuzione.',
                            'Windows supporta Intel e AMD a 64 bit. Per Linux, la versione minima di Ubuntu è indicata nella scheda di download. La disponibilità per Mac è indicata nella scheda macOS.')
        text = text.replace('Scarica Daylex — App per Windows e macOS', 'Scarica Daylex — App desktop')
    text = text.replace('Apri il file e segui la procedura. Se manca Microsoft Visual C++, il setup ne propone l’installazione con autorizzazione amministrativa.',
                        'Apri il file e segui la procedura. I componenti Microsoft Visual C++ necessari sono inclusi nel pacchetto.')
    if any(p['platform'] == 'macos' for p in packages):
        text = text.replace('La guida macOS sarà pubblicata insieme al relativo installer.',
                            'Su macOS, apri il DMG e trascina Daylex in Applicazioni, poi inserisci la chiave API.')
        text = text.replace('La versione macOS sarà disponibile prossimamente.', 'Disponibile anche per macOS.')
    index.write_text(text, encoding='utf-8')
    (dest / 'release.json').write_text(json.dumps(info, indent=2) + '\n')
    script = dest / 'app.js'
    js = script.read_text()
    old = "select(location.hash === '#macos' || /Mac|iPhone|iPad/.test(navigator.platform) ? 'macos' : 'windows');"
    js = js.replace(old, "const requested = location.hash.slice(1);\nselect(choices.some(c => c.dataset.platform === requested) ? requested : /Mac|iPhone|iPad/.test(navigator.platform) ? 'macos' : /Linux/.test(navigator.platform) && document.getElementById('linux') ? 'linux' : 'windows');")
    script.write_text(js)

def atomic_copy(source, destination):
    if destination.exists():
        if digest(source) != digest(destination):
            raise ValueError('Immutable download already exists with different content')
        return
    temporary = destination.with_name('.' + destination.name + '.tmp')
    shutil.copyfile(source, temporary)
    temporary.chmod(0o644)
    temporary.replace(destination)

def publish(src, packages, updates=UPDATES, site=SITE):
    current = (site / 'current').resolve(strict=True)
    release_id = f'ci-b{packages[0]["build"]}-{packages[0]["commit"][:12]}'
    candidate = site / 'releases' / release_id
    if not candidate.exists():
        # A fresh site release, with previous versioned downloads retained by hard link.
        shutil.copytree(current, candidate, copy_function=os.link)
        # Break hard links before modifying the three website files.
        for name in ('index.html', 'release.json', 'app.js'):
            data = (candidate / name).read_bytes()
            (candidate / name).unlink()
            (candidate / name).write_bytes(data)
    render_site(candidate, packages)
    for p in packages:
        atomic_copy(src / p['archive'], updates / p['archive'])
        atomic_copy(src / p['installer'], candidate / 'downloads' / p['installer'])
        checksum = candidate / 'downloads' / (p['installer'] + '.sha256')
        checksum.write_text(f'{p["installer_sha256"]}  {p["installer"]}\n')
        checksum.chmod(0o644)
    for path in candidate.rglob('*'):
        if path.is_file(): path.chmod(0o644)
        elif path.is_dir(): path.chmod(0o755)
    candidate.chmod(0o755)
    # Each manifest switches only after its immutable archive is available.
    for p in packages:
        staged = updates / f'.{p["platform"]}.json.tmp'
        shutil.copyfile(src / f'{p["platform"]}.json', staged)
        staged.chmod(0o644)
        staged.replace(updates / f'{p["platform"]}.json')
    link = site / '.current-ci'
    link.unlink(missing_ok=True)
    link.symlink_to(candidate, target_is_directory=True)
    link.replace(site / 'current')
    print('PUBLISHED ' + ', '.join(f'{p["platform"]} b{p["build"]}' for p in packages), flush=True)

def main():
    STATE.mkdir(exist_ok=True)
    with (STATE / 'publish.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        with tempfile.TemporaryDirectory(prefix='incoming-', dir=STATE) as directory:
            src = Path(directory)
            receive(sys.stdin.buffer, src)
            packages = validate(src, UPDATES)
            publish(src, packages)

if __name__ == '__main__':
    main()
