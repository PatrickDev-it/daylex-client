"""Expose real fonts to Flutter's browser-test server, which serves test/ only."""
import os
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parents[1]
app = root / 'app'
flutter = shutil.which('flutter.bat' if os.name == 'nt' else 'flutter')
generated = [app / 'test/assets', app / 'test/canvaskit']
if any(path.exists() for path in generated):
    raise SystemExit('Browser test staging already exists; refusing to replace it')
try:
    shutil.copytree(app / 'assets/fonts', generated[0] / 'assets/fonts')
    # Flutter 3.47's test CanvasKit handler compares a URI to a Windows path.
    # Its test-directory fallback can serve the same unmodified SDK files.
    if os.name == 'nt':
        sdk = Path(flutter).resolve().parents[1]
        shutil.copytree(sdk / 'bin/cache/flutter_web_sdk/canvaskit', generated[1])
    result = subprocess.run([flutter, 'test', '--platform', 'chrome', '--no-pub',
                             '--reporter', 'expanded', 'test/web_compatibility_test.dart'], cwd=app)
finally:
    for path in generated:
        if path.exists() and path.resolve().parent == (app / 'test').resolve():
            shutil.rmtree(path)
raise SystemExit(result.returncode)
