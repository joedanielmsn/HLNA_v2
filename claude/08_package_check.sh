#!/usr/bin/env bash
# Day 4: build (optional) and inspect a Linux package for layout and leftover Jan identity.
#   bash claude/08_package_check.sh --build     # runs: yarn tauri build --bundles deb  (needs a working 02 build first)
#   bash claude/08_package_check.sh             # inspect existing bundles only
# AppImage bundling downloads helper tools at build time; the deb target avoids that, so it is the default here.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/00_common.sh"
guard_paths
BUNDLE_DIR="$JAN_DIR/src-tauri/target/release/bundle"
FAILS=0; bad() { echo "FAIL  $*"; FAILS=$((FAILS+1)); }; ok() { echo "PASS  $*"; }; warn() { echo "WARN  $*"; }

if [ "${1:-}" = "--build" ]; then
  setup_yarn
  mkdir -p "$LOG_DIR"
  cd "$JAN_DIR" || exit 1
  "${YARN[@]}" tauri build --bundles deb 2>&1 | tee "$LOG_DIR/bundle-$(date +%Y%m%d-%H%M%S).log"
  [ "${PIPESTATUS[0]}" -eq 0 ] || die "bundle build failed (see log)"
fi

DEB="$(ls -t "$BUNDLE_DIR"/deb/*.deb 2>/dev/null | head -1)"
[ -n "$DEB" ] || die "No .deb under $BUNDLE_DIR/deb. Run with --build."
info "Inspecting $DEB"
X="$(mktemp -d)"; trap 'rm -rf "$X"' EXIT
( cd "$X" && ar x "$DEB" && mkdir root && tar xf data.tar.* -C root ) || die "cannot unpack deb (need 'ar' and 'tar')"

echo "== Control metadata"
( cd "$X" && tar xf control.tar.* ./control 2>/dev/null || tar xf control.tar.* control 2>/dev/null; cat control 2>/dev/null )

echo "== Identity"
EXE="$(find "$X/root" -type f -name 'HLNA-Desktop' | head -1)"
[ -n "$EXE" ] && ok "HLNA-Desktop present" || bad "HLNA-Desktop binary not in package"
find "$X/root" -type f -iname '*jan*' | grep -v -i 'janus' | sed 's/^/      /' | head
if find "$X/root" -type f -iname '*jan*' | grep -qvi janus; then bad "files with 'jan' in the name (above)"; else ok "no jan-named files"; fi
DESK="$(find "$X/root" -name '*.desktop' | head -1)"
if [ -n "$DESK" ]; then echo "--- $DESK"; cat "$DESK"; grep -qi 'jan' "$DESK" && bad "desktop entry mentions Jan" || ok "desktop entry has no Jan"; else bad "no .desktop entry"; fi

echo "== Resources"
VEC="$(find "$X/root" -name 'sqlite-vec.so' | head -1)"
if [ -n "$VEC" ]; then
  ok "sqlite-vec.so packaged at ${VEC#"$X/root"}"
  case "$VEC" in */resources/bin/sqlite-vec.so) ok "path matches runtime lookup resource_dir/resources/bin" ;; *) bad "unexpected location; runtime expects resources/bin/sqlite-vec.so" ;; esac
else
  warn "sqlite-vec.so not packaged (allowed: optional). Verify the app starts and degrades cleanly without it."
fi

echo "== Strings that should not be in an HLNA build"
if [ -n "$EXE" ] && command -v strings >/dev/null; then
  for pat in posthog 'api\.jan\.ai' 'janhq' 'pubkey'; do
    n="$(strings -a "$EXE" | grep -ciE "$pat")"
    [ "$n" -eq 0 ] && ok "no '$pat' strings" || bad "'$pat' appears $n time(s) in the binary (may be inert dependency text; inspect)"
  done
else warn "'strings' unavailable (install binutils)"; fi

echo; [ "$FAILS" -eq 0 ] && echo "Package check: no failures." || echo "Package check: $FAILS failure(s)."
echo "Still manual: install the .deb/extract in a disposable profile, launch, confirm sqlite-vec loads."
[ "$FAILS" -eq 0 ]
