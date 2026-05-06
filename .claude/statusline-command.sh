#!/bin/sh
# Claude Code status line — two-line rich display, no emojis
# Line 1: model | dir | git branch (+staged ~modified)
# Line 2: context bar | ctx% | cost | elapsed

input=$(cat)

# --- Extract fields from JSON (single read, multiple outputs) ---
eval "$(echo "$input" | jq -r '
  "model="      + (.model.display_name // "Unknown" | @sh),
  "cwd="        + (.workspace.current_dir // .cwd // "" | @sh),
  "session_id=" + (.session_id // "default" | @sh),
  "used_pct="   + ((.context_window.used_percentage // empty) | if . then tostring else "" end),
  "cost_usd="   + ((.cost.total_cost_usd // empty) | if . then tostring else "" end),
  "dur_ms="     + ((.cost.total_duration_ms // empty) | if . then tostring else "" end)
')"

# --- ANSI colours ---
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
CYAN='\033[36m'
WHITE='\033[37m'

# ------------------------------------------------------------------ #
# Git info — cached in /tmp keyed by session_id, 5-second TTL
# ------------------------------------------------------------------ #
git_cache="/tmp/claude_git_${session_id}"
git_info=""

if [ -n "$cwd" ] && git -C "$cwd" --no-optional-locks rev-parse --git-dir >/dev/null 2>&1; then
  now=$(date +%s)
  cache_valid=0
  if [ -f "${git_cache}" ]; then
    cache_time=$(head -1 "${git_cache}" 2>/dev/null)
    if [ -n "$cache_time" ] && [ $((now - cache_time)) -lt 5 ]; then
      cache_valid=1
    fi
  fi

  if [ "$cache_valid" -eq 1 ]; then
    git_info=$(tail -n +2 "${git_cache}" 2>/dev/null)
  else
    branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
      staged=$(git -C "$cwd" --no-optional-locks diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
      modified=$(git -C "$cwd" --no-optional-locks diff --name-only 2>/dev/null | wc -l | tr -d ' ')
      git_info="$branch"
      [ "$staged" -gt 0 ]    && git_info="${git_info} +${staged}"
      [ "$modified" -gt 0 ]  && git_info="${git_info} ~${modified}"
    fi
    printf '%s\n%s\n' "$now" "$git_info" > "${git_cache}"
  fi
fi

# ------------------------------------------------------------------ #
# Cost and elapsed from JSON (provided directly by Claude Code)
# ------------------------------------------------------------------ #
cost=""
[ -n "$cost_usd" ] && cost=$(awk -v c="$cost_usd" 'BEGIN { printf "$%.2f", c }')

elapsed=""
if [ -n "$dur_ms" ]; then
  dur_s=$(awk -v ms="$dur_ms" 'BEGIN { printf "%d", ms / 1000 }')
  elapsed="${dur_s%% *}s"
  if [ "$dur_s" -ge 60 ]; then
    elapsed="$((dur_s / 60))m $((dur_s % 60))s"
  fi
fi

# ------------------------------------------------------------------ #
# Context bar
# ------------------------------------------------------------------ #
bar_line=""
if [ -n "$used_pct" ]; then
  pct_int=$(printf '%.0f' "$used_pct")
  # Choose colour
  if [ "$pct_int" -ge 90 ]; then
    bar_color="$RED"
  elif [ "$pct_int" -ge 70 ]; then
    bar_color="$YELLOW"
  else
    bar_color="$GREEN"
  fi
  # 20-char bar
  filled=$((pct_int * 20 / 100))
  [ "$filled" -gt 20 ] && filled=20
  empty=$((20 - filled))
  bar=""
  i=0
  while [ $i -lt "$filled" ]; do bar="${bar}#"; i=$((i+1)); done
  i=0
  while [ $i -lt "$empty" ];  do bar="${bar}-"; i=$((i+1)); done
  bar_line="${bar_color}[${bar}]${RESET} ${bar_color}${pct_int}%${RESET}"
else
  bar_line="${DIM}[--------------------] --%${RESET}"
fi

# ------------------------------------------------------------------ #
# Assemble lines
# ------------------------------------------------------------------ #
dir_name=$(basename "$cwd")

# Line 1
line1="${BOLD}${CYAN}${model}${RESET}  ${WHITE}${dir_name}${RESET}"
if [ -n "$git_info" ]; then
  line1="${line1}  ${DIM}git:${RESET}${git_info}"
fi

# Line 2
line2="${bar_line}"
[ -n "$cost" ]    && line2="${line2}  cost:${cost}"
[ -n "$elapsed" ] && line2="${line2}  ${elapsed}"

printf '%b\n%b' "$line1" "$line2"
