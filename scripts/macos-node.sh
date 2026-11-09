#!/usr/bin/env bash
# A universal, self-contained Node runtime for the universal Flutter application.
set -euo pipefail
version="$(node --version)"
root="${RUNNER_TEMP}/daylex-universal-node"
mkdir -p "$root"
cd "$root"
curl --fail --silent --show-error --location "https://nodejs.org/dist/${version}/SHASUMS256.txt" -o SHASUMS256.txt
for arch in x64 arm64; do
  archive="node-${version}-darwin-${arch}.tar.gz"
  curl --fail --silent --show-error --location "https://nodejs.org/dist/${version}/${archive}" -o "$archive"
  grep " ${archive}$" SHASUMS256.txt | shasum -a 256 --check
  tar -xzf "$archive"
done
lipo -create "node-${version}-darwin-x64/bin/node" "node-${version}-darwin-arm64/bin/node" -output node
chmod +x node
echo "$root" >> "$GITHUB_PATH"
lipo -archs node
