#!/usr/bin/env bash
set -euo pipefail

echo "Testing zinit times"
zinit times

for i in $(seq 1 10); do time zsh -i -c exit; done