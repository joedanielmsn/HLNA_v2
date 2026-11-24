#!/usr/bin/env bash
# Step 3: launch HLNA-Desktop inside a disposable profile so it cannot touch
# real Jan or HLNA v1 data. Then do the brief manual checks printed below.
#
# Optional env:
#   HLNA_WEBKIT_WORKAROUND=1   set WEBKIT_DISABLE_DMABUF_RENDERER=1 (blank/white window
#                              is a common WebKitGTK problem on NVIDIA; try if the UI is empty)
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/00_common.sh"
guard_paths

[ -x "$BINARY" ] || die "Binary not found: $BINARY (run 02_build.sh first)"

case "$TEST_PROFILE" in
  "$HOME"|"$HOME/"|/|""|*HLNA_v1*|*Project_Assistant*) die "Unsafe test profile path: $TEST_PROFILE" ;;
esac

mkdir -p "$TEST_PROFILE"/{home,config,data,cache,state,hlna-data}

# Read-only fingerprint of REAL Jan locations only. HLNA_v1 is deliberately NOT read
# (the plan forbids entering it, and its working files change legitimately).
# If real Jan is running while you test, this can false-fail: close it first.
snapshot() {
  for p in "$HOME/.local/share/Jan" "$HOME/.local/share/jan" "$HOME/.local/share/jan.ai.app" \
           "$HOME/.config/Jan" "$HOME/.config/jan" "$HOME/.config/jan.ai.app" "$HOME/jan"; do
    [ -e "$p" ] && find "$p" -maxdepth 3 -printf '%p %T@ %s\n' 2>/dev/null
  done | sort | sha256sum | cut -d' ' -f1
}
BEFORE="$(snapshot)"
info "Jan fingerprint before: $BEFORE"

info "Checking Ollama"
if curl -fsS --max-time 3 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
  echo "Ollama reachable. Models:"
  curl -fsS http://127.0.0.1:11434/api/tags | grep -o '"name":"[^"]*"' || true
else
  echo "WARNING: Ollama not reachable on 127.0.0.1:11434 (chat check will fail)."
fi

cat <<EOF

Launching with profile: $TEST_PROFILE
Manual checklist (close the app window when done):
  [ ] App opens and says HLNA (not Jan)
  [ ] No analytics consent prompt, no updater prompt
  [ ] Add Ollama provider (http://127.0.0.1:11434), chat with a model, response streams
  [ ] Close and reopen: your chat is still there
EOF

# Keep X11 auth working even though HOME is redirected.
XAUTH="${XAUTHORITY:-$HOME/.Xauthority}"
EXTRA_ENV=()
[ "${HLNA_WEBKIT_WORKAROUND:-0}" = "1" ] && EXTRA_ENV+=(WEBKIT_DISABLE_DMABUF_RENDERER=1)

env "${EXTRA_ENV[@]}" \
  XAUTHORITY="$XAUTH" \
  HOME="$TEST_PROFILE/home" \
  XDG_CONFIG_HOME="$TEST_PROFILE/config" \
  XDG_DATA_HOME="$TEST_PROFILE/data" \
  XDG_CACHE_HOME="$TEST_PROFILE/cache" \
  XDG_STATE_HOME="$TEST_PROFILE/state" \
  HLNA_DATA_ROOT="$TEST_PROFILE/hlna-data" \
  HLNA_DATA_FOLDER="$TEST_PROFILE/hlna-data" \
  "$BINARY"
RC=$?

AFTER="$(snapshot)"
info "App exited with code $RC"
info "Jan fingerprint after:  $AFTER"
if [ "$BEFORE" = "$AFTER" ]; then
  echo "PASS: real Jan locations unchanged."
else
  echo "FAIL: real Jan locations changed. Stop and investigate before continuing."
  exit 20
fi

info "Directories the app created in the test profile:"
find "$TEST_PROFILE" -maxdepth 4 -type d | head -40
echo "Next: bash claude/04_final_checks.sh"
