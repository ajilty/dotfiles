#!/usr/bin/env zsh
# Shared helpers for zsh-prompt rendering tests.
#
# Why script(1) and not zpty: zsh's zpty builtin allocates a pseudo-terminal
# but in some constrained environments (containers without full session-leader
# semantics) the inner zsh sees enough of a tty to start but not enough for
# p10k's worker startup. Symptom: the inner zsh degrades to a bare `vm#`
# prompt instead of full p10k. util-linux `script` (preinstalled on every
# Ubuntu/Debian) gives a fuller PTY allocation and `setopt monitor` works
# under it -- which is what gitstatusd needs. Trade-off: macOS BSD `script`
# has different CLI syntax (`-q FILE COMMAND...` vs Linux `-qec COMMAND
# FILE`), papered over with a small shim below.
#
# Why we feed commands via stdin (heredoc) and not `zsh -i -c '...'`: the
# `-c` form makes zsh treat the argument as a single command-string and exit
# without entering the prompt loop -- so no prompt is ever drawn. Interactive
# zsh with stdin redirected from a heredoc reads commands one per line,
# drawing a fresh prompt between each, which is what we want to capture.
# zsh-autocomplete may eat the first character of our typed commands (e.g.
# "exit" → "xit"), which is harmless: we only care about the *prompt*, not
# whether the typed commands execute cleanly.

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

# Run interactive zsh under script(1) and capture its output. The inner
# zsh's stdin gets a small command sequence: optionally cd to a fixture
# dir, sleep long enough for p10k to draw the steady-state prompt, then
# exit. Anything written to the pty during that window -- including the
# rendered prompt -- is captured.
#
# Usage: script_capture <pre-shell-cmd> [<timeout-seconds>] [<sleep-for-seconds>]
#   <pre-shell-cmd>      Shell command run as the FIRST stdin line of the
#                        inner zsh (e.g. "cd /tmp/fixture"). Pass "" to
#                        skip and start from the inherited cwd.
#   <timeout-seconds>    Hard wall-clock budget (default 30).
#   <sleep-for-seconds>  How long the inner zsh sleeps before exiting.
#                        The final prompt drawn during this window is what
#                        we capture (default 8).
#
# stdout: the raw byte stream from the pty (ANSI included).
script_capture() {
  local pre_cmd="${1:-}"
  local timeout="${2:-30}"
  local sleep_for="${3:-8}"

  if ! command -v script >/dev/null 2>&1; then
    print -u2 "script_capture: script(1) not installed"
    return 1
  fi

  # Build the stdin command sequence for the inner zsh. Each line is a
  # separate command, drawing a fresh prompt between them.
  local stdin_script=""
  [[ -n "$pre_cmd" ]] && stdin_script+="$pre_cmd"$'\n'
  stdin_script+="sleep $sleep_for"$'\n'
  stdin_script+="exit"$'\n'

  # Linux util-linux vs BSD script have different CLI shapes. Same outcome.
  if script --version 2>&1 | grep -q util-linux; then
    print -rn -- "$stdin_script" | timeout "$timeout" \
      script -qec 'zsh -i' /dev/null 2>&1
  else
    print -rn -- "$stdin_script" | timeout "$timeout" \
      script -q /dev/null zsh -i 2>&1
  fi
}
