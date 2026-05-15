#!/usr/bin/env zsh
# Shared helpers for zsh-prompt rendering tests.
#
# Why zpty: the zsh/zpty module is built into zsh itself, so any machine that
# can run these tests already has it. No extra apt/brew install, identical
# behavior on Linux and macOS, no `script`/`expect` flag-portability shims.
# That's the whole reason we don't capture via `script -qec`.

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

# Drive an interactive zsh inside a zpty, send a setup command, and capture
# everything up to a unique sentinel marker. The sentinel is what tells us
# the prompt has actually drawn (and zinit/p10k have finished any deferred
# loads triggered by the first prompt).
#
# Usage: zpty_capture <setup-cmd> [<timeout-seconds>]
#   <setup-cmd>        Run inside the inner zsh before the sentinel (e.g. cd).
#   <timeout-seconds>  Wall-clock budget (default 20).
#
# stdout: the raw byte stream from the pty (ANSI included).
# stderr: diagnostics.
zpty_capture() {
  local setup="${1:-}"
  local timeout="${2:-20}"
  local sentinel="__DOTFILES_PROMPT_SENTINEL_$$_${RANDOM}__"
  local output="" chunk="" deadline
  deadline=$(( SECONDS + timeout ))

  if ! zmodload zsh/zpty 2>/dev/null; then
    print -u2 "zpty_capture: zsh/zpty module unavailable"
    return 1
  fi

  if ! zpty -b SHELL "zsh -i" 2>/dev/null; then
    print -u2 "zpty_capture: failed to spawn inner zsh"
    return 1
  fi

  # Let the prompt draw at least once before we send anything. p10k's instant
  # prompt and the deferred-loaded full prompt race; without a brief drain
  # the sentinel echo can interleave with prompt output and confuse readers.
  local primer_deadline=$(( SECONDS + 5 ))
  while (( SECONDS < primer_deadline )); do
    chunk=""
    if zpty -r -t SHELL chunk 2>/dev/null; then
      output+="$chunk"
    else
      sleep 0.2
      # Stop priming once output has stabilized.
      local before="$output"
      chunk=""
      zpty -r -t SHELL chunk 2>/dev/null && output+="$chunk"
      [[ "$output" == "$before" ]] && break
    fi
  done

  [[ -n "$setup" ]] && zpty -w SHELL "$setup"
  zpty -w SHELL "print -- $sentinel"

  while (( SECONDS < deadline )); do
    chunk=""
    if zpty -r -t SHELL chunk 2>/dev/null; then
      output+="$chunk"
      [[ "$output" == *"$sentinel"* ]] && break
    else
      sleep 0.1
    fi
  done

  zpty -d SHELL 2>/dev/null

  print -r -- "$output"
}
