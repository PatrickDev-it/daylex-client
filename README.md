# Daylex desktop client

Public client repository, extracted from the private Daylex project at `1192a84a2488dee757cca9191bf674d34ef2fddb`.
No backend implementation, production data, access tokens or signing keys are included.

## Development

Flutter 3.47.2, Dart 3.13.2 and Node 22.21.1. From `app/`, run `flutter pub get --enforce-lockfile`,
then `npm ci --omit=dev --ignore-scripts` in `whatsapp_bridge/`. Run `flutter run -d windows`, `macos` or `linux`.
Linux requires GTK 3, libsecret and a running Secret Service keyring. Credential storage fails closed when
the keyring is unavailable; credentials are never persisted in plaintext.

## Product target

Daylex primarily serves desktop PCs and large screens. Tablet use is secondary; phone-first redesign is
not a product goal. The complementary PWA should preserve document editing, agent chat, preview and PDF
export. WhatsApp remains a desktop-only integration and is intentionally unsupported on the web.

## iOS distribution assessment (9 November 2026)

| Channel | Requirements and fit |
| --- | --- |
| [AltStore PAL](https://faq.altstore.io/developers/distribute-with-altstore-pal) | Alternative marketplace, including EU users. Requires paid Apple Developer membership, App Store Connect and notarization. Suitable if native iPad distribution becomes necessary. |
| [Aptoide](https://docs.connect.aptoide.com/docs/onboarding-guide-ios) | Alternative iOS distribution through Aptoide Connect; requires partner onboarding, Apple distribution integration and review. Adds a commercial/operational dependency. |
| [Epic Games Store mobile](https://dev.epicgames.com/community/learning/tutorials/rvdp/epic-games-store-mobile-developer-resources) | Mobile publishing resources exist; a gaming-focused channel is not the preferred route for this document workspace. |
| [Setapp Mobile](https://support.setapp.com/hc/en-us/articles/25494771202716-Setapp-Mobile-sunset) | Discontinued on 16 February 2026; not a distribution option. |
| [PWA](https://developer.mozilla.org/en-US/docs/Web/Progressive_web_apps/Guides/Installing) | Installable from the website, including Safari's Add to Home Screen. No native iOS marketplace submission; browser capabilities apply. Preferred complementary route for occasional tablet use. |

Native alternative distribution is possible; it does not remove Apple signing/notarization requirements.
For AltStore PAL: register the developer through its API, add its token in App Store Connect, enable
build notifications, submit for notarization, host the unmodified Alternative Distribution Package and
publish the source JSON. CI can upload builds and refresh the source after approval; it cannot skip review.
Apple's [current EU terms](https://developer.apple.com/support/apps-in-the-eu/) also permit authorized
direct Web Distribution of native apps, subject to eligibility and notarization. This differs from a PWA.
Terms changed in October 2026; older guides about mandatory EU establishment or the former per-install
Core Technology Fee are not a reliable basis for implementation.

## Delivery

Every push to `main` builds and tests on `windows-latest`, `macos-latest` and `ubuntu-latest`.
Pull requests run the same qualification without deployment credentials. Build numbers are generated
from the Actions run and attempt; the marketing version remains in `app/pubspec.yaml`.

After all platforms pass, Windows/Linux/macOS package manifests and the delivery inventory
are signed with the existing Ed25519 release key. A restricted SSH receiver validates signatures,
hashes and monotonic versions, publishes immutable downloads, atomically replaces each updater manifest,
and switches the website release. Public HTTP downloads are verified before a GitHub Release is created.
macOS publishes a universal DMG and update ZIP with ad-hoc code signatures when Apple credentials are absent.
These builds are not notarized: after dragging Daylex into Applications and attempting to launch it,
users may need System Settings > Privacy & Security > Open Anyway. macOS may request approval again
after updates, including access to the login Keychain. No system security settings are disabled.
Local equivalent: `cd app` then `bash build_macos.sh --adhoc`.
Windows installers currently have no Authenticode signature, as disclosed on the download page.

Installed clients check `https://api.daylex.it/updates` at startup, every 30 minutes and on foreground resume.
Downloads are automatic. Installation follows the user's restart action so ongoing work is saved.
Linux installs into a user-owned bundle with `bash install.sh`; system-managed folders cannot self-update.

## Production setup

The companion PWA lives at `https://daylex.it/app/`. Its separate `Build and publish PWA` workflow
checks browser persistence/recovery, browser compatibility and PDF rendering, then signs the complete
static asset inventory. The same restricted receiver verifies every asset and atomically switches the
web release. The desktop release pipeline remains independent.

For local web development: run `npm ci --ignore-scripts` in `web-tools/`, then from this repository
run `python scripts/build-web.py` and `python scripts/preview-web.py`. Open `http://127.0.0.1:8765/app/`.
`--fixture` is an explicit loopback-only test API with synthetic data; it is never deployed.

The PWA uses IndexedDB for documents/chats and a Web Lock to prevent conflicting writes across tabs.
The toolbar exports/imports the local archive; importing downloads a backup and retains a recovery copy.
Browser data is separate from desktop data and can be removed by clearing site data. It does not sync
automatically between devices. Access keys remain in session memory; the browser's device identity is
persistent. With the existing one-device key policy, use a dedicated key for the browser, supplied by
the administrator. No access keys are written to IndexedDB, CacheStorage, localStorage or source code.

The service worker caches only hashed public build assets, never API responses, user documents or
credentials. New releases download in the background; “Salva e ricarica” commits pending work before
activating them. AI/review require connectivity; a new session requires the access key again.
On iPad, use Safari > Share > Add to Home Screen. Native iOS marketplace distribution is not configured.

For server setup, `scripts/daylex-site.caddy` serves the website, `/app/` and the existing authenticated
`/v1/` API on one origin, avoiding cross-origin credential handling. Validate before reloading Caddy.
The PWA's CSP permits dynamic code evaluation required by the PDF printing dependency; scripts, fonts,
PDF.js, workers and CanvasKit are self-hosted. The download website keeps its stricter separate CSP.

`production` environment: restrict deployment to `main`. Set `RELEASE_ENABLED=true` and `DEPLOY_HOST` as
repository variables. Store these environment secrets through GitHub Settings or `gh secret set`:

- `RELEASE_SIGNING_KEY`: existing Ed25519 PEM. Never generate a replacement for an installed client fleet.
- `DEPLOY_SSH_KEY`: dedicated forced-command SSH identity; no shell or forwarding.
- `DEPLOY_KNOWN_HOSTS`: verified server host key.

Install `scripts/deploy-server.py` as root-owned `/usr/local/lib/daylex-release/deploy-server.py` on the server.
The `daylex-release` SSH account may run only this receiver through sudo. CI cannot replace receiver code.

For optional macOS Developer ID signing and notarization, add repository secrets `APPLE_CERTIFICATE_P12_BASE64`, `APPLE_CERTIFICATE_PASSWORD`,
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
