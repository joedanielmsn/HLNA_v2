#!/usr/bin/env bash
# Day 4: replace "download floating latest sqlite-vec" with a pinned, checksum-verified download.
#
#   bash claude/07_pin_sqlite_vec.sh --print <version>   # download once, show SHA-256 for YOU to verify
#   bash claude/07_pin_sqlite_vec.sh --install           # install the pinned version, verified
#
# Trust model: --print is trust-on-first-use. Compare the printed SHA-256 with the digest shown on the
# release page https://github.com/asg017/sqlite-vec/releases before you write it into the pin file.
# Pin file: claude/pins/sqlite-vec.pin   (VERSION=..., SHA256=..., ASSET=...)
# Nothing is invented here: no checksum is shipped in this script.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/00_common.sh"
guard_paths

PIN="$DIR/pins/sqlite-vec.pin"
DEST="${SQLITE_VEC_DEST:-$JAN_DIR/src-tauri/resources/bin}"   # must match Tauri resource config / runtime lookup
ARCH="$(uname -m)"; case "$ARCH" in x86_64|amd64) ARCH=x86_64 ;; aarch64|arm64) ARCH=aarch64 ;; esac
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

asset_for() { echo "sqlite-vec-$1-loadable-linux-$ARCH.tar.gz"; }
url_for()   { echo "https://github.com/asg017/sqlite-vec/releases/download/v$1/$(asset_for "$1")"; }

fetch() { # version -> $WORK/asset
  info "Downloading $(url_for "$1")"
  curl -fL --proto '=https' --tlsv1.2 --max-time 120 -o "$WORK/asset.tgz" "$(url_for "$1")" \
    || die "download failed (wrong version or asset name? check the releases page)"
}

case "${1:-}" in
  --print)
    V="${2:?usage: --print <version, e.g. 0.1.6>}"
    fetch "$V"
    SUM="$(sha256sum "$WORK/asset.tgz" | cut -d' ' -f1)"
    info "Archive members:"; tar tzf "$WORK/asset.tgz"
    mkdir -p "$DIR/pins"
    cat <<EOF

Verify this SHA-256 against the release page, then save it:

  VERSION=$V
  ASSET=$(asset_for "$V")
  SHA256=$SUM

Write those three lines to: $PIN
EOF
    ;;
  --install)
    [ -f "$PIN" ] || die "No pin file. Run --print <version> first and save the verified values to $PIN"
    # Parse key=value lines; never execute the pin file as shell.
    getp() { sed -n "s/^$1=//p" "$PIN" | head -1 | tr -d ' \t\r'; }
    VERSION="$(getp VERSION)"; ASSET="$(getp ASSET)"; SHA256="$(getp SHA256)"
    [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.]+)?$ ]] || die "pin VERSION missing or malformed"
    [[ "$SHA256" =~ ^[0-9a-f]{64}$ ]] || die "pin SHA256 missing or not 64 lowercase hex chars"
    [ "$ASSET" = "$(asset_for "$VERSION")" ] || die "pin ASSET ($ASSET) does not match this machine ($(asset_for "$VERSION"))"
    fetch "$VERSION"
    echo "$SHA256  $WORK/asset.tgz" | sha256sum -c - || die "CHECKSUM MISMATCH - refusing to install"
    tar xzf "$WORK/asset.tgz" -C "$WORK"
    SRC="$(find "$WORK" -maxdepth 2 -name 'vec0.so' | head -1)"
    [ -n "$SRC" ] || { echo "Archive contents:"; tar tzf "$WORK/asset.tgz"; die "vec0.so not found in archive"; }
    mkdir -p "$DEST"
    install -m 0644 "$SRC" "$DEST/sqlite-vec.so"
    info "Installed $DEST/sqlite-vec.so (sqlite-vec v$VERSION, checksum verified)"
    ls -l "$DEST/sqlite-vec.so"
    echo "NOTE: confirm the packaged app really loads it (Day 4 package check), and that a build without it still starts."
    ;;
  *) die "usage: $0 --print <version> | --install" ;;
esac
