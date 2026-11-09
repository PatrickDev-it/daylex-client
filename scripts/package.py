"""Client-only packaging. Never imports or copies the private server repository."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'app'
DIST = APP / 'dist'

def version():
    match = re.search(r'^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$',
                      (APP / 'pubspec.yaml').read_text(), re.M)
    if not match:
        raise ValueError('Expected version X.Y.Z+BUILD')
    return match[1], int(match[2])

def set_build(build):
    path = APP / 'pubspec.yaml'
    name, _ = version()
    path.write_text(re.sub(r'^version:.*$', f'version: {name}+{build}', path.read_text(), flags=re.M))

def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def package(platform):
    name, build = version()
    DIST.mkdir(exist_ok=True)
    archive = DIST / f'daylex-{platform}-{name}-b{build}.zip'
    if platform in ('windows', 'linux'):
        bundle = APP / ('build/windows/x64/runner/Release' if platform == 'windows' else 'build/linux/x64/release/bundle')
        executable = bundle / ('paper_agent.exe' if platform == 'windows' else 'paper_agent')
        if not executable.is_file():
            raise ValueError(f'Missing executable: {executable}')
        if platform == 'windows':
            built = subprocess.check_output(['powershell', '-NoProfile', '-Command',
                f"(Get-Item -LiteralPath '{executable}').VersionInfo.ProductVersion"], text=True).strip()
            if built != f'{name}+{build}':
                raise ValueError('Windows binary version does not match release')
        bridge = bundle / 'whatsapp_bridge'
        shutil.copytree(APP / 'whatsapp_bridge', bridge, dirs_exist_ok=True,
                        ignore=shutil.ignore_patterns('.cache', '*.log'))
        shutil.copy2(shutil.which('node'), bridge / ('node.exe' if platform == 'windows' else 'node'))
        if platform == 'linux':
            shutil.copy2(ROOT / 'scripts/install-linux.sh', bundle / 'install.sh')
            (bundle / 'install.sh').chmod(0o755)
        with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as output:
            for file in sorted(bundle.rglob('*')):
                if file.is_file():
                    output.write(file, file.relative_to(bundle).as_posix())
        if platform == 'windows':
            iscc = shutil.which('iscc') or r'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'
            subprocess.run([iscc, f'/DAppVersion={name}', f'/DBuildNumber={build}',
                            str(ROOT / 'scripts/windows.iss')], check=True)
    if not archive.is_file():
        raise ValueError(f'Missing release archive: {archive}')
    installer = (DIST / f'Daylex-Setup-{name}-b{build}-windows-x64.exe' if platform == 'windows'
                 else DIST / 'Daylex.dmg' if platform == 'macos' else archive)
    if platform == 'macos':
        versioned = DIST / f'Daylex-{name}-b{build}-macos-universal.dmg'
        installer.rename(versioned)
        installer = versioned
    for path in {archive, installer}:
        (DIST / f'{path.name}.sha256').write_text(f'{digest(path)}  {path.name}\n')
    metadata = dict(platform=platform, version=name, build=build, archive=archive.name,
                    installer=installer.name, installer_sha256=digest(installer),
                    installer_size=installer.stat().st_size, notarized=platform == 'macos',
                    authenticode=False, commit=os.environ.get('GITHUB_SHA', 'local'))
    (DIST / f'{platform}-package.json').write_text(json.dumps(metadata, indent=2) + '\n')

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--build', type=int)
    parser.add_argument('--platform', choices=['windows', 'macos', 'linux'])
    args = parser.parse_args()
    if args.build:
        set_build(args.build)
    if args.platform:
        package(args.platform)
