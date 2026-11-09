"""Administrative, atomic website installation; retains live installers and app routes.

Run on the server as root: python3 install-site.py SOURCE_DIRECTORY RELEASE_ID
SOURCE_DIRECTORY contains the reviewed site/ and scripts/ from the same commit.
"""
import fcntl
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

source = Path(sys.argv[1]).resolve(strict=True)
release_id = sys.argv[2]
if not re.fullmatch(r'[a-f0-9]{7,40}', release_id):
    raise SystemExit('Expected a Git commit identifier')
site = Path('/srv/daylex-site')
with Path('/srv/daylex-release/publish.lock').open('a') as lock:
    fcntl.flock(lock, fcntl.LOCK_EX)
    previous = (site / 'current').resolve(strict=True)
    candidate = site / 'releases' / f'design-{release_id}'
    if candidate.exists(): raise SystemExit('Release directory already exists')
    shutil.copytree(previous, candidate, copy_function=os.link)
    for file in (source / 'site').rglob('*'):
        if not file.is_file() or file.name == 'release.json': continue
        relative = file.relative_to(source / 'site')
        destination = candidate / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.unlink(missing_ok=True)
        shutil.copyfile(file, destination)
        destination.chmod(0o644)
    # Break inventory hard link before the shared release renderer writes it.
    inventory = candidate / 'release.json'
    data = inventory.read_bytes()
    inventory.unlink()
    inventory.write_bytes(data)
    subprocess.run([sys.executable, str(source / 'scripts/render-site.py'), str(candidate)], check=True)
    for directory in candidate.rglob('*'):
        if directory.is_dir(): directory.chmod(0o755)
    candidate.chmod(0o755)
    # Install the reviewed renderer first so subsequent desktop updates preserve the new home.
    receiver = Path('/usr/local/lib/daylex-release/deploy-server.py')
    staged_receiver = receiver.with_suffix('.next')
    shutil.copyfile(source / 'scripts/deploy-server.py', staged_receiver)
    staged_receiver.chmod(0o755)
    staged_receiver.replace(receiver)
    link = site / '.current-design'
    link.unlink(missing_ok=True)
    link.symlink_to(candidate, target_is_directory=True)
    link.replace(site / 'current')
    print(f'PUBLISHED {candidate.name}; previous={previous.name}')
