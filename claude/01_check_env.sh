#!/usr/bin/env bash
# Step 1: fix the "yarn: command not found" problem and check for a leftover build.
# Read-only: installs nothing, deletes nothing.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/00_common.sh"
guard_paths

info "Leftover build processes (from the crashed terminal)?"
pgrep -af 'tauri|cargo|rustc' || echo "none running"

info "Shims in $TOOLS_BIN"
ls -la "$TOOLS_BIN" 2>/dev/null || echo "(directory missing)"

info "Tool locations"
command -v corepack node npm cargo git cmake || true

setup_yarn

info "Tool versions"
node --version; npm --version; cargo --version; git --version; cmake --version | head -1

info "Git branch / state (read-only)"
git -C "$HLNA_REPO" branch --show-current
git -C "$HLNA_REPO" status --short | head -50

echo
echo "If the yarn version above printed 4.5.3, run: bash claude/02_build.sh"
