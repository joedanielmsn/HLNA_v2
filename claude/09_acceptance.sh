#!/usr/bin/env bash
# Day 4/5: automated subset of the Section 13 acceptance criteria. Read-only except `cargo test` build output.
# Automated here != complete: the manual list at the end must still be done and recorded honestly.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/00_common.sh"
guard_paths
PASS=0; FAIL=0; SKIP=0
ok()   { echo "PASS  $*"; PASS=$((PASS+1)); }
bad()  { echo "FAIL  $*"; FAIL=$((FAIL+1)); }
skip() { echo "SKIP  $*"; SKIP=$((SKIP+1)); }
CONF="$(ls "$JAN_DIR"/src-tauri/tauri*.conf.json 2>/dev/null)"

echo "== Build artifact"
[ -x "$BINARY" ] && ok "$BINARY exists" || bad "binary missing (run 02_build.sh)"

echo "== Identity (config)"
grep -q '"productName": *"HLNA"' $CONF && ok "productName HLNA" || bad "productName is not HLNA"
grep -q 'ai\.hlna\.desktop' $CONF && ok "identifier ai.hlna.desktop" || bad "identifier not ai.hlna.desktop"
grep -qE '"publisher"' $CONF && bad "publisher still set (plan: remove inherited Jan publisher)" || ok "no publisher"

echo "== Updater removed"
grep -qE '"pubkey"|"endpoints"' $CONF && bad "updater key/endpoint in tauri config" || ok "no updater key/endpoint in config"
grep -rqE 'updater:' "$JAN_DIR/src-tauri/capabilities" 2>/dev/null && bad "updater permission in capabilities" || ok "no updater capability"

echo "== Privacy"
if [ -x "$BINARY" ] && command -v strings >/dev/null; then
  n="$(strings -a "$BINARY" | grep -ciE 'posthog')"
  [ "$n" -eq 0 ] && ok "no posthog strings in binary" || bad "posthog appears $n time(s) in binary"
else skip "binary string check"; fi
# The frontend is embedded compressed in the binary, so `strings` cannot see it. Check the built web assets directly.
WEBDIST="$(find "$JAN_DIR" -maxdepth 3 -type d -name dist -path '*web-app*' -not -path '*/node_modules/*' 2>/dev/null | head -1)"
if [ -n "$WEBDIST" ]; then
  n="$(grep -rlE 'posthog\.com|i\.posthog' "$WEBDIST" 2>/dev/null | wc -l)"
  [ "$n" -eq 0 ] && ok "no PostHog hosts in built web assets ($WEBDIST)" || bad "$n built web file(s) reference PostHog hosts (e.g. $(grep -rlE 'posthog\.com|i\.posthog' "$WEBDIST" | head -1))"
else skip "built web assets (web-app/dist not found; run build:web)"; fi
grep -rqE 'JAN_DATA_(ROOT|FOLDER)' "$JAN_DIR/src-tauri/src" 2>/dev/null && bad "old JAN_DATA_* env vars still in Rust" || ok "no JAN_DATA_* in Rust"

echo "== Permission broker core"
if cargo test --offline --manifest-path "$DIR/broker/Cargo.toml" -q >/tmp/hlna-broker-test.log 2>&1; then ok "broker unit tests"; else bad "broker tests failed: /tmp/hlna-broker-test.log"; fi

echo "== Git hygiene"
cd "$HLNA_REPO" || exit 1
git diff --check >/dev/null 2>&1 && ok "git diff --check clean" || bad "git diff --check reports problems"
git ls-files --others --exclude-standard | grep -qE '\.hlna-backup|/target/|node_modules' && bad "build/backup files untracked and not ignored" || ok "no stray build/backup files"

echo; echo "Result: $PASS pass, $FAIL fail, $SKIP skipped"
cat <<'EOF'

MANUAL (record results in release notes, do not claim them unverified):
  [ ] Starts/stops reliably; works offline with local inference
  [ ] Model/context settings persist (4K-16K, default 16K)
  [ ] No Jan/v1 data access (03_smoke_test fingerprint PASS)
  [ ] Every privileged operation goes through the broker (needs integration; currently NOT wired)
  [ ] Permissions visible, scoped, revocable; destructive actions prompt
  [ ] Cancel / emergency stop work in the app
  [ ] Models unload and free VRAM (06_core_check step 6 covers Ollama side)
  [ ] Backup/restore of the HLNA data folder works
  [ ] UI stays responsive on the 4 GB GPU
EOF
[ "$FAIL" -eq 0 ]
