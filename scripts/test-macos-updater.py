"""Exercise the app's actual updater with native ad-hoc signatures on macOS."""
import hashlib
import os
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
source = (root / 'app/lib/features/update/installer.dart').read_text()
script = re.search(r"const _macScript = r'''(.*?)''';", source, re.S)[1]

def run(*args, **kwargs):
    return subprocess.run(args, check=True, capture_output=True, text=True, **kwargs)

def bundle(path, version):
    contents = path / 'Contents'
    (contents / 'MacOS').mkdir(parents=True)
    with (contents / 'Info.plist').open('wb') as output:
        plistlib.dump(dict(CFBundleIdentifier='it.daylex.updater-test', CFBundleName='Daylex',
                          CFBundleExecutable='Daylex', CFBundlePackageType='APPL',
                          CFBundleVersion=version), output)
    run('clang', '-x', 'c', '-', '-o', str(contents / 'MacOS/Daylex'), input='int main(void) { return 0; }')
    run('codesign', '--force', '--sign', '-', str(path))
    run('codesign', '--verify', '--deep', '--strict', str(path))

with tempfile.TemporaryDirectory(prefix='daylex-updater-') as temp:
    directory = Path(temp)
    harness = directory / 'install.sh'
    harness.write_text(script)
    commands = directory / 'commands'
    commands.mkdir()
    # Launch is outside this file-replacement test; packaged app startup is checked separately.
    (commands / 'open').write_text('#!/bin/sh\nprintf "%s\\n" "$1" > "$LAUNCH_LOG"\n')
    (commands / 'ditto').write_text('#!/bin/sh\nif [ "${FAIL_COPY:-}" = 1 ] && [ "$1" != -x ]; then exit 1; fi\nexec /usr/bin/ditto "$@"\n')
    for command in commands.iterdir():
        command.chmod(0o755)
    # An exited child is a real PID that the updater can safely wait on.
    exited = subprocess.Popen(['/usr/bin/true'])
    exited.wait()
    for scenario in ('valid', 'tampered', 'invalid-signature', 'rollback'):
        case = directory / scenario
        case.mkdir()
        app = case / 'Daylex.app'
        candidate = case / 'candidate/Daylex.app'
        bundle(app, '1')
        bundle(candidate, '2')
        if scenario == 'invalid-signature':
            with (candidate / 'Contents/MacOS/Daylex').open('ab') as binary:
                binary.write(b'corruption')
        archive = case / 'update.zip'
        run('/usr/bin/ditto', '-c', '-k', '--keepParent', str(candidate), str(archive))
        sha = hashlib.sha256(archive.read_bytes()).hexdigest()
        if scenario == 'tampered':
            with archive.open('ab') as output:
                output.write(b'changed after verification')
        work = case / 'work'
        work.mkdir()
        log = case / 'install.log'
        launch = case / 'launch.log'
        env = dict(os.environ, PATH=str(commands) + ':' + os.environ['PATH'], LAUNCH_LOG=str(launch),
                   FAIL_COPY='1' if scenario == 'rollback' else '0')
        result = subprocess.run(['/bin/sh', str(harness), str(exited.pid), str(archive), str(app),
                                 str(work), str(log), sha], env=env, capture_output=True, text=True, timeout=30)
        assert result.returncode == (1 if scenario == 'tampered' else 0), result.stderr
        with (app / 'Contents/Info.plist').open('rb') as installed:
            assert plistlib.load(installed)['CFBundleVersion'] == ('2' if scenario == 'valid' else '1')
        run('codesign', '--verify', '--deep', '--strict', str(app))
        expected = {'valid': 'installed ', 'tampered': 'integrity check failed',
                    'invalid-signature': 'code signature is invalid', 'rollback': 'previous one is back'}[scenario]
        assert expected in log.read_text(), log.read_text()
        assert launch.read_text().strip() == str(app)
        assert not app.with_suffix('.app.old').exists()
        print(f'PASS: macOS updater {scenario}', flush=True)
