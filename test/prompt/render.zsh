#!/usr/bin/env zsh
# Render the zsh prompt for a named fixture. Output (stdout) is the raw
# byte stream produced by the inner zsh, ANSI escapes included. The caller
# is expected to strip ANSI when comparing or displaying.
#
# Usage: render.zsh <fixture>
#
# Fixtures:
#   clean-git   freshly-initialized repo with one empty commit on `master`
#   home        $HOME (no setup); useful for the not-stuck-on-Loading check

set -e
emulate -L zsh

SCRIPT_DIR="${0:A:h}"
source "$SCRIPT_DIR/lib.zsh"

fixture="${1:?fixture name required}"

# Build each fixture's state, then echo the sh command that, when
# prepended to `exec zsh -i`, lands the inner zsh in that state.
work=""
case "$fixture" in
  clean-git)
    work=$(mktemp -d -t dotfiles-prompt-XXXXXX) || exit 1
    git init -q -b master "$work/repo" >/dev/null 2>&1 || exit 1
    # Identity must be set per-invocation: the bare dotfiles repo's
    # pre-commit identity hook is hooked via `includeIf gitdir:~/.dotfiles`,
    # which this temp repo isn't, so it doesn't fire. We just need *some*
    # identity for the empty commit to succeed.
    git -C "$work/repo" \
      -c user.email=test@example.com -c user.name=test \
      commit --allow-empty -q -m init || exit 1
    pre_cmd="cd $work/repo"
    ;;
  home)
    pre_cmd='cd "$HOME"'
    ;;
  *)
    print -u2 "render.zsh: unknown fixture '$fixture'"
    exit 2
    ;;
esac

script_capture "$pre_cmd" 30 8

# Best-effort cleanup. Failure here doesn't mask render success.
[[ -n "$work" && -d "$work" ]] && rm -rf "$work" 2>/dev/null || true
