# claude/ - HLNA v2 scripts for the 5-day plan

Everything here was written without access to your machine or to `foundation/jan`.
**Syntax-checked and, where noted, unit-tested in a sandbox; none of the scripts has been run against your real tree.**
Run them in your own terminal from the repo root.

| Day | Script | What it does | Changes files? |
|---|---|---|---|
| 1 | `01_check_env.sh` | find yarn/corepack, leftover builds, tool versions | no |
| 1 | `02_build.sh` | `build:web` + `tauri build --no-bundle`, logged | build output only |
| 1 | `03_smoke_test.sh` | run HLNA-Desktop in a disposable profile, Jan fingerprint before/after | profile dir only |
| 1 | `04_final_checks.sh` | `git diff --check`, status, files not to commit | no |
| 2 | `05_security_audit.sh` | grep-based audit: capabilities, updater/publisher, data isolation, permission defaults | writes a report |
| 2 | `broker/` | tested Rust permission-broker core (16 tests) | no |
| 3 | `06_core_check.sh` | Ollama reachable, model present, streaming at 16K, GPU placement, unload | unloads the model |
| 4 | `07_pin_sqlite_vec.sh` | pinned, checksum-verified sqlite-vec install | writes `sqlite-vec.so` |
| 4 | `08_package_check.sh` | build/inspect a .deb: identity, resource layout, leftover strings | build output only |
| 4-5 | `09_acceptance.sh` | automated subset of the acceptance criteria + manual list | no |
| 5 | `10_release.sh` | release notes draft, checksums, licenses, local tag (`--confirm`) | writes `release/` |
| any | `run_all.sh dayN` | run a day's scripts in order, stop on first failure | as above |

See `IMPROVEMENTS.md` for findings and what is still unverified.

## Safety properties
- Never enters `HLNA_v1`; scripts abort if the path contains it. No `yarn install`, no `cargo fmt`, no package installs, no pushes.
- The smoke test redirects `HOME`, all `XDG_*`, `HLNA_DATA_ROOT` and `HLNA_DATA_FOLDER` into `~/.hlna-smoke-profile`.
- Tagging requires `--confirm` and a clean tree and never pushes.

## Overrides
`HLNA_REPO`, `HLNA_TEST_PROFILE`, `MODEL`, `OLLAMA`, `NUM_CTX`, `SQLITE_VEC_DEST`, `HLNA_WEBKIT_WORKAROUND=1`.
