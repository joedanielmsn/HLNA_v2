#!/usr/bin/env bash
# Step 2: one consolidated build of the current HLNA changes.
#   yarn build:web  &&  yarn tauri build --no-bundle      (run from foundation/jan)
# Output is logged to claude/logs/ so a closed terminal does not lose it.
# Does NOT run `yarn install`. Does NOT run cargo fmt.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/00_common.sh"
guard_paths
setup_yarn

if pgrep -af 'tauri build|cargo build|rustc' >/dev/null; then
  die "A build already seems to be running. Wait for it or check: pgrep -af 'tauri|cargo|rustc'"
fi

[ -d "$JAN_DIR/node_modules" ] || die "node_modules missing in $JAN_DIR. Run 'yarn install --immutable' there once, then retry."

mkdir -p "$LOG_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$LOG_DIR/build-$STAMP.log"
cd "$JAN_DIR" || die "cannot cd to $JAN_DIR"

info "Logging to $LOG"
{
  echo "### build:web"
  "${YARN[@]}" build:web || { echo "### FAILED: build:web"; exit 10; }
  echo "### tauri build --no-bundle"
  "${YARN[@]}" tauri build --no-bundle || { echo "### FAILED: tauri build"; exit 11; }
  echo "### BUILD OK"
} 2>&1 | tee "$LOG"
RC=${PIPESTATUS[0]}

if [ "$RC" -ne 0 ]; then
  echo
  echo "Build failed (exit $RC). Last 40 log lines:"
  tail -40 "$LOG"
  echo "Send me those lines; fix only the blocking issue, then rerun this script."
  exit "$RC"
fi

[ -x "$BINARY" ] || die "Build said OK but binary missing: $BINARY"
info "Built: $BINARY"
ls -lh "$BINARY"
echo "Next: bash claude/03_smoke_test.sh"
