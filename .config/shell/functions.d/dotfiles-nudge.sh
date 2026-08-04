#!/bin/bash
# dotfiles-nudge: one-line drift warning at the first prompt of a new
# interactive shell when the dotfiles repo is out of sync with its remote.
#
# Startup cost is a single cache-file read: the real work (throttled fetch
# plus ahead/behind/uncommitted counts) happens in `dotfiles sync-status`,
# spawned here as a detached background job for the NEXT shell. The nudge
# is therefore at most one shell stale and never blocks the prompt.
#
# Non-interactive shells, non-TTY contexts (scripts, CI, command
# substitution), and dumb terminals bail before defining anything, so
# scripting is unaffected.

case "$-" in *i*) ;; *) return ;; esac
[ -t 2 ] || return
[ "${TERM:-}" != "dumb" ] || return
[ -d "$HOME/.dotfiles" ] || return
command -v dotfiles >/dev/null 2>&1 || return

_dotfiles_nudge() {
  local cache="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/sync-nudge"
  # stderr so a nudge can never leak into captured stdout.
  [ -s "$cache" ] && printf '\033[33m%s\033[0m\n' "$(cat "$cache")" >&2
  # Refresh for the next shell; subshell backgrounding detaches without
  # job-control noise in either bash or zsh.
  ( dotfiles sync-status >/dev/null 2>&1 </dev/null & )
  return 0
}

if [ -n "${ZSH_VERSION:-}" ]; then
  # .zshrc sources this file (via .profile) while p10k's instant prompt is
  # active, and direct output there trips its console-output warning.
  # Defer to a self-removing precmd so the nudge prints above the first
  # real prompt instead.
  autoload -Uz add-zsh-hook
  _dotfiles_nudge_once() {
    add-zsh-hook -d precmd _dotfiles_nudge_once
    _dotfiles_nudge
  }
  add-zsh-hook precmd _dotfiles_nudge_once
else
  _dotfiles_nudge
fi
