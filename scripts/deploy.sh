#!/usr/bin/env bash
set -euo pipefail
umask 077
mkdir -p "$HOME/.ssh"
printf '%s\n' "$DEPLOY_SSH_KEY" > "$HOME/.ssh/daylex-deploy"
printf '%s\n' "$DEPLOY_KNOWN_HOSTS" > "$HOME/.ssh/known_hosts"
trap 'rm -f "$HOME/.ssh/daylex-deploy"' EXIT
ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o IdentitiesOnly=yes -i "$HOME/.ssh/daylex-deploy" "daylex-release@$DEPLOY_HOST" < delivery.tar
if [[ "${1:-desktop}" == web ]]; then
  python scripts/verify-web.py
else
  python scripts/verify-live.py
fi
