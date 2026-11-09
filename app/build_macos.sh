#!/usr/bin/env bash
# Builds Daylex for macOS on this Mac and packs it, from nothing but Xcode:
#   bash build_macos.sh
# Uses the same pinned toolchain.json SDK as analysis, tests and the other desktop builds.
# Result, in dist/:
#   Daylex.dmg                          the drag-to-Applications disk image, for a first install by hand;
#   daylex-macos-X.Y.Z-bBUILD.zip       the update automatically signed and published by CI.
set -euo pipefail
cd "$(dirname "$0")"

readonly app=Daylex

# Ad-hoc distribution is supported; Gatekeeper approval is required on the user's Mac.
development=false
adhoc=false
case "${1:-}" in
  --development) development=true; adhoc=true ;;
  --adhoc) adhoc=true ;;
  '') ;;
  *) echo "Usage: bash build_macos.sh [--adhoc|--development]"; exit 1 ;;
esac
sign_identity="${DAYLEX_SIGN_IDENTITY:-}"
notary_profile="${DAYLEX_NOTARY_PROFILE:-}"
notary_flags=(--keychain-profile "$notary_profile")
if [[ -n "${DAYLEX_NOTARY_KEYCHAIN:-}" ]]; then notary_flags+=(--keychain "$DAYLEX_NOTARY_KEYCHAIN"); fi
if [[ "$adhoc" == false ]]; then
  [[ "$sign_identity" == "Developer ID Application:"* && -n "$notary_profile" ]] || {
    echo "Distribuzione: configura DAYLEX_SIGN_IDENTITY e DAYLEX_NOTARY_PROFILE (profilo notarytool nel Portachiavi)."
    echo "Per un DMG distribuibile senza notarizzazione: bash build_macos.sh --adhoc"
    exit 1
  }
  sign_flags=(--sign "$sign_identity" --options runtime --timestamp)
else
  sign_flags=(--sign -)
fi

step() { printf '\n== %s\n' "$*"; }

step "Xcode"
if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Serve Xcode (gratuito, dall'App Store): installalo, aprilo una volta, poi rilancia questo script."
  open "macappstore://apps.apple.com/app/xcode/id497799835" || true
  exit 1
fi
xcodebuild -version | sed -n 1p
if ! xcodebuild -license check >/dev/null 2>&1; then
  echo "Accetto la licenza di Xcode (chiede la password del Mac):"
  sudo xcodebuild -license accept
fi

step "Flutter: toolchain verificato"
flutter_home="$(python3 ../scripts/flutter_toolchain.py --path)"
export PATH="${flutter_home}/bin:${PATH}"
flutter config --no-analytics >/dev/null
flutter config --enable-macos-desktop >/dev/null

step "dipendenze"
flutter pub get --enforce-lockfile
if ! command -v node >/dev/null || ! command -v npm >/dev/null; then
  echo "Serve Node.js per il connettore WhatsApp. Installalo e rilancia lo script."
  exit 1
fi
(cd whatsapp_bridge && npm ci --omit=dev --ignore-scripts)

step "build (qualche minuto la prima volta)"
if ! flutter build macos --release --no-pub; then
  if ! command -v pod >/dev/null; then
    echo
    echo "La build richiede CocoaPods. Installalo e rilancia lo script:"
    echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    echo "  brew install cocoapods"
  fi
  exit 1
fi
built="build/macos/Build/Products/Release/${app}.app"
bridge_resources="${built}/Contents/Resources/whatsapp_bridge"
node_helper="${built}/Contents/Helpers/daylex-whatsapp-node"
rm -rf "$bridge_resources"
mkdir -p "$bridge_resources" "${built}/Contents/Helpers"
cp whatsapp_bridge/bridge.js whatsapp_bridge/package.json whatsapp_bridge/package-lock.json "$bridge_resources/"
cp -R whatsapp_bridge/node_modules "$bridge_resources/"
cp "$(command -v node)" "$node_helper"
bash tool/check_macos_runtime.sh "$node_helper"

app_archs="$(lipo -archs "${built}/Contents/MacOS/${app}")"
node_archs="$(lipo -archs "$node_helper")"
for arch in $app_archs; do
  if [[ " $node_archs " != *" $arch "* ]]; then
    echo "Il Node incluso supporta [$node_archs], ma Daylex richiede anche $arch. Usa un Node universale."
    exit 1
  fi
done

step "firma interna e verifica"
# Apple richiede di firmare ogni componente annidato prima dell'app che lo contiene.
if [[ -d "${built}/Contents/Frameworks" ]]; then
  while IFS= read -r -d '' nested; do
    codesign --force "${sign_flags[@]}" "$nested"
  done < <(find "${built}/Contents/Frameworks" -depth \( -type f -name '*.dylib' -o -type d -name '*.framework' \) -print0)
fi
codesign --force "${sign_flags[@]}" --entitlements macos/Runner/Node.entitlements "$node_helper"
codesign --force "${sign_flags[@]}" --entitlements macos/Runner/Release.entitlements "$built"
verify_app() { codesign --verify --deep --strict --verbose=2 "$1"; }
verify_app "$built"
echo "architetture: $app_archs"

step "DMG"
rm -rf dist
mkdir -p dist/dmg
update=""
verify_temp=""
mounted=""
artifacts_verified=false
cleanup_build() {
  if [[ -n "$mounted" ]]; then hdiutil detach -quiet "$mounted" || true; fi
  if [[ -n "$verify_temp" ]]; then rm -rf "$verify_temp"; fi
  rm -rf dist/dmg
  if [[ "$artifacts_verified" != true ]]; then
    rm -f "dist/${app}.dmg"
    if [[ -n "$update" ]]; then rm -f "$update"; fi
  fi
}
trap cleanup_build EXIT
if [[ "$adhoc" == false ]]; then
  step "notarizzazione app"
  ditto -c -k --keepParent "$built" "dist/notarization.zip"
  xcrun notarytool submit "dist/notarization.zip" "${notary_flags[@]}" --wait
  xcrun stapler staple "$built"
  xcrun stapler validate "$built"
  spctl --assess --type execute --verbose=2 "$built"
  rm -f dist/notarization.zip
fi
ditto "$built" "dist/dmg/${app}.app"
ln -s /Applications dist/dmg/Applications
hdiutil create -quiet -volname "$app" -srcfolder dist/dmg -ov -format UDZO "dist/${app}.dmg"
if [[ "$adhoc" == false ]]; then
  codesign --force --sign "$sign_identity" --timestamp "dist/${app}.dmg"
  xcrun notarytool submit "dist/${app}.dmg" "${notary_flags[@]}" --wait
  xcrun stapler staple "dist/${app}.dmg"
  xcrun stapler validate "dist/${app}.dmg"
fi
rm -rf dist/dmg

step "archivio di aggiornamento"
# pubspec's `version: X.Y.Z+BUILD`, the name release.py expects; ditto keeps the bundle's links and attributes.
version="$(sed -n 's/^version:[[:space:]]*\([0-9.]*\)+\([0-9]*\).*/\1-b\2/p' pubspec.yaml)"
[[ -n "$version" ]] || { echo "pubspec.yaml: nessuna riga version: X.Y.Z+BUILD"; exit 1; }
update="dist/daylex-macos-${version}.zip"
if [[ "$development" == true ]]; then update="dist/development-macos-${version}.zip"; fi
ditto -c -k --keepParent "$built" "$update"

step "verifica artefatti"
hdiutil verify "dist/${app}.dmg"
verify_temp="$(mktemp -d "${TMPDIR:-/tmp}/daylex-verify.XXXXXX")"
mkdir "$verify_temp/mount" "$verify_temp/zip"
hdiutil attach -quiet -readonly -nobrowse -mountpoint "$verify_temp/mount" "dist/${app}.dmg"
mounted="$verify_temp/mount"
verify_app "$mounted/${app}.app"
hdiutil detach -quiet "$mounted"
mounted=""
ditto -x -k "$update" "$verify_temp/zip"
verify_app "$verify_temp/zip/${app}.app"
# Record the mode only after both delivered bundles pass signature verification.
if [[ "$adhoc" == true ]]; then
  printf '{"signing":"adhoc","notarized":false}\n' > dist/macos-signing.json
else
  printf '{"signing":"developer-id","notarized":true}\n' > dist/macos-signing.json
fi
artifacts_verified=true
cleanup_build
trap - EXIT
shasum -a 256 "dist/${app}.dmg" "$update"

step "fatto"
if [[ "$development" == true ]]; then
  echo "Build locale ad-hoc: non pubblicabile nel canale aggiornamenti."
  if [[ "${CI:-}" != true ]]; then open dist; fi
  exit 0
fi
echo "dist/${app}.dmg: aprilo e trascina ${app} in Applicazioni (solo la prima installazione)."
if [[ "$adhoc" == true ]]; then
  echo "App non notarizzata: dopo il primo tentativo di apertura, autorizzala da Impostazioni di Sistema > Privacy e sicurezza > Apri comunque."
fi
echo "${update}: pronto per la pipeline di firma e pubblicazione automatica."
if [[ "${CI:-}" != true ]]; then open dist; fi
