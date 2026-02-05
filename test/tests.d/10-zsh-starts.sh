#!/usr/bin/env bash
set -euo pipefail

echo "Testing zsh startup"

if [ -z "${DOTFILES_TEST_LIB:-}" ]; then
  echo "error: DOTFILES_TEST_LIB is not set" >&2
  exit 1
fi

source "$DOTFILES_TEST_LIB"

: "${DOTFILES_TEST_TIMEOUT_SECONDS:=900}"

if ! command -v zsh >/dev/null 2>&1; then
  die "zsh is not installed"
fi

log_file="${DOTFILES_TEST_LOG_DIR:-${HOME}/test-logs}/zsh-start.log"
mkdir -p "$(dirname "$log_file")"

info "Starting zsh (this may take a while on first run)"
if ! run_with_timeout "$DOTFILES_TEST_TIMEOUT_SECONDS" "$log_file" zsh -i -c 'echo __DOTFILES_ZSH_OK__'; then
  warn "zsh did not exit cleanly or timed out"
  warn "See log: $log_file"
  die "zsh failed to start"
fi

if ! grep -q "__DOTFILES_ZSH_OK__" "$log_file"; then
  warn "zsh did not reach expected prompt output"
  warn "See log: $log_file"
  die "zsh output check failed"
fi

info "zsh started successfully"
