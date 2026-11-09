"""Analyze with the same qualified SDK locally and in CI; never suppress diagnostics."""
import os
import subprocess
from flutter_toolchain import ROOT, ensure_sdk

sdk = ensure_sdk()
flutter = sdk / 'bin' / ('flutter.bat' if os.name == 'nt' else 'flutter')
raise SystemExit(subprocess.run([str(flutter), 'analyze', '--no-pub', '--fatal-warnings', '--fatal-infos'], cwd=ROOT / 'app').returncode)
