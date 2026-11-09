"""One verified Flutter pin for local tools and all CI jobs; no global SDK mutation."""
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
PIN = json.loads((ROOT / 'toolchain.json').read_text())

def ensure_sdk():
    cache = Path(os.environ.get('RUNNER_TEMP') or os.environ.get('LOCALAPPDATA') or Path.home() / '.cache')
    sdk = cache / 'Daylex/toolchains' / ('flutter-' + PIN['flutter'])
    if not sdk.exists():
        sdk.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(['git', '-c', 'core.longpaths=true', 'clone', '--depth', '1', '--branch',
                        PIN['flutter'], 'https://github.com/flutter/flutter.git', str(sdk)], check=True)
    actual = subprocess.check_output(['git', '-C', str(sdk), 'rev-parse', 'HEAD'], text=True).strip()
    if actual != PIN['commit']:
        raise RuntimeError('Flutter checkout does not match the approved toolchain commit')
    flutter = sdk / 'bin' / ('flutter.bat' if os.name == 'nt' else 'flutter')
    subprocess.run([str(flutter), '--version'], check=True, stdout=sys.stderr)
    if (sdk / 'bin/cache/dart-sdk/version').read_text().strip() != PIN['dart']:
        raise RuntimeError('Flutter downloaded an unexpected Dart SDK')
    return sdk

if __name__ == '__main__':
    sdk = ensure_sdk()
    if os.environ.get('GITHUB_PATH'):
        with open(os.environ['GITHUB_PATH'], 'a') as output:
            output.write(str(sdk / 'bin') + '\n')
    print(str(sdk) if '--path' in sys.argv[1:] else f'Qualified toolchain: {sdk}')
