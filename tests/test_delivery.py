import base64
import importlib.util
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest
import zipfile
import hashlib
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

spec = importlib.util.spec_from_file_location('receiver', Path(__file__).resolve().parents[1] / 'scripts/deploy-server.py')
receiver = importlib.util.module_from_spec(spec)
spec.loader.exec_module(receiver)

class DeliveryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.src = self.root / 'src'
        self.updates = self.root / 'updates'
        self.src.mkdir()
        self.updates.mkdir()
        self.key = Ed25519PrivateKey.generate()
        self.public = base64.b64encode(self.key.public_key().public_bytes_raw()).decode()
        archive = self.src / 'daylex-linux-0.1.0-b201.zip'
        archive.write_bytes(b'synthetic archive')
        self.package = dict(platform='linux', version='0.1.0', build=201, commit='a'*40,
                            archive=archive.name, installer=archive.name, installer_size=archive.stat().st_size,
                            installer_sha256=receiver.digest(archive), notarized=False)
        self.manifest = dict(platform='linux', version='0.1.0', build=201, file=archive.name,
                             size=archive.stat().st_size, sha256=receiver.digest(archive))
        self.write_signed(self.src / 'linux.json', self.manifest)
        self.write_signed(self.src / 'delivery.json', dict(packages=[self.package]))

    def write_signed(self, path, payload):
        text = json.dumps(payload)
        path.write_text(json.dumps(dict(payload=text, signature=base64.b64encode(self.key.sign(text.encode())).decode())))

    def test_valid_delivery(self):
        self.assertEqual(receiver.validate(self.src, self.updates, self.public), [self.package])

    def presentation(self, extra=None):
        files = {name: b'fixture' for name in ('style.css', 'app.js', 'assistenza.html', 'favicon.svg')}
        platforms = ('windows', 'windows', 'macos', 'linux')
        files['index.html'] = ('<html data-site-version="3">New presentation' + ''.join(
            f'<a data-download="{p}" href="downloads/stale">{p}</a>' for p in platforms) + '</html>').encode()
        files['tecnica.html'] = ''.join(f'<!-- release:{p} -->old<!-- /release:{p} -->'
                                       for p in ('windows', 'macos', 'linux')).encode()
        files.update(extra or {})
        archive = self.src / 'daylex-site-b201.zip'
        with zipfile.ZipFile(archive, 'w') as bundle:
            for name, data in files.items(): bundle.writestr(name, data)
        release = dict(kind='site', build=201, commit='b'*40, file=archive.name,
                       size=archive.stat().st_size, sha256=receiver.digest(archive),
                       assets={name: hashlib.sha256(data).hexdigest() for name, data in files.items()})
        self.write_signed(self.src / 'delivery.json', release)
        return release

    def live_site(self):
        site = self.root / 'site'
        previous = site / 'releases/previous'
        (previous / 'downloads').mkdir(parents=True)
        (previous / 'downloads/old.exe').write_bytes(b'old installer')
        info = {p: dict(url=f'downloads/live-{p}.zip', bytes=10, sha256='a'*64,
                       version='0.1.0', build=101) for p in ('windows', 'macos', 'linux')}
        info['web'] = dict(build=901, url='/app/')
        (previous / 'release.json').write_text(json.dumps(info))
        (previous / 'index.html').write_text('Old presentation')
        (previous / 'style.css').write_text('old styles')
        (site / 'current').symlink_to(previous)
        return site, previous

    def test_signed_site_cannot_replace_server_code_or_live_inventory(self):
        for name in ('release.json', 'site-release.json', 'downloads/old.exe',
                     'scripts/receiver.py', 'receiver.py', '../escape'):
            self.presentation({name: b'bad'})
            with self.assertRaises(ValueError):
                receiver.validate_web(self.src, self.root / 'site', self.public, kind='site')

    def test_site_publication_uses_live_downloads_preserves_pwa_and_previous_files(self):
        site, previous = self.live_site()
        release = self.presentation()
        self.assertEqual(receiver.validate_web(self.src, site, self.public, kind='site'), release)
        receiver.publish_site(self.src, release, site)
        home = (site / 'current/index.html').read_text()
        self.assertIn('New presentation', home)
        self.assertNotIn('downloads/stale', home)
        self.assertEqual(home.count('downloads/live-windows.zip'), 2)
        self.assertEqual(json.loads((site / 'current/release.json').read_text())['web']['build'], 901)
        self.assertEqual((site / 'current/downloads/old.exe').read_bytes(), b'old installer')
        self.assertEqual((previous / 'index.html').read_text(), 'Old presentation')
        self.assertEqual((previous / 'style.css').read_text(), 'old styles')
        # A lost SSH response can retry the same signed payload without mutating history.
        self.assertEqual(receiver.validate_web(self.src, site, self.public, kind='site'), release)
        receiver.publish_site(self.src, release, site)
        self.assertEqual((site / 'current/index.html').read_text(), home)
        self.write_signed(site / 'current/site-release.json', dict(release, build=202))
        with self.assertRaises(ValueError): receiver.validate_web(self.src, site, self.public, kind='site')

    def test_native_retry_does_not_revert_a_newer_presentation_or_pwa(self):
        site, _ = self.live_site()
        release = self.presentation()
        receiver.publish_site(self.src, release, site)
        receiver.publish(self.src, [self.package], self.updates, site)
        newer = self.presentation({'style.css': b'newer styles'})
        receiver.publish_site(self.src, newer, site)
        receiver.publish(self.src, [self.package], self.updates, site)
        self.assertEqual((site / 'current/style.css').read_bytes(), b'newer styles')
        self.assertIn('New presentation', (site / 'current/index.html').read_text())
        self.assertEqual(json.loads((site / 'current/release.json').read_text())['web']['build'], 901)
        self.assertIn(self.package['installer'], (site / 'current/index.html').read_text())

    def web_release(self, extra=None):
        archive = self.src / 'daylex-web-b201.zip'
        files = {name: b'fixture' for name in ('index.html', 'main.dart.js', 'runtime.mjs', 'storage.mjs', 'manifest.json', 'service-worker.js', 'flutter_bootstrap.js')}
        files.update(extra or {})
        with zipfile.ZipFile(archive, 'w') as bundle:
            for name, data in files.items(): bundle.writestr(name, data)
        release = dict(kind='web', build=201, commit='a'*40, file=archive.name,
                       size=archive.stat().st_size, sha256=receiver.digest(archive),
                       assets={name: hashlib.sha256(data).hexdigest() for name, data in files.items()})
        self.write_signed(self.src / 'delivery.json', release)
        return release

    def test_web_delivery_rejects_traversal_even_with_valid_signature(self):
        for name in ('../escape', '/absolute', 'nested/../escape', 'a//b', 'web-release.json'):
            self.web_release({name: b'bad'})
            with self.assertRaises(ValueError): receiver.validate_web(self.src, self.root / 'web', self.public)

    def test_web_delivery_checks_each_asset(self):
        release = self.web_release()
        release['assets']['main.dart.js'] = '0'*64
        self.write_signed(self.src / 'delivery.json', release)
        with self.assertRaises(ValueError): receiver.validate_web(self.src, self.root / 'web', self.public)

    def test_web_publish_preserves_desktop_and_rejects_downgrade(self):
        release = self.web_release()
        web = self.root / 'web'
        site = self.root / 'site'
        previous = site / 'releases/previous'
        (previous / 'downloads').mkdir(parents=True)
        (previous / 'downloads/old.dmg').write_bytes(b'previous Mac installer')
        text = '<nav aria-label="Navigazione principale"></nav><article id="macos">Mac download</article>'
        (previous / 'index.html').write_text(text)
        (previous / 'release.json').write_text('{"macos":{"build":601}}')
        (site / 'current').symlink_to(previous)
        self.assertEqual(receiver.validate_web(self.src, web, self.public), release)
        receiver.publish_web(self.src, release, web, site)
        self.assertEqual((web / 'current/main.dart.js').read_bytes(), b'fixture')
        self.assertEqual((previous / 'index.html').read_text(), text)
        self.assertIn('href="/app/"', (site / 'current/index.html').read_text())
        self.assertEqual((site / 'current/downloads/old.dmg').read_bytes(), b'previous Mac installer')
        self.assertEqual(json.loads((site / 'current/release.json').read_text())['macos']['build'], 601)
        self.assertEqual(receiver.validate_web(self.src, web, self.public), release)
        self.write_signed(web / 'current/web-release.json', dict(release, build=202))
        with self.assertRaises(ValueError): receiver.validate_web(self.src, web, self.public)

    def mac_package(self, signing='adhoc', notarized=False):
        archive = self.src / 'daylex-macos-0.1.0-b201.zip'
        archive.write_bytes(b'synthetic Mac archive')
        installer = self.src / 'Daylex-0.1.0-b201-macos-universal.dmg'
        installer.write_bytes(b'synthetic DMG')
        package = dict(self.package, platform='macos', archive=archive.name, installer=installer.name,
                       installer_size=installer.stat().st_size, installer_sha256=receiver.digest(installer),
                       signing=signing, notarized=notarized)
        manifest = dict(self.manifest, platform='macos', file=archive.name,
                        size=archive.stat().st_size, sha256=receiver.digest(archive))
        self.write_signed(self.src / 'macos.json', manifest)
        self.write_signed(self.src / 'delivery.json', dict(packages=[package]))
        return package

    def test_adhoc_mac_delivery_keeps_signed_update_trust(self):
        package = self.mac_package()
        self.assertEqual(receiver.validate(self.src, self.updates, self.public), [package])
        text = receiver.article(package)
        self.assertIn('non notarizzata', text)
        self.assertIn('Apri comunque', text)
        self.assertNotIn('App firmata con Developer ID', text)
        (self.src / package['installer']).write_bytes(b'tampered DMG')
        with self.assertRaises(ValueError): receiver.validate(self.src, self.updates, self.public)

    def test_notarized_mac_delivery_and_disclosure(self):
        package = self.mac_package('developer-id', True)
        self.assertEqual(receiver.validate(self.src, self.updates, self.public), [package])
        self.assertIn('App firmata con Developer ID', receiver.article(package))
        self.assertNotIn('Apri comunque', receiver.article(package))

    def test_inconsistent_mac_signing_claim_rejected(self):
        for mode, notarized in [('adhoc', True), ('developer-id', False), (None, False)]:
            self.mac_package(mode, notarized)
            with self.assertRaises(ValueError): receiver.validate(self.src, self.updates, self.public)

    def test_modified_archive_rejected(self):
        (self.src / self.package['archive']).write_bytes(b'changed')
        with self.assertRaises(ValueError): receiver.validate(self.src, self.updates, self.public)

    def test_marketing_release_keeps_technical_details_out_of_home(self):
        site = self.root / 'marketing'
        site.mkdir()
        (site / 'index.html').write_text('<html data-site-version="2"><a data-platform="linux">Linux</a><article id="linux">old</article></html>')
        (site / 'tecnica.html').write_text('<!-- release:linux -->old<!-- /release:linux -->')
        (site / 'release.json').write_text('{}')
        (site / 'app.js').write_text('')
        receiver.render_site(site, [self.package])
        home = (site / 'index.html').read_text()
        technical = (site / 'tecnica.html').read_text()
        self.assertIn(self.package['installer'], home)
        self.assertIn('Guida all’installazione', home)
        for jargon in ('SHA-256', 'libsecret', 'bash install.sh', 'build '):
            self.assertNotIn(jargon, home)
            self.assertIn(jargon, technical)

    def test_modern_publish_does_not_modify_previous_technical_page(self):
        site = self.root / 'modern-site'
        previous = site / 'releases' / 'previous'
        (previous / 'downloads').mkdir(parents=True)
        (previous / 'index.html').write_text('<html data-site-version="2"><a data-platform="linux">Linux</a><article id="linux">old</article></html>')
        original = '<!-- release:linux -->previous metadata<!-- /release:linux -->'
        (previous / 'tecnica.html').write_text(original)
        (previous / 'release.json').write_text('{}')
        (previous / 'app.js').write_text('')
        (site / 'current').symlink_to(previous)
        receiver.publish(self.src, [self.package], self.updates, site)
        self.assertEqual((previous / 'tecnica.html').read_text(), original)
        self.assertIn(self.package['installer'], (site / 'current/tecnica.html').read_text())

    def test_gateway_updates_both_windows_choices_without_losing_icons(self):
        site = self.root / 'gateway'
        site.mkdir()
        link = '<a data-download="windows" href="downloads/old.exe"><img src="windows.svg">Windows {}</a>'
        (site / 'index.html').write_text('<html data-site-version="3">' + link.format(11) + link.format(10) + '<a href="/app/installa.html">PWA</a></html>')
        (site / 'tecnica.html').write_text('<!-- release:windows -->old<!-- /release:windows -->')
        (site / 'release.json').write_text('{}')
        (site / 'app.js').write_text('')
        package = dict(self.package, platform='windows', installer='Daylex-Setup-new.exe')
        receiver.render_site(site, [package])
        home = (site / 'index.html').read_text()
        self.assertEqual(home.count('downloads/Daylex-Setup-new.exe'), 2)
        self.assertEqual(home.count('<img src="windows.svg">'), 2)
        self.assertIn('/app/installa.html', home)
        self.assertNotIn('SHA-256', home)
        self.assertIn('Daylex-Setup-new.exe', (site / 'tecnica.html').read_text())

    def test_gateway_refuses_missing_download_instead_of_silent_stale_link(self):
        site = self.root / 'invalid-gateway'
        site.mkdir()
        (site / 'index.html').write_text('<html data-site-version="3"></html>')
        (site / 'tecnica.html').write_text('<!-- release:linux -->old<!-- /release:linux -->')
        (site / 'release.json').write_text('{}')
        with self.assertRaisesRegex(ValueError, 'download link missing'):
            receiver.render_site(site, [self.package])

    def test_unsafe_release_directory_rejected(self):
        self.write_signed(self.src / 'delivery.json', dict(packages=[dict(self.package, commit='../../escape')]))
        with self.assertRaises(ValueError): receiver.validate(self.src, self.updates, self.public)

    def test_modified_signature_rejected(self):
        value = json.loads((self.src / 'delivery.json').read_text())
        value['payload'] += ' '
        (self.src / 'delivery.json').write_text(json.dumps(value))
        with self.assertRaises(Exception): receiver.validate(self.src, self.updates, self.public)

    def test_downgrade_rejected(self):
        self.write_signed(self.updates / 'linux.json', dict(self.manifest, build=202))
        with self.assertRaises(ValueError): receiver.validate(self.src, self.updates, self.public)

    def test_same_build_different_bytes_rejected(self):
        self.write_signed(self.updates / 'linux.json', dict(self.manifest, sha256='0'*64))
        with self.assertRaises(ValueError): receiver.validate(self.src, self.updates, self.public)

    def test_idempotent_retry(self):
        self.write_signed(self.updates / 'linux.json', self.manifest)
        self.assertEqual(receiver.validate(self.src, self.updates, self.public), [self.package])

    def test_unsafe_tar_member_rejected(self):
        for name in ('../escape', '/tmp/escape', 'nested/file'):
            stream = io.BytesIO()
            with tarfile.open(fileobj=stream, mode='w') as archive:
                member = tarfile.TarInfo(name)
                member.size = 1
                archive.addfile(member, io.BytesIO(b'x'))
            stream.seek(0)
            with self.assertRaises(ValueError): receiver.receive(stream, self.src)

    def test_site_switch_preserves_previous_downloads_and_page(self):
        site = self.root / 'site'
        previous = site / 'releases' / 'previous'
        (previous / 'downloads').mkdir(parents=True)
        (previous / 'downloads' / 'old.exe').write_bytes(b'old')
        original = '<div><a href="#guide">guide</a></div>\n<div class="platforms"><a data-platform="macos">macOS</a></div><article id="windows">old</article><article id="macos">unavailable</article>'
        (previous / 'index.html').write_text(original)
        (previous / 'release.json').write_text('{}')
        (previous / 'app.js').write_text('')
        (site / 'current').symlink_to(previous)
        receiver.publish(self.src, [self.package], self.updates, site)
        current = (site / 'current').resolve()
        self.assertNotEqual(current, previous)
        self.assertEqual((previous / 'index.html').read_text(), original)
        self.assertEqual((current / 'downloads' / 'old.exe').read_bytes(), b'old')
        self.assertIn('data-platform="linux"', (current / 'index.html').read_text())
        self.assertIn('<div class="platforms"><a data-platform="macos">macOS</a><a href="#linux" data-platform="linux">Linux</a></div>', (current / 'index.html').read_text())
        self.assertIn(self.package['installer'], (current / 'index.html').read_text())
        self.assertEqual(receiver.verified(self.updates / 'linux.json', self.public), self.manifest)

if __name__ == '__main__':
    unittest.main()
