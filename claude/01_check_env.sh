#!/usr/bin/env bash
# Step 1: fix the "yarn: command not found" problem and check for a leftover build.
# Read-only: installs nothing, deletes nothing.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/00_common.sh"
guard_paths

info "Leftover build processes (from the crashed terminal)?"
{ pgrep -ax cargo; pgrep -ax rustc; } || echo "none running"

info "Tool locations and versions"
for t in node npm cargo rustc git cmake corepack yarn; do
  if command -v "$t" >/dev/null 2>&1; then
    # cd into the pinned project (yarn/corepack read packageManager there), no prompts, no stdin, 15s cap
    v="$(cd "$JAN_DIR" 2>/dev/null; COREPACK_ENABLE_DOWNLOAD_PROMPT=0 timeout 15 "$t" --version </dev/null 2>&1 | head -1)"
    printf '%-9s %s  (%s)\n' "$t" "$(command -v "$t")" "${v:-no version / timed out}"
  else
    printf '%-9s MISSING\n' "$t"
  fi
done

info "Git branch / state (read-only)"
git -C "$HLNA_REPO" branch --show-current
git -C "$HLNA_REPO" status --short | head -50

if ! command -v yarn >/dev/null 2>&1 && ! command -v corepack >/dev/null 2>&1; then
  cat <<'EOF'

Neither yarn nor corepack is installed (Node 25+ no longer bundles corepack).
Fix on Arch/CachyOS:
  sudo pacman -S --needed corepack
  mkdir -p ~/.local/bin && corepack enable --install-directory ~/.local/bin
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
  export PATH="$HOME/.local/bin:$PATH"; hash -r
  (cd foundation/jan && yarn --version)     # expect 4.5.3
EOF
  exit 1
fi

setup_yarn
echo
echo "If the yarn version above printed 4.5.3, run: bash claude/02_build.sh"
