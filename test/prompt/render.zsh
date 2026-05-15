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

# Each fixture builds its sandbox state and emits a single zsh command that,
# when run inside the inner pty zsh, lands us in that state.
work=""
build_fixture() {
  case "$fixture" in
    clean-git)
      work=$(mktemp -d -t dotfiles-prompt-XXXXXX) || return 1
      git init -q -b master "$work/repo" >/dev/null 2>&1 || return 1
      # Identity must be set per-invocation here; the dotfiles repo's
      # pre-commit hook is hooked via includeIf gitdir:~/.dotfiles, which
      # this temp repo isn't, so it doesn't fire. We just need *some*
      # identity for the empty commit to succeed.
      git -C "$work/repo" \
        -c user.email=test@example.com -c user.name=test \
        commit --allow-empty -q -m init || return 1
      print -r -- "cd $work/repo"
      ;;
    home)
      print -r -- 'cd $HOME'
      ;;
    *)
      print -u2 "render.zsh: unknown fixture '$fixture'"
      return 2
      ;;
  esac
}

setup=$(build_fixture) || exit $?

zpty_capture "$setup" 20

# Best-effort cleanup. Failure here doesn't mask render success.
[[ -n "$work" && -d "$work" ]] && rm -rf "$work" 2>/dev/null || true
