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
import zipfile
import stat
from pathlib import PurePosixPath
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

PUBLIC_KEY = 'zd/PmMt2KpSg0aGGUaPqr8/PKgEjrtWiw2VZRO5vnng='
UPDATES = Path('/opt/paperagent/updates')
SITE = Path('/srv/daylex-site')
STATE = Path('/srv/daylex-release')
WEB = Path('/srv/daylex-pwa')

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
        if not re.fullmatch(r'[0-9a-f]{40}', p['commit']):
            raise ValueError('Invalid source commit')
        if not re.fullmatch(r'\d+\.\d+\.\d+', p['version']) or not isinstance(p['build'], int) or p['build'] <= 0:
            raise ValueError('Invalid version')
        expected = f'daylex-{platform}-{p["version"]}-b{p["build"]}.zip'
        if p['archive'] != expected or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]{0,180}', p['installer']):
            raise ValueError('Invalid artifact name')
        if platform == 'macos' and (p.get('signing'), p.get('notarized')) not in (('adhoc', False), ('developer-id', True)):
            raise ValueError('Invalid Mac signing metadata')
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
                  'Apri il DMG e trascina Daylex in Applicazioni. ' +
                  ('App firmata con Developer ID e notarizzata da Apple.' if p.get('notarized') else
                   'App non notarizzata, con firma ad-hoc. Dopo il primo tentativo di apertura, se macOS la blocca, '
                   'vai in Impostazioni di Sistema → Privacy e sicurezza → Apri comunque e conferma solo se ti fidi della provenienza. '
                   'macOS potrebbe richiedere una nuova conferma dopo un aggiornamento. '
                   '<a href="https://support.apple.com/it-it/102445">Istruzioni Apple</a>.')),
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

def marketing_article(p):
    platform = p['platform']
    label, requirements, note = {
        'windows': ('Windows', 'Windows 10 e 11', 'Il computer potrebbe chiederti una conferma durante l’installazione.'),
        'macos': ('Mac', 'Per Mac Intel e Apple Silicon',
                  'Apri il file e trascina Daylex in Applicazioni.' if p.get('notarized') else 'Il Mac potrebbe chiederti di confermare l’apertura.'),
        'linux': ('Linux', f'Ubuntu {html.escape(p.get("linux_minimum", "26.04"))} e successivi', 'Trovi tutti i passaggi nella guida.'),
    }[platform]
    name = html.escape(p['installer'], quote=True)
    return (f'<article id="{platform}"><h3>Daylex per {label}</h3><p>{requirements}</p>'
            f'<a class="button" href="downloads/{name}" download>Scarica per {label}</a>'
            f'<p class="download-note">Versione di anteprima. {note}</p>'
            f'<a class="text-link" href="assistenza.html#{platform}">Guida all’installazione</a></article>')

def render_site(dest, packages):
    index = dest / 'index.html'
    text = index.read_text(encoding='utf-8')
    gateway = 'data-site-version="3"' in text
    marketing = gateway or 'data-site-version="2"' in text
    technical = dest / 'tecnica.html'
    technical_text = technical.read_text(encoding='utf-8') if marketing else None
    info = json.loads((dest / 'release.json').read_text())
    for p in packages:
        platform = p['platform']
        pattern = rf'<article id="{platform}">.*?</article>'
        if gateway:
            link_pattern = rf'(<a\b[^>]*data-download="{platform}"[^>]*\bhref=")[^"]*(")'
            text, count = re.subn(link_pattern, lambda match: match[1] + 'downloads/' + html.escape(p['installer'], quote=True) + match[2], text)
            if not count:
                raise ValueError('Website download link missing')
        elif re.search(pattern, text, re.S):
            text = re.sub(pattern, lambda _: marketing_article(p) if marketing else article(p), text, count=1, flags=re.S)
        elif platform == 'linux':
            text = text.replace('</article>', '</article>' + article(p), 1)
        else:
            raise ValueError('Website platform section missing')
        info[platform] = dict(url='downloads/' + p['installer'], bytes=p['installer_size'],
                              sha256=p['installer_sha256'], version=p['version'], build=p['build'],
                              authenticode=p.get('authenticode', False), notarized=p.get('notarized', False),
                              signing=p.get('signing'), linux_minimum=p.get('linux_minimum'))
        if marketing:
            technical_pattern = rf'<!-- release:{platform} -->.*?<!-- /release:{platform} -->'
            if not re.search(technical_pattern, technical_text, re.S):
                raise ValueError('Technical release section missing')
            technical_text = re.sub(technical_pattern, lambda _: f'<!-- release:{platform} -->{article(p)}<!-- /release:{platform} -->', technical_text, count=1, flags=re.S)
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
    if marketing:
        technical.write_text(technical_text, encoding='utf-8')
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
    suffix = hashlib.sha256(current.name.encode()).hexdigest()[:12]
    release_id = f'ci-b{packages[0]["build"]}-{packages[0]["commit"][:12]}-{suffix}'
    candidate = site / 'releases' / release_id
    if not candidate.exists():
        # A fresh site release, with previous versioned downloads retained by hard link.
        shutil.copytree(current, candidate, copy_function=os.link)
        # Break hard links before modifying generated website files.
        for name in ('index.html', 'release.json', 'app.js', 'tecnica.html'):
            if not (candidate / name).exists(): continue
            data = (candidate / name).read_bytes()
            (candidate / name).unlink()
            (candidate / name).write_bytes(data)
    render_site(candidate, packages)
    for p in packages:
        atomic_copy(src / p['archive'], updates / p['archive'])
        atomic_copy(src / p['installer'], candidate / 'downloads' / p['installer'])
        checksum = candidate / 'downloads' / (p['installer'] + '.sha256')
        expected_checksum = f'{p["installer_sha256"]}  {p["installer"]}\n'
        if checksum.exists():
            if checksum.read_text() != expected_checksum:
                raise ValueError('Immutable checksum changed')
        else:
            checksum.write_text(expected_checksum)
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

def validate_web(src, web=WEB, public=PUBLIC_KEY, kind='web'):
    release = verified(src / 'delivery.json', public)
    if kind not in ('web', 'site') or release.get('kind') != kind or type(release.get('build')) is not int or release['build'] <= 0:
        raise ValueError('Invalid web release')
    if not re.fullmatch(r'[0-9a-f]{40}', release.get('commit', '')):
        raise ValueError('Invalid web source commit')
    expected = f'daylex-{kind}-b{release["build"]}.zip'
    if release.get('file') != expected:
        raise ValueError('Invalid web archive name')
    archive = src / expected
    if archive.stat().st_size != release['size'] or digest(archive) != release['sha256']:
        raise ValueError('Web archive integrity mismatch')
    assets = release['assets']
    required = {'index.html', 'main.dart.js', 'runtime.mjs', 'storage.mjs', 'manifest.json', 'service-worker.js', 'flutter_bootstrap.js'}
    if kind == 'site':
        required = {'index.html', 'style.css', 'app.js', 'assistenza.html', 'tecnica.html', 'favicon.svg'}
    if not isinstance(assets, dict) or not required <= set(assets) or len(assets) > 5000:
        raise ValueError('Incomplete web assets')
    with zipfile.ZipFile(archive) as bundle:
        entries = bundle.infolist()
        if len(entries) != len(assets) or sum(entry.file_size for entry in entries) > 700 * 1024**2:
            raise ValueError('Invalid web archive size')
        names = set()
        for entry in entries:
            name = entry.filename
            if (name in names or name not in assets or entry.is_dir() or
                not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_./@ -]{0,240}', name) or
                '..' in PurePosixPath(name).parts or stat.S_ISLNK(entry.external_attr >> 16) or
                PurePosixPath(name).as_posix() != name or name == 'web-release.json' or
                entry.file_size > 150 * 1024**2):
                raise ValueError('Unsafe web asset')
            names.add(name)
            if kind == 'site' and (name in ('release.json', 'site-release.json') or
                                  ('/' in name and name.split('/')[0] not in ('fonts', 'media')) or
                                  PurePosixPath(name).suffix not in ('.html', '.css', '.js', '.svg', '.png', '.jpg', '.jpeg', '.webp', '.ttf', '.woff2', '.txt', '.md')):
                raise ValueError('Site payload cannot overwrite downloads, inventory or server code')
            with bundle.open(entry) as data:
                if hashlib.file_digest(data, 'sha256').hexdigest() != assets[name]:
                    raise ValueError('Web asset integrity mismatch')
    current = web / f'current/{kind}-release.json'
    if current.exists():
        previous = verified(current, public)
        if previous['build'] > release['build'] or (previous['build'] == release['build'] and previous['sha256'] != release['sha256']):
            raise ValueError('Web rollback or mutation refused')
    return release

def publish_site(src, release, site=SITE):
    previous = (site / 'current').resolve(strict=True)
    versions = site / 'releases'
    suffix = hashlib.sha256(previous.name.encode()).hexdigest()[:12]
    candidate = versions / f'site-b{release["build"]}-{release["commit"][:12]}-{suffix}'
    if not candidate.exists():
        with tempfile.TemporaryDirectory(prefix='.staging-site-', dir=versions) as directory:
            staged = Path(directory) / 'site'
            shutil.copytree(previous, staged, copy_function=os.link)
            with zipfile.ZipFile(src / release['file']) as bundle:
                for entry in bundle.infolist():
                    target = staged / entry.filename
                    target.parent.mkdir(parents=True, exist_ok=True)
                    target.unlink(missing_ok=True)  # Never modify the previous release's inode.
                    with target.open('wb') as output, bundle.open(entry) as data:
                        shutil.copyfileobj(data, output)
            inventory = staged / 'release.json'
            info = json.loads(inventory.read_text())
            inventory.unlink()
            inventory.write_text(json.dumps(info))
            packages = []
            for platform in ('windows', 'macos', 'linux'):
                item = info[platform]
                packages.append(dict(platform=platform, installer=Path(item['url']).name,
                    installer_size=item['bytes'], installer_sha256=item['sha256'], version=item['version'],
                    build=item['build'], authenticode=item.get('authenticode', False),
                    notarized=item.get('notarized', False), signing=item.get('signing'),
                    linux_minimum=item.get('linux_minimum') or '26.04'))
            render_site(staged, packages)  # Refresh links using LIVE versions, never stale source links.
            receipt = staged / 'site-release.json'
            receipt.unlink(missing_ok=True)
            shutil.copyfile(src / 'delivery.json', receipt)
            for file in staged.rglob('*'):
                file.chmod(0o755 if file.is_dir() else 0o644)
            staged.chmod(0o755)
            staged.rename(candidate)
    link = site / '.current-ci'
    link.unlink(missing_ok=True)
    link.symlink_to(candidate, target_is_directory=True)
    link.replace(site / 'current')
    print(f'PUBLISHED site b{release["build"]}', flush=True)

def publish_web(src, release, web=WEB, site=SITE):
    versions = web / 'releases'
    versions.mkdir(parents=True, exist_ok=True)
    name = f'b{release["build"]}-{release["commit"][:12]}'
    candidate = versions / name
    if not candidate.exists():
        with tempfile.TemporaryDirectory(prefix='.staging-', dir=versions) as staging:
            staged = Path(staging)
            with zipfile.ZipFile(src / release['file']) as bundle:
                bundle.extractall(staged)  # Every entry was bounded, hashed and path-checked above.
            shutil.copyfile(src / 'delivery.json', staged / 'web-release.json')
            for file in staged.rglob('*'):
                file.chmod(0o755 if file.is_dir() else 0o644)
            staged.chmod(0o755)
            staged.rename(candidate)
    link = web / '.current-ci'
    link.unlink(missing_ok=True)
    link.symlink_to(candidate, target_is_directory=True)
    link.replace(web / 'current')
    previous = (site / 'current').resolve(strict=True)
    suffix = hashlib.sha256(previous.name.encode()).hexdigest()[:12]
    site_candidate = site / 'releases' / f'web-{name}-{suffix}'
    if not site_candidate.exists():
        shutil.copytree(previous, site_candidate, copy_function=os.link)
        for file in ('index.html', 'release.json'):
            data = (site_candidate / file).read_bytes()
            (site_candidate / file).unlink()
            (site_candidate / file).write_bytes(data)
        page = site_candidate / 'index.html'
        text = page.read_text(encoding='utf-8')
        if 'href="/app/"' not in text:
            text = text.replace('<nav aria-label="Navigazione principale">',
                                '<nav aria-label="Navigazione principale"><a href="/app/">Apri nel browser</a>', 1)
        page.write_text(text, encoding='utf-8')
        info_file = site_candidate / 'release.json'
        info = json.loads(info_file.read_text())
        info['web'] = dict(url='/app/', build=release['build'], commit=release['commit'])
        info_file.write_text(json.dumps(info, indent=2) + '\n')
        for file in site_candidate.rglob('*'):
            if file.is_file(): file.chmod(0o644)
            elif file.is_dir(): file.chmod(0o755)
        site_candidate.chmod(0o755)
    link = site / '.current-ci'
    link.unlink(missing_ok=True)
    link.symlink_to(site_candidate, target_is_directory=True)
    link.replace(site / 'current')
    print(f'PUBLISHED web b{release["build"]}', flush=True)

def main():
    STATE.mkdir(exist_ok=True)
    with (STATE / 'publish.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        with tempfile.TemporaryDirectory(prefix='incoming-', dir=STATE) as directory:
            src = Path(directory)
            receive(sys.stdin.buffer, src)
            kind = verified(src / 'delivery.json').get('kind')
            if kind == 'site':
                publish_site(src, validate_web(src, web=SITE, kind='site'))
            elif kind == 'web':
                publish_web(src, validate_web(src))
            else:
                packages = validate(src, UPDATES)
                publish(src, packages)

if __name__ == '__main__':
    main()
