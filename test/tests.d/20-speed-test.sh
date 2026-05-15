#!/usr/bin/env bash
# Informational benchmark: dump zinit timing data and measure 10 interactive
# startups. Never gates CI -- a slow runner shouldn't fail the suite.
#
# `zinit` is a zsh function (not a binary), so calls have to go through
# `zsh -ic` rather than running bare. Run under `script` to provide a PTY
# (without one, zinit's bootstrap is incomplete: see test/prompt/lib.zsh
# and 31-prompt-no-stderr.sh for the same fix).
set -uo pipefail

if ! command -v script >/dev/null 2>&1; then
  echo "(script unavailable; skipping speed test)"
  exit 0
fi

echo "zinit times:"
script -qec 'zsh -i -c "zinit times"' /dev/null 2>&1 || echo "(zinit times unavailable)"

echo
echo "10x interactive startup:"
for _ in $(seq 1 10); do
  { time script -qec 'zsh -i -c exit' /dev/null >/dev/null; } 2>&1 || true
done

exit 0
