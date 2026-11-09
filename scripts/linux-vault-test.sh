#!/usr/bin/env bash
set -euo pipefail
export GNOME_KEYRING_CONTROL="$(mktemp -d)"
printf 'ci-only-keyring-password' | gnome-keyring-daemon --unlock --components=secrets
cd app
flutter test integration_test/credential_vault_test.dart -d linux --no-pub
