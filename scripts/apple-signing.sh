#!/usr/bin/env bash
set -euo pipefail
if [[ -z "$CERTIFICATE" || -z "$CERTIFICATE_PASSWORD" || -z "$APPLE_ID" || -z "$APPLE_TEAM_ID" || -z "$APPLE_APP_PASSWORD" || -z "$SIGN_IDENTITY" ]]; then
  echo 'ready=false' >> "$GITHUB_OUTPUT"
  exit 0
fi
keychain="$RUNNER_TEMP/daylex-signing.keychain-db"
password="$(openssl rand -hex 32)"
echo "::add-mask::$password"
export CERTIFICATE_FILE="$RUNNER_TEMP/daylex-certificate.p12"
python -c 'import base64,os,pathlib; pathlib.Path(os.environ["CERTIFICATE_FILE"]).write_bytes(base64.b64decode(os.environ["CERTIFICATE"]))'
trap 'rm -f "$CERTIFICATE_FILE"' EXIT
security create-keychain -p "$password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$password" "$keychain"
security import "$CERTIFICATE_FILE" -P "$CERTIFICATE_PASSWORD" -A -t cert -f pkcs12 -k "$keychain"
security set-key-partition-list -S apple-tool:,apple: -k "$password" "$keychain"
security list-keychains -d user -s "$keychain" "$HOME/Library/Keychains/login.keychain-db"
xcrun notarytool store-credentials daylex-ci --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_PASSWORD" --keychain "$keychain"
echo 'ready=true' >> "$GITHUB_OUTPUT"
echo "identity=$SIGN_IDENTITY" >> "$GITHUB_OUTPUT"
echo 'profile=daylex-ci' >> "$GITHUB_OUTPUT"
