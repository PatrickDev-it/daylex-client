#!/usr/bin/env bash
# Run administratively after copying the audited receiver and CI public key into /tmp.
set -euo pipefail
test "$(id -u)" = 0
id daylex-release >/dev/null 2>&1 || useradd --create-home --shell /bin/sh daylex-release
install -d -o root -g root -m 755 /usr/local/lib/daylex-release
install -o root -g root -m 755 /tmp/daylex-ci-deploy-server.py /usr/local/lib/daylex-release/deploy-server.py
install -d -o root -g root -m 750 /srv/daylex-release
install -d -o daylex-release -g daylex-release -m 700 /home/daylex-release/.ssh
python3 - <<'PY'
from pathlib import Path
key = Path('/tmp/daylex-ci-key.pub').read_text().strip()
assert key.startswith('ssh-ed25519 ') and '\n' not in key
Path('/home/daylex-release/.ssh/authorized_keys').write_text(
    'restrict,command="sudo -n /usr/local/lib/daylex-release/deploy-server.py" ' + key + '\n')
Path('/etc/sudoers.d/daylex-release').write_text(
    'daylex-release ALL=(root) NOPASSWD: /usr/local/lib/daylex-release/deploy-server.py ""\n')
PY
chown daylex-release:daylex-release /home/daylex-release/.ssh/authorized_keys
chmod 600 /home/daylex-release/.ssh/authorized_keys
chmod 440 /etc/sudoers.d/daylex-release
visudo -cf /etc/sudoers.d/daylex-release
echo 'Dedicated forced-command release account configured.'
