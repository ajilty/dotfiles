#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/test/lib.sh"

export DOTFILES_TEST_LIB="${DOTFILES_TEST_LIB:-${TEST_DIR}/lib.sh}"
export DOTFILES_TEST_LOG_DIR="${DOTFILES_TEST_LOG_DIR:-${HOME}/test-logs}"

mkdir -p "$DOTFILES_TEST_LOG_DIR"

shopt -s nullglob
tests=("$TESTS_DIR"/*.sh)
shopt -u nullglob

if [ ${#tests[@]} -eq 0 ]; then
  die "No tests found in $TESTS_DIR"
fi

failures=()
# Per-test status files live in $LOG_DIR/status/ so the workflow can build
# a summary table for the PR comment. Each file is one of: pass | fail.
status_dir="$DOTFILES_TEST_LOG_DIR/status"
mkdir -p "$status_dir"

for test_script in "${tests[@]}"; do
  name="$(basename "$test_script")"
  info "Running $name"
  if bash "$test_script"; then
    echo "pass" > "$status_dir/$name"
  else
    echo "fail" > "$status_dir/$name"
    echo "Test $name failed" >&2
    failures+=("$name")
  fi
done

if [ ${#failures[@]} -ne 0 ]; then
  die "Some tests failed: ${failures[*]}"
fi
info "All tests passed"
