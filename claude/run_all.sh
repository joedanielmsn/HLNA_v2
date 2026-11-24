#!/usr/bin/env bash
# Run a day's scripts in order; stop at the first failure.
#   bash claude/run_all.sh day1|day2|day3|day4|day5
# day1 pauses before the interactive smoke test. Nothing here commits or pushes.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
run() { echo; echo "################ $*"; bash "$DIR/$@" || { echo "STOPPED: $1 failed"; exit 1; }; }
pause() { read -r -p "$1 [Enter to continue, Ctrl-C to stop] " _; }

case "${1:-}" in
  day1) run 01_check_env.sh; run 02_build.sh; pause "Next: interactive smoke test."; run 03_smoke_test.sh; run 04_final_checks.sh ;;
  day2) run 05_security_audit.sh; cargo test --offline --manifest-path "$DIR/broker/Cargo.toml" ;;
  day3) run 06_core_check.sh ;;
  day4) run 07_pin_sqlite_vec.sh --install; run 08_package_check.sh --build; run 09_acceptance.sh ;;
  day5) run 09_acceptance.sh; run 10_release.sh licenses; run 10_release.sh checksums; run 10_release.sh notes ;;
  *) echo "usage: $0 day1|day2|day3|day4|day5"; exit 2 ;;
esac
