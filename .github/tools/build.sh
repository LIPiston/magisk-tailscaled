#!/bin/bash
set -euo pipefail

VERSION="${1:-$(grep '^version=' module.prop | cut -d'=' -f2)}"
DIST_DIR="dist"
BIN_DIR="tailscale/bin"

get_release_asset() {
  local repo="$1"
  local pattern="$2"
  curl --fail --silent --show-error --retry 3 \
    "https://api.github.com/repos/${repo}/releases/latest" |
    jq -r --arg pattern "$pattern" \
      '.assets[] | select(.name | test($pattern)) | .browser_download_url' |
    head -n 1
}

download_tgz_binary() {
  local arch="$1"
  local url
  url="$(get_release_asset 'anasfanani/tailscale-android-cli' "^tailscale_[0-9.]+_${arch}\\.tgz$")"
  [[ -n "$url" && "$url" != "null" ]] || {
    echo "No Tailscale Android asset found for ${arch}" >&2
    exit 1
  }
  echo "- Downloading tailscaled for ${arch}..."
  curl --fail --location --retry 3 --progress-bar "$url" | tar -xz -C "$BIN_DIR"
  [[ -f "$BIN_DIR/tailscaled" ]] || { echo "tailscaled missing after ${arch} extraction" >&2; exit 1; }
  mv "$BIN_DIR/tailscaled" "$BIN_DIR/tailscaled-$arch"
}

download_jq_binary() {
  local arch="$1"
  local file_arch="$2"
  local url
  url="$(get_release_asset 'theshoqanebi/jq-build-for-android' "^jq-${file_arch}$")"
  [[ -n "$url" && "$url" != "null" ]] || {
    echo "No jq Android asset found for ${arch}" >&2
    exit 1
  }
  echo "- Downloading jq for ${arch}..."
  curl --fail --location --retry 3 --progress-bar "$url" -o "$BIN_DIR/jq-$arch"
}

echo "Building Magisk-Tailscaled ${VERSION}"
echo "========================================"

mkdir -p "$BIN_DIR" "$DIST_DIR"
rm -f "$BIN_DIR"/* "$DIST_DIR"/*.zip

echo "Downloading binaries..."
download_tgz_binary arm
download_jq_binary arm armv7a-linux-androideabi
download_tgz_binary arm64
download_jq_binary arm64 aarch64-linux-android

echo
echo "Creating zip without binaries..."
zip -9 -r "${DIST_DIR}/Magisk-Tailscaled-${VERSION}.zip" . \
  -x "*.git*" "dist/*" "*.zip" "*.json" "*.md" "${BIN_DIR}/*" ".shellcheckrc" >/dev/null

echo "Creating zip with binaries..."
zip -9 -r "${DIST_DIR}/Magisk-Tailscaled-${VERSION}-full.zip" . \
  -x "*.git*" "dist/*" "*.zip" "*.json" "*.md" ".shellcheckrc" >/dev/null

rm -f "$BIN_DIR"/*

echo
echo "Build completed successfully!"
echo "========================================"
ls -lh "${DIST_DIR}/"
echo "========================================"
echo "Created: ${DIST_DIR}/Magisk-Tailscaled-${VERSION}.zip (no binaries - downloads on install)"
echo "Created: ${DIST_DIR}/Magisk-Tailscaled-${VERSION}-full.zip (includes all binaries)"
