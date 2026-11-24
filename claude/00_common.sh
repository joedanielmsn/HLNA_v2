#!/usr/bin/env bash
# Shared helpers for the HLNA v2 Day 1 scripts. Source this; do not run it.
# Safety: nothing here touches ~/Project_Assistant/HLNA_v1 or real Jan data.

HLNA_REPO="${HLNA_REPO:-$HOME/Project_Assistant/HLNA_v2}"
JAN_DIR="$HLNA_REPO/foundation/jan"
TOOLS_BIN="$HLNA_REPO/.tools/bin"
BINARY_NAME="HLNA-Desktop"
BINARY="$JAN_DIR/src-tauri/target/release/$BINARY_NAME"
TEST_PROFILE="${HLNA_TEST_PROFILE:-$HOME/.hlna-smoke-profile}"
LOG_DIR="$HLNA_REPO/claude/logs"

die()  { echo "ERROR: $*" >&2; exit 1; }
info() { echo "==> $*"; }

guard_paths() {
  [ -d "$HLNA_REPO" ] || die "HLNA_REPO not found: $HLNA_REPO"
  case "$PWD" in
    *HLNA_v1*) die "Refusing to run inside HLNA_v1." ;;
  esac
  case "$HLNA_REPO" in
    *HLNA_v1*) die "HLNA_REPO points at v1. Aborting." ;;
  esac
}

# Make `yarn` resolvable: prefer repo shims, then fall back to `corepack yarn`.
setup_yarn() {
  export COREPACK_ENABLE_DOWNLOAD_PROMPT=0   # Yarn is pinned by foundation/jan; never wait on a hidden prompt
  [ -d "$TOOLS_BIN" ] && export PATH="$TOOLS_BIN:$PATH"
  hash -r
  if command -v yarn >/dev/null 2>&1; then
    YARN=(yarn)
  elif command -v corepack >/dev/null 2>&1; then
    YARN=(corepack yarn)
  else
    die "Neither 'yarn' nor 'corepack' found. Check $TOOLS_BIN and your Node install."
  fi
  # Run from the pinned project dir, never prompt, never wait on stdin, never hang.
  local v
  v="$(cd "$JAN_DIR" 2>/dev/null && COREPACK_ENABLE_DOWNLOAD_PROMPT=0 timeout 30 "${YARN[@]}" --version </dev/null 2>&1 | tail -1)"
  info "Yarn command: ${YARN[*]}  (version: ${v:-unknown/timed out})"
}
