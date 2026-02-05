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

for test_script in "${tests[@]}"; do
  info "Running $(basename "$test_script")"
  if ! bash "$test_script"; then
    echo "Test $(basename "$test_script") failed" >&2
    failures+=("$(basename "$test_script")")
  fi
done

if [ ${#failures[@]} -ne 0 ]; then
  die "Some tests failed: ${failures[*]}"
fi
info "All tests passed"
