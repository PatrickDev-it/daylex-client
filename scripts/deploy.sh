#!/usr/bin/env bash
set -euo pipefail
umask 077
mkdir -p "$HOME/.ssh"
printf '%s\n' "$DEPLOY_SSH_KEY" > "$HOME/.ssh/daylex-deploy"
printf '%s\n' "$DEPLOY_KNOWN_HOSTS" > "$HOME/.ssh/known_hosts"
trap 'rm -f "$HOME/.ssh/daylex-deploy"' EXIT
for attempt in 1 2 3; do
  if ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o ConnectTimeout=20 -o ServerAliveInterval=15 -o ServerAliveCountMax=4 -o IdentitiesOnly=yes -i "$HOME/.ssh/daylex-deploy" "daylex-release@$DEPLOY_HOST" < delivery.tar; then break; fi
  if [[ "$attempt" == 3 ]]; then exit 1; fi
  sleep "$((attempt * 10))"
done
if [[ "${1:-desktop}" == web ]]; then
  verifier=scripts/verify-web.py
elif [[ "${1:-desktop}" == site ]]; then
  verifier=scripts/verify-site.py
else
  verifier=scripts/verify-live.py
fi
for attempt in 1 2 3; do
  if python "$verifier"; then exit 0; fi
  if [[ "$attempt" == 3 ]]; then exit 1; fi
  sleep "$((attempt * 10))"
done
