#!/usr/bin/env bash
# Informational benchmark: dump zinit timing data and measure 10 interactive
# startups. Never gates CI -- a slow runner shouldn't fail the suite.
#
# `zinit` is a zsh function (not a binary), so calls have to go through
# `zsh -ic` rather than running bare. The previous version of this script
# ran `zinit times` directly from bash under `set -e`, which exits 127 the
# moment bash can't find the command.
set -uo pipefail

echo "zinit times:"
zsh -i -c 'zinit times' 2>&1 || echo "(zinit times unavailable)"

echo
echo "10x interactive startup:"
for _ in $(seq 1 10); do
  { time zsh -i -c exit; } 2>&1 || true
done

exit 0
