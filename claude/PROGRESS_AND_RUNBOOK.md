# HLNA v2 - progress and runbook

Last updated: 2026-11-24 ~18:20 IST. Target: usable first desktop release by 2026-11-28.
Repo: `~/Project_Assistant/HLNA_v2`, branch `work/hlna-identity-isolation`, remote `origin` = `joedanielmsn/HLNA_v2`.
Upstream code lives in `foundation/jan` (pinned Jan commit `49a84bdeaebdfc0f36c00f252eb638f516a48432`).

## 1. Status table (update this as things get verified; evidence = pasted output)

| Item | Status | Evidence |
|---|---|---|
| Identity/isolation/privacy source changes (HLNA name, `HLNA-Desktop`, `ai.hlna.desktop`, data dir, no Jan updater, no PostHog) | Applied in source. **Build not yet confirmed.** | Described in handoff plan section 5; no build output yet |
| sqlite-vec loader tests | Verified earlier by user: 17 passed, 0 failed | Handoff plan 5.4 |
| Yarn available | **Verified**: `yarn 4.5.3` via Corepack in `~/.local/bin` | User output 2026-11-24 |
| `claude/` scripts on GitHub (Day 1-5) | **Pushed** by the user; remote branch tip was `942644f` | `git ls-remote` showed it |
| Yarn-hang fix for `01_check_env.sh` / `00_common.sh` | Applied locally by the user via `git apply`, **uncommitted** | `git status` showed both files modified |
| `node_modules` in `foundation/jan` | Was missing (cause unknown). **Reinstalled**: `yarn install --immutable` finished "Done with warnings" in 12s, lockfile unchanged | User output 2026-11-24 |
| Rust `target/` build cache | **Unknown, probably missing** (same cause as node_modules?). Expect a full, slow Rust build | Not checked |
| Current HLNA native build (`yarn build:web` then `yarn tauri build --no-bundle`) | **NOT DONE. This is the Day 1 blocker.** | none |
| Isolated smoke test (`03_smoke_test.sh`) | NOT DONE | none |
| Permission broker core `claude/broker` | 16/16 unit tests pass in the author's sandbox. **Not wired into Jan.** Not yet run on the user's machine | Sandbox only |
| Security audit (`05_security_audit.sh`) | Tested on a fake tree only. **Never run on the real tree** | none |
| Everything in Day 2-5 beyond the above | NOT DONE | none |

### Uncommitted changes in the user's working tree (do NOT discard; review before any commit)
- `claude/00_common.sh`, `claude/01_check_env.sh` (the yarn-hang fix; safe to commit)
- `foundation/jan/e2e/README.md`, `e2e/isolation.ts`, `e2e/launch-guard.ts` (earlier identity/isolation work by a previous agent; review the diff with the user first)

### Known noise (not blockers)
`yarn install` printed peer-dependency warnings (react 19.0.0 vs ^19.2, typescript 5.9.2 vs <5.9.0). These are inherited from upstream and non-fatal.
Three dead-code warnings in the sqlite-vec plugin are known and non-fatal.

## 2. THE NEXT ACTION (do exactly this)

```bash
cd ~/Project_Assistant/HLNA_v2
CARGO_BUILD_JOBS=6 bash claude/02_build.sh
```
- It runs `yarn build:web` then `yarn tauri build --no-bundle` from `foundation/jan` and logs to `claude/logs/build-<time>.log`.
- `CARGO_BUILD_JOBS=6` is a memory-safety cap (an earlier terminal crash may have been out-of-memory). It may be raised later.
- A full Rust release build takes a long time. Tell the user to let it run and to paste the last lines.
- Success = the script prints `Built: .../src-tauri/target/release/HLNA-Desktop`.

## 3. If the build fails: decision tree (fix only the blocker, then rerun the same script)

| Symptom in the log | Likely cause | Action |
|---|---|---|
| `error[E....]` in Rust mentioning a language feature, deprecated API, or new lint-as-error | Rust moved 1.98 to 1.100, or the HLNA edits broke compile | Show the first error only. Check whether the failing file is one HLNA edited (`git log -3 -- <file>`). Fix the smallest thing. Do NOT bump or pin Rust without telling the user |
| `Command ... killed`, `signal: 9`, terminal closes, `out of memory` | OOM during compile/link | `journalctl -k -b | grep -i -E 'oom|killed process'`. Retry with `CARGO_BUILD_JOBS=3` |
| `pkg-config` / `webkit2gtk-4.1` / `libsoup` / `gtk` not found | Missing system libs | `pacman -Q webkit2gtk-4.1 gtk3 libsoup3 librsvg openssl libappindicator-gtk3 xdotool base-devel`. Install what is missing with `sudo pacman -S --needed ...` (ask first) |
| `yarn: command not found` | PATH lost in a new shell | `export PATH="$HOME/.local/bin:$PATH"; hash -r` |
| `node_modules missing` | Dependencies not installed | `cd foundation/jan && yarn install --immutable` |
| `YN0028 lockfile would be modified` | Lockfile drift | STOP. Do not run plain `yarn install`. Show the user the message |
| TypeScript/vite error in `build:web` | HLNA edits to the web app (e.g. removed analytics provider) | Show the first error and the file. Fix narrowly |
| Failure mentions sqlite-vec / `resources/bin` | Tauri resource glob requires a file that is absent | The extension is meant to be optional. Look at `tauri.linux.conf.json` resources; make the entry tolerant of absence or create the dir. Do not download anything unpinned |
| Network error fetching crates | Offline or proxy | Retry; confirm network |

If the terminal closes: first run `pgrep -af 'tauri build|cargo|rustc'` to see if a build is still running. Do not start a second one.

## 4. After the build succeeds (in order, one block at a time)
1. `bash claude/03_smoke_test.sh` (launches `HLNA-Desktop` in `~/.hlna-smoke-profile`; user does the 4-point checklist it prints. If the window is blank: `HLNA_WEBKIT_WORKAROUND=1 bash claude/03_smoke_test.sh`).
2. `bash claude/04_final_checks.sh` (diff check, flags files not to commit).
3. Ask the user whether to commit. Stage explicit paths. Suggested first commit: the two `claude/` script fixes alone. Review the `e2e/*` changes separately.
4. Mark Day 1 complete only if: build OK, smoke test PASS (including "Jan locations unchanged"), diff check clean. Record the evidence in the table above.
5. Then start Day 2 with `bash claude/05_security_audit.sh` and send the report to the agent/user (see `BACKLOG.md`).

## 5. Scripts reference (all in `claude/`)
`01_check_env.sh` env + yarn check (read-only) | `02_build.sh` build | `03_smoke_test.sh` isolated run |
`04_final_checks.sh` git hygiene | `05_security_audit.sh` grep audit, writes `logs/audit-*.txt` | `06_core_check.sh` Ollama 16K check |
`07_pin_sqlite_vec.sh` pinned sqlite-vec | `08_package_check.sh` .deb inspection | `09_acceptance.sh` automated acceptance subset |
`10_release.sh` notes/checksums/licenses/tag | `run_all.sh dayN` | `broker/` Rust crate (`cargo test --offline --manifest-path claude/broker/Cargo.toml`).
All scripts were written without access to the real tree; only syntax-checked (and the audit script exercised on a fake tree). Expect small fixes when they first meet the real tree. Fix the script, do not work around it silently.

## 6. Facts learned this session (so nobody re-learns them)
- Node 25+ no longer bundles Corepack; on Arch it is the `corepack` package. Enable with `corepack enable --install-directory ~/.local/bin`.
- `yarn --version` outside a pinned project makes Corepack ask to download Yarn; if its output is captured the prompt is invisible and the command appears to hang. Always run Yarn from `foundation/jan` with `COREPACK_ENABLE_DOWNLOAD_PROMPT=0 ... </dev/null`.
- The remote `main` branch contains only planning docs; the code is on `work/hlna-identity-isolation` (and its parent `integration/jan-foundation` locally).
- The AI assistant used earlier could not push to GitHub (Claude GitHub App not installed for this account). The user pushes from their own terminal.
- `.hlna-backup` files exist in the tree on purpose; never delete them until the user approves.
