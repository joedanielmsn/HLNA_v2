#!/usr/bin/env bash
# Day 2: read-only security/identity audit of foundation/jan. Changes nothing.
# It finds candidates for review; a hit is not proof of a bug and no hit is not proof of safety.
# Report is written to claude/logs/audit-<time>.txt
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/00_common.sh"
guard_paths
[ -d "$JAN_DIR/src-tauri" ] || die "Missing $JAN_DIR/src-tauri"

mkdir -p "$LOG_DIR"
REPORT="$LOG_DIR/audit-$(date +%Y%m%d-%H%M%S).txt"
cd "$JAN_DIR" || exit 1

EXCL=(--exclude-dir=node_modules --exclude-dir=target --exclude-dir=.git --exclude-dir=dist --exclude-dir=build)
TOTAL=0
scan() { # label, regex, path...
  local label="$1" re="$2"; shift 2
  local out; out="$(grep -rnIE "${EXCL[@]}" -e "$re" "$@" 2>/dev/null | grep -v '\.hlna-backup' | head -40)"
  local n; n="$(printf '%s' "$out" | grep -c . || true)"
  { echo; echo "## $label  [$n hit(s), max 40 shown]"; [ -n "$out" ] && echo "$out"; } | tee -a "$REPORT"
  TOTAL=$((TOTAL + n))
}

{ echo "HLNA security audit  $(date -Is)"; echo "tree: $JAN_DIR"; } | tee "$REPORT"

CONF=$(ls src-tauri/tauri*.conf.json 2>/dev/null)
CAPS="src-tauri/capabilities"

echo -e "\n######## A. Tauri capabilities (least privilege)" | tee -a "$REPORT"
scan "Wildcard filesystem scopes"      '"(path|\$[A-Z]+/)?\*\*"|\$(HOME|APPDATA|APPDATA|DOCUMENT|DOWNLOAD|DESKTOP)[A-Za-z]*/\*\*|"/\*\*"' $CAPS $CONF
scan "Broad network URL scopes"        '"https?://\*|https?://\*\*|"url": *"\*' $CAPS $CONF
scan "Shell spawn/execute/open"        'shell:(allow-)?(spawn|execute|open|kill)|"cmd":|opener:' $CAPS
scan "Window/webview wildcards"        '"(windows|webviews)": *\[ *"\*"' $CAPS
scan "fs:* permissions"                '"fs:(allow|default|scope)' $CAPS
scan "Plugins granted by default"      '"(core|dialog|fs|http|opener|shell|os|process|updater|deep-link|store|log|clipboard-manager|notification)[:a-z-]*"' $CAPS

echo -e "\n######## B. Updater / telemetry / publisher leftovers" | tee -a "$REPORT"
scan "Updater config or keys"          'pubkey|"endpoints"|createUpdaterArtifacts|tauri-plugin-updater|updater:' $CONF $CAPS src-tauri/src src-tauri/Cargo.toml
scan "Publisher metadata"              '"publisher"' $CONF
scan "PostHog / analytics endpoints"   'posthog|app\.posthog|us\.i\.posthog|eu\.i\.posthog|analytics' $CONF src-tauri/src web-app/src --include=*.json --include=*.rs --include=*.ts --include=*.tsx
scan "Jan-branded hosts"               'jan\.ai|janhq\.|api\.jan|catalog\.jan|github\.com/janhq' $CONF src-tauri/src web-app/src

echo -e "\n######## C. Data isolation" | tee -a "$REPORT"
scan "Old JAN_* env vars"              'JAN_DATA_ROOT|JAN_DATA_FOLDER|JAN_[A-Z_]*FOLDER' src-tauri/src web-app/src tests e2e 2>/dev/null
scan "Hard-coded Jan data dirs"        '"Jan"|"jan"|\.local/share/[Jj]an|\.config/[Jj]an|/jan/data|~/jan' src-tauri/src
scan "Default data folder"             'data_folder' src-tauri/src

echo -e "\n######## D. Tool / MCP permission defaults" | tee -a "$REPORT"
scan "Allow-all defaults"              'allow_all\(\)|PermissionDefault::Allow|Default::default\(\).*allow' src-tauri/src
scan "Auto-approve / skip prompts"     'auto[_-]?approve|skip[_-]?permission|dangerously|yolo|no[_-]?confirm|always[_-]?allow' src-tauri/src src crates cli tui 2>/dev/null
scan "Shell confinement toggles"       'sandbox|confine|landlock|seccomp|disable_.*sandbox|workspace_root' src-tauri/src
scan "Local API / server bind"         '0\.0\.0\.0|"::"|bind\(|host *[:=] *"?(0\.0\.0\.0|::)|cors|allow_origin|Any\)' src-tauri/src
scan "MCP server launch (stdio/http)"  'StdioClientTransport|StreamableHttp|sse_|spawn\(|Command::new' src-tauri/src

echo -e "\n######## E. Dynamic code loading" | tee -a "$REPORT"
scan "Native extension loading"        'load_extension|libloading|dlopen|Library::new|sqlite-vec|LD_LIBRARY_PATH' src-tauri src-tauri/plugins 2>/dev/null
scan "Remote asset download at build"  'curl |wget |releases/latest|download-bin|download_bin|latest/download' package.json Makefile scripts src-tauri/build.rs 2>/dev/null
scan "Extension/worker install paths"  'new Worker|importScripts|\.install\(|extensions?/install|manifest' core/src extensions 2>/dev/null

{ echo; echo "======== TOTAL candidate hits: $TOTAL"; echo "Report: $REPORT"; } | tee -a "$REPORT"
cat <<'EOF'

How to use this: send me the report (or the sections you care about) and I will propose
focused patches. Priority order for Day 2: (A) wildcard fs/shell/http, (D) allow-all and
auto-approve, then (B) updater/publisher leftovers.
EOF
