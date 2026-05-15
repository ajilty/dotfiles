#!/usr/bin/env zsh
# Shared helpers for zsh-prompt rendering tests.
#
# Why zpty: the zsh/zpty module is built into zsh itself, so any machine that
# can run these tests already has it. No extra apt/brew install, identical
# behavior on Linux and macOS, no `script`/`expect` flag-portability shims.
#
# Why we never write into the spawned zsh's zle (a hard-won lesson):
# zsh-autocomplete is loaded by .zshrc and runs live, intercepting every
# keystroke through zle widgets. Writing "cd /tmp/foo" via `zpty -w` after
# the prompt has drawn produces "d /tmp/foo" -- autocomplete's redraw eats
# the first character. So instead of typing commands, we hand them to the
# spawn line (`cd /tmp/foo && exec zsh -i`) and let the inner zsh start
# already in the right state. No zle interaction needed.

emulate -L zsh

# Strip ANSI escapes / OSC sequences from stdin -> stdout.
# Handles: CSI (\e[...), OSC (\e]...BEL or ST), charset switches, keypad mode,
# bare CRs. perl is preinstalled on every Linux/macOS box we care about.
strip_ansi() {
  perl -pe '
    s/\e\[[0-9;?]*[ -\/]*[@-~]//g;
    s/\e\][^\a\e]*(?:\a|\e\\)//g;
    s/\e[()][AB012]//g;
    s/\e[=>]//g;
    s/\r//g;
  '
}

# Spawn interactive zsh in a zpty and capture its output until it goes
# quiet. "Quiet" means no new bytes for QUIET_FOR seconds -- by then,
# p10k's instant prompt has drawn, zinit's deferred plugins have loaded,
# and async vcs lookups have settled.
#
# Usage: zpty_capture <pre-shell-cmd> [<timeout-seconds>] [<quiet-for-seconds>]
#   <pre-shell-cmd>      Sh command run before `exec zsh -i`. Use this to
#                        place the inner zsh in a fixture dir, set env vars,
#                        etc. Pass "" to spawn zsh from wherever we are.
#   <timeout-seconds>    Hard wall-clock budget (default 25).
#   <quiet-for-seconds>  Idle threshold to declare the prompt "rendered"
#                        (default 3).
#
# stdout: the raw byte stream from the pty (ANSI included).
zpty_capture() {
  local pre_cmd="${1:-}"
  local timeout="${2:-25}"
  local quiet_for="${3:-3}"
  local output="" chunk="" last_at deadline

  if ! zmodload zsh/zpty 2>/dev/null; then
    print -u2 "zpty_capture: zsh/zpty module unavailable"
    return 1
  fi

  local spawn="exec zsh -i"
  [[ -n "$pre_cmd" ]] && spawn="$pre_cmd && exec zsh -i"

  if ! zpty -b SHELL "$spawn" 2>/dev/null; then
    print -u2 "zpty_capture: failed to spawn inner zsh"
    return 1
  fi

  last_at=$SECONDS
  deadline=$(( SECONDS + timeout ))

  while (( SECONDS < deadline )); do
    chunk=""
    if zpty -r -t SHELL chunk 2>/dev/null; then
      output+="$chunk"
      last_at=$SECONDS
    else
      if (( SECONDS - last_at >= quiet_for )); then
        break
      fi
      sleep 0.1
    fi
  done

  zpty -d SHELL 2>/dev/null
  print -r -- "$output"
}
