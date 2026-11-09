import base64
import importlib.util
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest
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

    def test_modified_archive_rejected(self):
        (self.src / self.package['archive']).write_bytes(b'changed')
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
        original = '<div><a data-platform="macos">macOS</a></div><article id="windows">old</article><article id="macos">unavailable</article>'
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
        self.assertIn(self.package['installer'], (current / 'index.html').read_text())
        self.assertEqual(receiver.verified(self.updates / 'linux.json', self.public), self.manifest)

if __name__ == '__main__':
    unittest.main()
