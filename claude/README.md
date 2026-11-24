# claude/ - HLNA v2 Day 1 scripts

Scripts to finish Day 1 from `HLNA_v2_Master_Handoff_Plan.md`: fix the missing
`yarn`, build the current HLNA changes, run an isolated smoke test, and review the diff.

**Status:** written but not run. They were written without access to your machine,
so none of these has been executed or tested. Run them in your own terminal.

## Usage

Run from your local checkout, on branch `work/hlna-identity-isolation`:

```bash
cd ~/Project_Assistant/HLNA_v2
bash claude/01_check_env.sh      # find yarn, check for leftover builds (read-only)
bash claude/02_build.sh          # build:web + tauri build --no-bundle, logged
bash claude/03_smoke_test.sh     # launch HLNA-Desktop in a disposable profile
bash claude/04_final_checks.sh   # git diff --check + changed-file review (read-only)
```

Stop at the first failing step and fix only that blocker.

## Safety properties

- Never enters or touches `HLNA_v1`; scripts abort if the path contains it.
- No `yarn install`, no `cargo fmt`, no package installs, no deletions.
- Smoke test redirects `HOME`, all `XDG_*` dirs, `HLNA_DATA_ROOT` and
  `HLNA_DATA_FOLDER` into `~/.hlna-smoke-profile` and compares a before/after
  fingerprint of known Jan/v1 locations.
- `04_final_checks.sh` only reads; it never stages or commits.

## Overrides

- `HLNA_REPO` - checkout path (default `~/Project_Assistant/HLNA_v2`)
- `HLNA_TEST_PROFILE` - smoke-test profile dir (default `~/.hlna-smoke-profile`)

Build logs go to `claude/logs/` (add to `.gitignore` or leave unstaged).
