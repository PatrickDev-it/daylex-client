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
