#!/usr/bin/env bash
# Replaces native/ with the server libraries of an offline_first_core release.
#
#   tool/update_native.sh 0.7.0
#
# Downloads the Linux, macOS and Windows assets of the GitHub release
# v<version>, checks them against the release's SHA256SUMS and lays them out
# as hook/build.dart expects: native/<os>/<architecture>/<library>, one
# architecture per file (the macOS binary is split with lipo). Requires curl,
# shasum and lipo (macOS).
set -euo pipefail

VERSION="${1:?usage: tool/update_native.sh <offline_first_core version>}"
URL="https://github.com/JhonaCodes/offline_first_core/releases/download/v$VERSION"
LIB=liboffline_first_core
cd "$(dirname "$0")/.."

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
ASSETS=(
  SHA256SUMS
  "$LIB-macos-universal.dylib"
  "$LIB-linux-x86_64.so"
  "$LIB-linux-aarch64.so"
  offline_first_core-windows-x86_64.dll
  offline_first_core-windows-arm64.dll
)
for asset in "${ASSETS[@]}"; do
  curl -fsSL -o "$WORK/$asset" "$URL/$asset"
done
# The release lists every platform; only the server assets were downloaded.
(cd "$WORK" && shasum -a 256 -c --ignore-missing SHA256SUMS)

rm -rf native
place() { # <file> <destination under native/>
  mkdir -p "native/$(dirname "$2")"
  cp "$1" "native/$2"
}
thin() { # <universal binary> <architecture> <destination under native/>
  mkdir -p "native/$(dirname "$3")"
  lipo "$1" -thin "$2" -output "native/$3"
}

thin "$WORK/$LIB-macos-universal.dylib" arm64 "macos/arm64/$LIB.dylib"
thin "$WORK/$LIB-macos-universal.dylib" x86_64 "macos/x64/$LIB.dylib"
place "$WORK/$LIB-linux-x86_64.so" "linux/x64/$LIB.so"
place "$WORK/$LIB-linux-aarch64.so" "linux/arm64/$LIB.so"
place "$WORK/offline_first_core-windows-x86_64.dll" "windows/x64/offline_first_core.dll"
place "$WORK/offline_first_core-windows-arm64.dll" "windows/arm64/offline_first_core.dll"

echo "$VERSION" > native/VERSION
(cd native && find . -type f ! -name SHA256SUMS ! -name VERSION -print0 | sort -z | xargs -0 shasum -a 256 > SHA256SUMS)
echo "native/ holds offline_first_core $VERSION"
