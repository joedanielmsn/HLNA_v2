#!/usr/bin/env bash
# Day 5: release helpers. Never pushes. Tagging requires --confirm.
#   bash claude/10_release.sh notes              # draft release notes (edit before use)
#   bash claude/10_release.sh checksums          # SHA-256 of built artifacts
#   bash claude/10_release.sh licenses           # Rust dependency licenses (offline cargo metadata)
#   bash claude/10_release.sh tag v0.1.0 --confirm   # annotated local tag only
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/00_common.sh"
guard_paths
OUT="$HLNA_REPO/claude/release"; mkdir -p "$OUT"
BUNDLES="$JAN_DIR/src-tauri/target/release/bundle"

case "${1:-}" in
  notes)
    cat > "$OUT/RELEASE_NOTES.draft.md" <<EOF
# HLNA v2 first desktop release (DRAFT, $(date +%F))

Based on Jan commit 49a84bdeaebdfc0f36c00f252eb638f516a48432 (pinned import). Jan license and attribution retained.

## Included (check each against what you actually verified)
- [ ] HLNA identity (name, binary, bundle id) and separate data directory
- [ ] No analytics, no auto-updater
- [ ] Chat with local models through Ollama; streaming, history, 4K-16K context (default 16K)
- [ ] Permission broker core (library only; see limitations)

## Verified (fill in with evidence only)
- Build: <command, date, result>
- Isolated smoke test: <date, result>
- Tests: sqlite-vec plugin 17/17; broker 16/16

## Known limitations
- Permission broker is not yet wired into every tool/MCP call path.
- sqlite-vec: <pinned & checksum-verified | optional and absent>; packaged loading <verified | not verified>.
- Extension workers are not a hardened sandbox.
- Tauri capabilities reviewed: <yes/no; link to audit report>.

## Deferred
Voice, workflows, gaming mode, floating companion, computer automation, Linux distribution, auto-update.

## Not claimed
This release is not "fully secure" or "production hardened".
EOF
    echo "Wrote $OUT/RELEASE_NOTES.draft.md" ;;
  checksums)
    [ -d "$BUNDLES" ] || die "no bundles at $BUNDLES (run 08_package_check.sh --build)"
    ( cd "$BUNDLES" && find . -type f \( -name '*.deb' -o -name '*.rpm' -o -name '*.AppImage' \) -print0 | xargs -0 -r sha256sum ) | tee "$OUT/SHA256SUMS"
    [ -s "$OUT/SHA256SUMS" ] || echo "no packages found" ;;
  licenses)
    cd "$JAN_DIR/src-tauri" || exit 1
    command -v python3 >/dev/null || die "python3 required"
    cargo metadata --format-version 1 --offline 2>/dev/null | python3 -I -c '
import json,sys
m=json.load(sys.stdin)
rows=sorted({(p["name"],p["version"],p.get("license") or "UNKNOWN") for p in m["packages"]})
print("name,version,license")
for r in rows: print(",".join(r))
' > "$OUT/rust-licenses.csv" && echo "Wrote $OUT/rust-licenses.csv ($(($(wc -l < "$OUT/rust-licenses.csv")-1)) crates)"
    echo "UNKNOWN licenses:"; grep ',UNKNOWN$' "$OUT/rust-licenses.csv" || echo "  none"
    echo "Still separate and manual: npm dependency licenses, fonts, logos/icons, bundled model files." ;;
  tag)
    V="${2:?usage: tag vX.Y.Z --confirm}"
    [ "${3:-}" = "--confirm" ] || die "refusing to tag without --confirm"
    cd "$HLNA_REPO" || exit 1
    git diff --quiet && git diff --cached --quiet || die "working tree not clean; commit reviewed changes first"
    git tag -a "$V" -m "HLNA $V" && echo "Created local tag $V. Not pushed. Push with: git push origin $V" ;;
  *) die "usage: $0 notes|checksums|licenses|tag <v> --confirm" ;;
esac
