#!/usr/bin/env bash
# Guard against the failure mode where p10k never loads and the prompt is
# stuck on the placeholder literal "Loading..." (see .zshrc near the
# zinit-light powerlevel10k block).
#
# .zshrc deliberately sets PS1="Loading..." before the deferred zinit load
# of romkatv/powerlevel10k so a missing/broken atload hook is loud-ish
# instead of producing an empty prompt. If anything breaks the load chain
# (renamed plugin, bad atload, network failure during zinit install) the
# placeholder is what the user sees -- with no error message. CI is exactly
# where you want this caught.
set -euo pipefail

echo "Testing prompt does not stick on 'Loading...'"
source "$DOTFILES_TEST_LIB"

if ! command -v zsh >/dev/null 2>&1; then
  die "zsh is not installed"
fi
if ! command -v perl >/dev/null 2>&1; then
  die "perl is not installed (needed for ANSI stripping)"
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROMPT_DIR="$ROOT_DIR/test/prompt"
log_dir="${DOTFILES_TEST_LOG_DIR:-$HOME/test-logs}"
mkdir -p "$log_dir"

raw="$log_dir/render-home.raw"
err="$log_dir/render-home.err"

info "Rendering prompt at \$HOME"
if ! zsh "$PROMPT_DIR/render.zsh" home >"$raw" 2>"$err"; then
  warn "see $err"
  die "render.zsh failed"
fi

plain=$(zsh -c "source '$PROMPT_DIR/lib.zsh'; strip_ansi" <"$raw")

# Look at the last non-empty line, which is the active prompt line.
last=$(printf '%s\n' "$plain" | awk 'NF{l=$0} END{print l}')

if printf '%s' "$last" | grep -Fq 'Loading...'; then
  warn "raw output: $raw"
  warn "last non-empty line: $last"
  die "prompt stuck on placeholder 'Loading...' -- p10k did not finish loading"
fi

# Sanity check: we got *some* prompt content. An empty render means the
# zpty capture timed out before anything was drawn.
if [ -z "$plain" ]; then
  warn "see $raw"
  die "render produced no output"
fi

info "prompt advanced past placeholder"
