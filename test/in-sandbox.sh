#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/test/lib.sh"

: "${DOTFILES_TEST_TIMEOUT_SECONDS:=900}"

mkdir -p "${TEST_DIR}"

SANDBOX_DIR="$(create_sandbox_dir)"
export DOTFILES_SANDBOX="$SANDBOX_DIR"
export DOTFILES_TEST_LIB="${TEST_DIR}/lib.sh"
export DOTFILES_TEST_LOG_DIR="${SANDBOX_DIR}/test-logs"
export HOME="$SANDBOX_DIR"
export ZDOTDIR="$HOME"

mkdir -p "$DOTFILES_TEST_LOG_DIR"

info "Sandbox: ${SANDBOX_DIR}"
info "Installing dotfiles into sandbox"

git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Not a git repository: $ROOT_DIR"

DOTFILES_REPO_URL="file://${ROOT_DIR}" DOTFILES_NO_EXEC_ZSH=1 bash "$ROOT_DIR/bin/setup-dotfiles.sh"

shopt -s nullglob
tests=("$TESTS_DIR"/*.sh)
shopt -u nullglob

if [ ${#tests[@]} -eq 0 ]; then
  die "No tests found in $TESTS_DIR"
fi

info "Sandbox retained at ${SANDBOX_DIR}"
