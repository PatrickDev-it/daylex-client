# Daylex desktop client

Public client repository, extracted from the private Daylex project at `1192a84a2488dee757cca9191bf674d34ef2fddb`.
No backend implementation, production data, access tokens or signing keys are included.

## Development

Flutter 3.47.2, Dart 3.13.2 and Node 22.21.1. From `app/`, run `flutter pub get --enforce-lockfile`,
then `npm ci --omit=dev --ignore-scripts` in `whatsapp_bridge/`. Run `flutter run -d windows`, `macos` or `linux`.
Linux requires GTK 3, libsecret and a running Secret Service keyring. Credential storage fails closed when
the keyring is unavailable; credentials are never persisted in plaintext.

## Delivery

Every push to `main` builds and tests on `windows-latest`, `macos-latest` and `ubuntu-latest`.
Pull requests run the same qualification without deployment credentials. Build numbers are generated
from the Actions run and attempt; the marketing version remains in `app/pubspec.yaml`.

After all platforms pass, distributable Windows/Linux packages and any signed, notarized Mac package
are signed with the existing Ed25519 release key. A restricted SSH receiver validates signatures,
hashes and monotonic versions, publishes immutable downloads, atomically replaces each updater manifest,
and switches the website release. Public HTTP downloads are verified before a GitHub Release is created.
Unsigned macOS builds are qualification artifacts only and never enter the update channel or website.
Windows installers currently have no Authenticode signature, as disclosed on the download page.

Installed clients check `https://api.daylex.it/updates` at startup, every 30 minutes and on foreground resume.
Downloads are automatic. Installation follows the user's restart action so ongoing work is saved.
Linux installs into a user-owned bundle with `bash install.sh`; system-managed folders cannot self-update.

## Production setup

`production` environment: restrict deployment to `main`. Set `RELEASE_ENABLED=true` and `DEPLOY_HOST` as
repository variables. Store these environment secrets through GitHub Settings or `gh secret set`:

- `RELEASE_SIGNING_KEY`: existing Ed25519 PEM. Never generate a replacement for an installed client fleet.
- `DEPLOY_SSH_KEY`: dedicated forced-command SSH identity; no shell or forwarding.
- `DEPLOY_KNOWN_HOSTS`: verified server host key.

Install `scripts/deploy-server.py` as root-owned `/usr/local/lib/daylex-release/deploy-server.py` on the server.
The `daylex-release` SSH account may run only this receiver through sudo. CI cannot replace receiver code.

For macOS, add repository secrets `APPLE_CERTIFICATE_P12_BASE64`, `APPLE_CERTIFICATE_PASSWORD`,
`APPLE_SIGN_IDENTITY` (Developer ID Application identity), `APPLE_ID`, `APPLE_TEAM_ID`, and
`APPLE_APP_PASSWORD` (app-specific password). Certificates require Apple Developer Program membership.
The workflow creates a temporary keychain and removes it after signing and notarization.

## Scope and recovery

This is now the source of truth for client changes. The original private repository remains intact.
Old versioned downloads and previous website releases are retained. A corrected application release must
always use a newer build number; updater downgrade prevention is intentional.
The Linux support target is Ubuntu x64; its minimum release matches the build runner and is recorded in
the signed package inventory and website (currently Ubuntu 26.04). It does not cover every Linux distribution. `latest` labels track GitHub's
stable images, not necessarily the OS vendor's newest release.
