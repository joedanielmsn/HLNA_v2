# HLNA v2 backlog (ordered). Each task: what, where to look, how to verify.

Rule of thumb: if a task cannot be finished safely by 2026-11-28, disable the feature and document the limitation. Do not weaken security.

## Day 1 - finish (see PROGRESS_AND_RUNBOOK.md)
- [ ] Build passes (`CARGO_BUILD_JOBS=6 bash claude/02_build.sh`)
- [ ] Smoke test passes (`bash claude/03_smoke_test.sh`), including "real Jan locations unchanged"
- [ ] `bash claude/04_final_checks.sh` clean; changes committed with explicit paths
- [ ] Remove the inherited Jan `publisher` from the Tauri config (do not invent a new publisher). Verify: `grep -n publisher foundation/jan/src-tauri/tauri*.conf.json` returns nothing

## Day 2 - security and permissions
Start: `bash claude/05_security_audit.sh`, then work through its hits in this order.
- [ ] **Capabilities minimization** (`foundation/jan/src-tauri/capabilities/*.json`). Replace `**` fs scopes, `https://*` http scopes, `windows: ["*"]` with explicit values: app data dir, user-attached folders, `http://127.0.0.1:11434` plus user-added endpoints. Remove `shell:allow-spawn` / `open` unless a shipped feature needs it. Verify: rerun audit sections A; app still starts and chats (smoke test).
- [ ] **Permission defaults.** Inspect `ToolPermissions::default()` / `allow_all()` / `PermissionDefault::Allow` call paths (do not assume). Make default = deny/ask. Verify: add a unit test that the default denies an unknown tool, `cargo test` for that crate only.
- [ ] **CLI/TUI auto-approve and shell confinement**: ensure not reachable from the shipped desktop app, or default to prompting. Verify with audit section D.
- [ ] **Local API server and MCP tool calls: disabled by default** for the first release. Verify: fresh profile has nothing listening (`ss -ltnp | grep HLNA`) after launch.
- [ ] **Data folder default**: `AppConfiguration::default().data_folder` is `./data` (relative to the working directory). Resolve against the HLNA app-data dir, reject relative values, and confirm GUI and any CLI/headless start-up use it. Verify: launch from `/tmp` and from the repo; both use the same data location.
- [ ] **Wire the broker** (`claude/broker`, 16 tests): add as a path dependency in `src-tauri/Cargo.toml`, create one `Broker` in app state, route each Tauri command / MCP tool call that touches files, shell, or network through `Broker::evaluate`. `component` must come from the host (MCP server registry), never from model/plugin text. Start with the file-reading tool only; do not try to do everything. Verify: unit test that an un-granted call returns Ask, and manual test of one prompt.
- [ ] Emergency stop button/command calls `Broker::emergency_stop`. Verify manually.

## Day 3 - core product
- [ ] `bash claude/06_core_check.sh` passes (Ollama up, `assistant-qwen-16k:latest` streams at 16384 ctx, 100% GPU, closed port fails fast, unload works).
- [ ] In the app: add Ollama provider `http://127.0.0.1:11434`; pick model; stream; stop/cancel; regenerate; copy; history persists across restart.
- [ ] Context length setting: default 16384, range 4096-16384, persists. Look for where Jan stores per-model `ctx_len`/`num_ctx`.
- [ ] Clear error when Ollama is unreachable (stop the service briefly: `systemctl stop ollama`, confirm a readable error, restart it).
- [ ] Logs do not contain prompts/secrets (grep the app log dir in the test profile after a chat).
- [ ] Optional Ollama tuning for 4 GB VRAM (systemd drop-in): `OLLAMA_MAX_LOADED_MODELS=1`, `OLLAMA_NUM_PARALLEL=1`, `OLLAMA_KEEP_ALIVE=5m`; try `OLLAMA_FLASH_ATTENTION=1`, `OLLAMA_KV_CACHE_TYPE=q8_0`; rerun 06.

## Day 4 - packaging and release candidate
- [ ] Pin sqlite-vec: `bash claude/07_pin_sqlite_vec.sh --print <version>`, user compares SHA-256 with the release page, saves `claude/pins/sqlite-vec.pin`, then `--install`. The asset name/member (`vec0.so`) in that script is from memory; verify. Replace any floating "latest" download in the repo's download script.
- [ ] `bash claude/08_package_check.sh --build` (builds a .deb) and inspect: no Jan names, `.desktop` entry correct, sqlite-vec at `resources/bin/sqlite-vec.so` or cleanly absent.
- [ ] Verify the app starts with sqlite-vec absent (optional component).
- [ ] `bash claude/09_acceptance.sh`
- [ ] Draft release notes: `bash claude/10_release.sh notes`; fill with only verified facts.
- [ ] License/provenance review: `bash claude/10_release.sh licenses` (Rust); npm licenses, fonts, logos/icons, bundled assets are separate manual checks.

## Day 5 - verify and release
- [ ] Install the package in a disposable profile; launch; chat; restart.
- [ ] Backup/restore sanity: copy the HLNA data folder, wipe, restore, confirm chats return.
- [ ] `bash claude/10_release.sh checksums`
- [ ] Tag only with user approval: `bash claude/10_release.sh tag vX.Y.Z --confirm` (local tag, never pushes).
- [ ] Release notes list: included, verified (with evidence), deferred, known limitations. Never say "fully secure" or "production hardened".

## Improvements that make the project better (after the first release unless noted)
1. **Reproducible builds**: commit `Cargo.lock`/Yarn lockfile (check they are), add `rust-toolchain.toml` (Rust floated from 1.98 to 1.100 between sessions) and `.nvmrc`/`engines`. Decide the toolchain pin with the user.
2. **CI**: copy `claude/ci/hlna-ci.yml` to `.github/workflows/` (untested). Runs broker tests, script syntax, audit report.
3. **Faster local builds**: `mold` + `clang`, `sccache`; keep `CARGO_BUILD_JOBS` set to avoid OOM. Test before recommending.
4. **Close the path check-use gap** in the broker with `cap-std` or Landlock at the actual file-open layer (the broker only checks at decision time).
5. **Persist grants and audit log** (encrypted at rest, per-project), expose a "Permissions" settings page (view, revoke, expiry), then evaluate Cedar for policy.
6. **Resource manager** (post-release): one loaded model at a time, queue, unload on idle/gaming mode.
7. **Update strategy**: manual updates for now; later a signed channel with HLNA-owned keys. Never reuse Jan keys.
8. **Remove dead legacy code** (PostHog types/unused modules) in one focused commit after release, not before.
9. **Docs**: keep `PROGRESS_AND_RUNBOOK.md` current after every verified step; it is what lets a cheaper agent continue safely.
10. **Rename leftovers**: only user-visible or isolation-relevant `jan` strings. No blind global rename.
