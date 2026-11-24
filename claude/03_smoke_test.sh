#!/usr/bin/env bash
# Step 3: launch HLNA-Desktop inside a disposable profile so it cannot touch
# real Jan or HLNA v1 data. Then do the brief manual checks printed below.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/00_common.sh"
guard_paths

[ -x "$BINARY" ] || die "Binary not found: $BINARY (run 02_build.sh first)"

# Profile must live outside both projects and must not be a real home dir.
case "$TEST_PROFILE" in
  "$HOME"|"$HOME/"|/|""|*HLNA_v1*|*Project_Assistant*) die "Unsafe test profile path: $TEST_PROFILE" ;;
esac

mkdir -p "$TEST_PROFILE"/{home,config,data,cache,state,hlna-data}

# Fingerprint real Jan/v1 locations before and after (read-only listing).
snapshot() {
  for p in "$HOME/.local/share/Jan" "$HOME/.local/share/jan" "$HOME/.config/Jan" "$HOME/.config/jan" "$HOME/Project_Assistant/HLNA_v1"; do
    [ -e "$p" ] && find "$p" -maxdepth 3 -printf '%p %T@ %s\n' 2>/dev/null
  done | sort | sha256sum | cut -d' ' -f1
}
BEFORE="$(snapshot)"
info "Jan/v1 fingerprint before: $BEFORE"

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

env \
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
info "Jan/v1 fingerprint after:  $AFTER"
if [ "$BEFORE" = "$AFTER" ]; then
  echo "PASS: Jan/v1 locations unchanged."
else
  echo "FAIL: Jan/v1 locations changed. Stop and investigate before continuing."
  exit 20
fi

info "Files the app created in the test profile:"
find "$TEST_PROFILE" -maxdepth 4 -type d | head -40
echo "Next: bash claude/04_final_checks.sh"
