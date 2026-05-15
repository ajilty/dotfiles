#!/usr/bin/env bash
# Syntax-check every file that contributes to the interactive shell prompt.
# `zsh -n` parses without executing, so this is fast and side-effect-free.
set -euo pipefail

echo "Testing zsh prompt config syntax"

if [ -z "${DOTFILES_TEST_LIB:-}" ]; then
  echo "error: DOTFILES_TEST_LIB is not set" >&2
  exit 1
fi
source "$DOTFILES_TEST_LIB"

if ! command -v zsh >/dev/null 2>&1; then
  die "zsh is not installed"
fi

files=(
  "$HOME/.zshrc"
  "$HOME/.zshenv"
  "$HOME/.profile"
  "$HOME/.p10k.zsh"
)

failures=0
for f in "${files[@]}"; do
  if [ ! -f "$f" ]; then
    warn "missing $f, skipping"
    continue
  fi
  info "zsh -n $f"
  if ! zsh -n "$f" 2>&1; then
    warn "syntax error in $f"
    failures=$((failures + 1))
  fi
done

# Shared shell fragments — these are sourced unconditionally from .profile
# and .zshrc, so a parse error here is a real prompt-time failure.
shopt -s nullglob
shared=("$HOME/.config/shell"/* "$HOME/.config/shell"/*.d/*)
shopt -u nullglob
for f in "${shared[@]}"; do
  [ -f "$f" ] || continue
  case "$f" in *.sample|*.md) continue ;; esac
  info "zsh -n $f"
  if ! zsh -n "$f" 2>&1; then
    warn "syntax error in $f"
    failures=$((failures + 1))
  fi
done

if [ "$failures" -gt 0 ]; then
  die "$failures file(s) failed syntax check"
fi

info "prompt config syntax OK"
