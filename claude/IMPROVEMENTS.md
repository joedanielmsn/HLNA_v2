# Improvements found while reviewing the HLNA v2 handoff plan

Source: `HLNA_v2_Master_Handoff_Plan.md`. I could not see `foundation/jan` (it is not on the remote `main`),
so these come from the plan and from the scripts, not from reading Jan's code. Verify before acting.

## Fixed in the scripts already
| Issue | Fix |
|---|---|
| `yarn` missing because Node 25+ no longer bundles Corepack | `01_check_env.sh` detects it and prints the Arch fix |
| Smoke test fingerprinted `HLNA_v1`, which the plan forbids entering and which changes legitimately (false FAIL) | Fingerprint now covers real Jan locations only |
| Redirecting `HOME` can break X11 auth | `XAUTHORITY` is preserved |
| Blank/white window is a common WebKitGTK + NVIDIA failure | Optional `HLNA_WEBKIT_WORKAROUND=1` |
| `bc` is not guaranteed on Arch | Replaced with `awk` |

## High value, do soon
1. **Relative default data folder.** The plan says `AppConfiguration::default().data_folder` is `./data`. A relative path
   resolves against the current working directory, so launching from different places can use different (or shared) folders.
   Resolve it against the HLNA app-data dir and reject relative values.
2. **Possible out-of-memory cause for the closed terminal.** Linking a big Tauri/Rust release build can use most of 14 GiB.
   Check `journalctl -k -b -1 | grep -i -E 'oom|killed process'`. If so, build with `CARGO_BUILD_JOBS=6`.
   Faster linking on CachyOS: install `mold` and `clang`, set `RUSTFLAGS="-C link-arg=-fuse-ld=mold"` (test it; not verified here).
3. **Capabilities.** Replace wildcard fs/http scopes with explicit ones: app data dir, user-attached folders,
   and `http://127.0.0.1:11434` plus user-added endpoints. Drop `shell:allow-spawn`/`open` unless a feature needs it.
   Use `05_security_audit.sh` to list the current hits.
4. **First-release scope cut.** Ship with the local API server and MCP tool calls disabled by default. The broker is a
   library that is not wired in yet; do not describe tool calls as brokered until they are.
5. **Pin sqlite-vec** with `07_pin_sqlite_vec.sh` (checksum verified by you against the release page).

## Permission broker (`claude/broker`)
- 16 unit tests pass: scope containment (`proj` vs `proj-evil`), symlink escape, dangling symlinks, `..`, protected roots,
  expiry, one-shot grants, high-risk/delete need one-shot, ask-every-time, emergency stop, revoke, redaction.
- Integration plan: add as a path dependency in `src-tauri/Cargo.toml`; construct one `Broker` in app state; every Tauri command
  and MCP tool call builds a `Request` and calls `evaluate`. Derive `component` from the MCP server registry entry, never from
  model or plugin text.
- Known gaps: check-time path resolution has a TOCTOU window. Close it at the I/O layer with `cap-std` or Landlock
  (both already in the plan's research list). Grants are in-memory only; persistence and a Cedar policy layer are later work.

## Ollama on 4 GB VRAM (optional, test each)
Set via a systemd drop-in (`sudo systemctl edit ollama`):
`OLLAMA_MAX_LOADED_MODELS=1`, `OLLAMA_NUM_PARALLEL=1`, `OLLAMA_KEEP_ALIVE=5m`.
For more headroom at 16K, try `OLLAMA_FLASH_ATTENTION=1` and `OLLAMA_KV_CACHE_TYPE=q8_0`, then rerun `06_core_check.sh`.
This matches the plan's "no concurrent models by default" rule.

## Process
- Commit `Cargo.lock` and the Yarn lockfile, keep `yarn install --immutable`, and add a `rust-toolchain.toml` so builds are repeatable.
- Add CI (`claude/ci/hlna-ci.yml`, untested): broker tests, `git diff --check`, and the audit script on every push.
- Never `git add .` here: `.hlna-backup`, `target/`, and logs exist in the tree. `04_final_checks.sh` flags them.
- Keep this folder small and reviewable; do not let scripts grow into a second build system.

## Still unverified (do not claim)
Current HLNA build, smoke test, packaged sqlite-vec loading, every script in this folder on your machine.
