#!/usr/bin/env bash
# Assemble the final PR-comment markdown from the test artifacts.
# Output goes to stdout; the workflow redirects it into a file the
# sticky-comment action posts.
#
# Inputs (env vars):
#   DOTFILES_TEST_LOG_DIR  Where the test suite wrote logs + status/.
#   DOTFILES_TEST_BASE_MS  Optional. Base-branch startup median in ms; if
#                          set, the comment shows a delta.
#
# Inputs (positional):
#   $1                     Path to the existing prompt-report.md (the
#                          render details). Will be embedded into the
#                          comment under <details>.
set -uo pipefail

LOG_DIR="${DOTFILES_TEST_LOG_DIR:?DOTFILES_TEST_LOG_DIR required}"
RENDER_REPORT="${1:-$LOG_DIR/prompt-report.md}"

# --- Status table ----------------------------------------------------------
# Read every <test>.status file. Each is `pass` or `fail`. Order by filename
# so the table reads NN-name top-to-bottom.
status_dir="$LOG_DIR/status"
declare -a rows
overall_pass=1
if [ -d "$status_dir" ]; then
  for f in "$status_dir"/*; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    status=$(cat "$f" 2>/dev/null || echo "unknown")
    case "$status" in
      pass) icon="✅" ;;
      fail) icon="❌"; overall_pass=0 ;;
      *)    icon="❓" ;;
    esac
    rows+=("| \`$name\` | $icon $status |")
  done
fi

if (( overall_pass )); then
  header_icon="✅"
  header_text="all green"
else
  header_icon="❌"
  header_text="failure"
fi

# --- Startup time ----------------------------------------------------------
current_ms=""
if [ -s "$LOG_DIR/startup-median.ms" ]; then
  current_ms=$(cat "$LOG_DIR/startup-median.ms")
fi
base_ms="${DOTFILES_TEST_BASE_MS:-}"

speed_line=""
if [ -n "$current_ms" ]; then
  speed_line="**Interactive startup**: ${current_ms}ms median (10 runs)"
  if [ -n "$base_ms" ] && [ "$base_ms" != "0" ]; then
    delta=$(( current_ms - base_ms ))
    pct=$(( delta * 100 / base_ms ))
    if (( delta > 0 )); then
      arrow="⬆️ +${delta}ms (+${pct}%)"
    elif (( delta < 0 )); then
      arrow="⬇️ ${delta}ms (${pct}%)"
    else
      arrow="±0ms (±0%)"
    fi
    speed_line+=" — base ${base_ms}ms, $arrow vs base"
  fi
fi

# --- Assemble --------------------------------------------------------------
printf '## zsh prompt — %s %s\n\n' "$header_icon" "$header_text"

if [ "${#rows[@]}" -gt 0 ]; then
  printf '| Test | Status |\n'
  printf '| --- | --- |\n'
  for r in "${rows[@]}"; do
    printf '%s\n' "$r"
  done
  printf '\n'
fi

if [ -n "$speed_line" ]; then
  printf '%s\n\n' "$speed_line"
fi

# Embed the existing render report. It already has its own <details>
# wrapper per fixture, so we just strip the report's own H2 + meta lines
# (we emitted our own header above) and dump the rest.
if [ -s "$RENDER_REPORT" ]; then
  sed -n '/<details>/,$p' "$RENDER_REPORT"
fi
