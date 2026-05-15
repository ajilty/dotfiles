#!/usr/bin/env bash
# Interactive startup should not produce hard-failure stderr lines.
#
# We do TWO runs: the first primes zinit/p10k (download plugins, build the
# instant-prompt cache, compile completions). The second is steady-state
# and is what we actually assert against. Without priming, CI's first run
# would always be noisy and the test would be useless.
set -euo pipefail

echo "Testing interactive zsh produces no fatal errors"
source "$DOTFILES_TEST_LIB"

if ! command -v zsh >/dev/null 2>&1; then
  die "zsh is not installed"
fi

log_dir="${DOTFILES_TEST_LOG_DIR:-$HOME/test-logs}"
mkdir -p "$log_dir"

prime_log="$log_dir/zsh-startup-prime.log"
steady_log="$log_dir/zsh-startup-steady.log"

info "Priming (downloads plugins, builds caches; may be slow)"
zsh -i -c 'exit' >"$prime_log" 2>&1 || true

info "Steady-state startup"
if ! zsh -i -c 'exit' >/dev/null 2>"$steady_log"; then
  warn "see $steady_log"
  die "interactive zsh failed on steady-state startup"
fi

# Real fatal errors zsh emits are prefixed with `zsh:`. Plugin/zinit
# warnings (e.g. snippet downloads, optional config absences) are not.
# Match only the zsh-prefixed form so we don't false-positive on benign
# zinit `no such file or directory` traces from snippet fetches.
pattern='^zsh: (syntax error|parse error|command not found|undefined function)'
if grep -E -- "$pattern" "$steady_log" >/dev/null; then
  warn "fatal-looking lines in $steady_log:"
  grep -E --color=never -- "$pattern" "$steady_log" >&2 || true
  die "interactive zsh emitted fatal-looking errors on steady-state startup"
fi

info "no fatal errors on interactive startup"
