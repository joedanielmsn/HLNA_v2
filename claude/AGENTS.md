# AGENTS.md - read this first (entry point for any AI agent working on HLNA v2)

You are continuing work on **HLNA v2** (Tauri 2 + Rust + React/TS, based on a pinned import of Jan).
Do not guess. Do not re-discover. Read these in order, then act:

1. `claude/AGENTS.md` (this file: rules)
2. `claude/PROGRESS_AND_RUNBOOK.md` (current state, the exact next command, what to do when it fails)
3. `claude/BACKLOG.md` (remaining work by day, each task with how to verify it)
4. `HLNA_v2_Master_Handoff_Plan.md` (long-term vision and binding decisions; only if you need background)

## Hard rules (violating any of these is a failure)
1. **Never touch `~/Project_Assistant/HLNA_v1`** or real Jan data. Do not `cd` there, read it, or copy from it.
2. **Never claim something worked unless the user pasted output proving it** (or you ran it and saw the output).
   Say "not verified" instead. A build/test that was not run is not passing.
3. **One copyable command block at a time.** Ask the user to paste the output. Wait for it.
4. **No broad scans, no repeated audits, no rewriting upstream code for style.** Inspect the smallest area that answers the question.
5. **Never run `cargo fmt` on the repo, never `git add .`, never `git clean`, `git reset --hard`, or `rm -rf` on anything in the repo.**
   Stage explicit paths only. Do not delete `*.hlna-backup` files.
6. **No commit or push without showing the user the exact staged file list and getting a yes.**
7. **Do not weaken security to hit a date.** If a feature cannot be made safe in time, disable or defer it and write that in the release notes.
8. Do not re-enable the Jan updater, analytics (PostHog), or Jan endpoints/keys.
9. Keep upstream attribution and licenses.
10. Do not print or log secrets. Ask before running anything that needs `sudo`.

## How to make a code change (follow exactly)
1. State the one problem you are fixing and the file(s) you expect to touch.
2. Look only at those files (`grep -n` for the symbol, then read ~60 lines around it).
3. Make the smallest edit. Prefer a unified diff the user applies with `git apply <<'EOF' ... EOF`.
4. Run only the check that covers that change (see the BACKLOG task's "Verify").
5. Show `git diff --stat` and the diff. Do not commit until the user approves.
6. Update the status table in `PROGRESS_AND_RUNBOOK.md` with what is now verified and the evidence.

## User's environment (verified from pasted output unless marked)
CachyOS (Arch). RTX 3050 4 GB. ~14 GiB RAM. Node v26.13.1, npm 12.2.3, Rust/Cargo 1.100.0 (was 1.98.0 earlier), Git 2.56.1,
CMake 4.5.1, Corepack 0.36.0, Yarn 4.5.3 (via `~/.local/bin`, in `~/.bashrc` PATH). Ollama runs as a system service.
Model store `/var/lib/ollama/models`. Do not delete or overwrite models.

## Style for talking to the user
Short. Plain. One block of commands. Say exactly what output to paste back. Be honest about uncertainty.
