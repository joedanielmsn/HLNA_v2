#!/usr/bin/env bash
# Step 4: final diff check + changed-file review. Read-only. Does not stage or commit.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/00_common.sh"
guard_paths
cd "$HLNA_REPO" || exit 1

info "git diff --check (whitespace/conflict markers)"
if git diff --check; then echo "clean"; else echo "issues found above"; fi

info "git status --short"
git status --short

info "Files that should NOT be committed (review these)"
git status --short | grep -E '\.hlna-backup|/target/|node_modules|claude/logs/|\.tools/' \
  || echo "none flagged"

info "Quick leftover-identity grep in active config (read-only)"
grep -nE '"publisher"|"endpoints"|"pubkey"|posthog' foundation/jan/src-tauri/tauri*.conf.json 2>/dev/null \
  || echo "no publisher/updater/posthog hits in tauri*.conf.json"

cat <<'EOF'

Day 1 is complete only if: build OK + smoke test PASS + Jan/v1 untouched.
To commit, stage reviewed paths explicitly (never `git add .`), e.g.:
  git add <path1> <path2> ...
  git diff --cached --stat
  git commit -m "..."
No push until you approve.
EOF
