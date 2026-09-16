#!/usr/bin/env bash
# Interactive startup must be free of known zinit/compinit warnings.
#
# Why this exists separately from 31-prompt-no-stderr.sh: those warnings do
# NOT go to stderr. zinit's ice diagnostics and compinit's insecure-dirs
# prompt are written to the terminal (the combined PTY stream), so a
# stderr-only grep never sees them -- which is exactly how the `as"snippet"`
# bug (#11) shipped green. Here we capture the full PTY stream the way the
# render test does and assert the bad signatures are absent.
#
# By the time this test runs, the sandbox is already primed (CI warmup plus
# the earlier 3x-prompt tests), so a single steady-state capture is enough.
set -euo pipefail

echo "Testing interactive startup is free of known zinit/compinit warnings"
source "$DOTFILES_TEST_LIB"

if ! command -v zsh >/dev/null 2>&1; then
  die "zsh is not installed"
fi
if ! command -v script >/dev/null 2>&1; then
  die "script (util-linux) is required for PTY-backed zsh tests"
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROMPT_DIR="$ROOT_DIR/test/prompt"
log_dir="${DOTFILES_TEST_LOG_DIR:-$HOME/test-logs}"
mkdir -p "$log_dir"
raw="$log_dir/startup-warnings.txt"

# One PTY-backed interactive startup, ANSI stripped. script_capture sleeps a
# few seconds so zinit's deferred (turbo) plugin loads -- where ice warnings
# are emitted -- land in the captured window.
zsh -c "source '$PROMPT_DIR/lib.zsh'; script_capture '' 40 8 | strip_ansi" \
  >"$raw" 2>/dev/null || true

if [ ! -s "$raw" ]; then
  die "captured empty startup output (PTY capture failed?)"
fi

fail=0

# #11: an `as` ice given an unsupported value (e.g. the old `as"snippet"`).
# zinit emits this once per offending ice during plugin load.
if grep -aiE "as ice received invalid value" "$raw" >/dev/null; then
  warn "zinit reported an invalid 'as' ice value (regression of #11):"
  grep -aiE --color=never "as ice received invalid value" "$raw" >&2 || true
  fail=1
fi

# #12: compinit's interactive insecure-directories prompt. With
# ZINIT[COMPINIT_OPTS]=-i set in .zshrc these dirs are silently ignored; if
# this resurfaces, compinit is no longer running with -i (or the option was
# dropped), which would hang a non-interactive shell waiting on [y/n].
if grep -aiE "insecure directories|compinit: initialization aborted" "$raw" >/dev/null; then
  warn "compinit insecure-directories prompt surfaced on startup (regression of #12):"
  grep -aiE --color=never "insecure directories|compinit: initialization aborted" "$raw" >&2 || true
  fail=1
fi

if [ "$fail" -ne 0 ]; then
  die "interactive startup emitted known-bad warnings (see $raw)"
fi

info "no known zinit/compinit warnings on interactive startup"
