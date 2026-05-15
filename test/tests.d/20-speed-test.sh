#!/usr/bin/env bash
# Informational benchmark: dump zinit timing data and measure 10 interactive
# startups. Never gates CI -- a slow runner shouldn't fail the suite. But
# DOES write the median to $LOG_DIR/startup-median.ms so the PR-comment
# build step can show it (and compare against the base branch).
#
# `zinit` is a zsh function (not a binary), so calls go through `zsh -ic`
# rather than running bare. Both calls run under script(1) for PTY -- without
# one, zinit's bootstrap is incomplete (see test/prompt/lib.zsh for why).
set -uo pipefail

LOG_DIR="${DOTFILES_TEST_LOG_DIR:-${HOME}/test-logs}"
mkdir -p "$LOG_DIR"

if ! command -v script >/dev/null 2>&1; then
  echo "(script unavailable; skipping speed test)"
  exit 0
fi

echo "zinit times:"
script -qec 'zsh -i -c "zinit times"' /dev/null 2>&1 || echo "(zinit times unavailable)"

echo
echo "10x interactive startup:"
times_file="$LOG_DIR/startup-times.ms"
: > "$times_file"
for _ in $(seq 1 10); do
  # date +%s%N: nanoseconds since epoch. Portable enough on GNU systems
  # (and the CI runners we care about); macOS coreutils gdate works too.
  start_ns=$(date +%s%N)
  script -qec 'zsh -i -c exit' /dev/null >/dev/null 2>&1 || true
  end_ns=$(date +%s%N)
  ms=$(( (end_ns - start_ns) / 1000000 ))
  echo "${ms}ms"
  echo "$ms" >> "$times_file"
done

# Median of 10 values: average of the 5th and 6th elements after sort.
# Pure-bash so no python/jq dependency.
if [ -s "$times_file" ]; then
  mapfile -t sorted < <(sort -n "$times_file")
  median=$(( (${sorted[4]} + ${sorted[5]}) / 2 ))
  echo "$median" > "$LOG_DIR/startup-median.ms"
  echo
  echo "median: ${median}ms (over ${#sorted[@]} runs)"
fi

exit 0
