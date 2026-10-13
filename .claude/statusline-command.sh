#!/bin/sh
# Claude Code status line — one line, no emojis
# model | dir | git branch (+staged ~modified) | cost | elapsed
#
# Context usage is not drawn here: the context-bar mod (~/.claude/mods)
# draws it above the prompt, by category, wherever mods can draw.

input=$(cat)

# --- Extract fields from JSON (single read, multiple outputs) ---
eval "$(echo "$input" | jq -r '
  "model="      + (.model.display_name // "Unknown" | @sh),
  "cwd="        + (.workspace.current_dir // .cwd // "" | @sh),
  "session_id=" + (.session_id // "default" | @sh),
  "cost_usd="   + ((.cost.total_cost_usd // empty) | if . then tostring else "" end),
  "dur_ms="     + ((.cost.total_duration_ms // empty) | if . then tostring else "" end),
  "effort_lvl=" + (.effort.level // "" | @sh),
  "fast_mode="  + ((.fast_mode // false) | tostring | @sh)
')"

# --- ANSI colours ---
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
YELLOW='\033[33m'
CYAN='\033[36m'
WHITE='\033[37m'
MAGENTA='\033[35m'

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
# Assemble lines
# ------------------------------------------------------------------ #
dir_name=$(basename "$cwd")

# Compact model name: drop the verbose " (1M context)" suffix, show "1M" badge instead
model_short=$(printf '%s' "$model" | sed 's/ *(1M context)//')
ctx_badge=""
case "$model" in *"1M context"*) ctx_badge=" ${DIM}1M${RESET}" ;; esac

# Effort tag — always shown when the model reports an effort level
effort_tag=""
[ -n "$effort_lvl" ] && effort_tag=" ${DIM}·${RESET}${MAGENTA}${effort_lvl}${RESET}"

# Fast-mode flag
fast_tag=""
[ "$fast_mode" = "true" ] && fast_tag=" ${YELLOW}fast${RESET}"

line1="${BOLD}${CYAN}${model_short}${RESET}${ctx_badge}${effort_tag}${fast_tag}  ${WHITE}${dir_name}${RESET}"
if [ -n "$git_info" ]; then
  line1="${line1}  ${DIM}git:${RESET}${git_info}"
fi
[ -n "$cost" ]    && line1="${line1}  ${DIM}cost:${RESET}${cost}"
[ -n "$elapsed" ] && line1="${line1}  ${DIM}${elapsed}${RESET}"

printf '%b' "$line1"
