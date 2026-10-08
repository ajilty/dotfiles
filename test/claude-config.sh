#!/usr/bin/env bash
# Checks the tracked Claude Code config with Claude Code's own validators,
# so a bad settings key, a skill whose frontmatter no longer parses, or a mod
# broken by an API change fails a PR instead of failing silently at load time.
#
#   settings  `claude doctor` checks settings.json against the CLI's built-in
#             schema. It exits 0 even when the file is invalid, so we read its
#             "Invalid settings" section, and prove that reading still works by
#             feeding it a known-bad file first.
#   skills    `claude plugin validate --strict` on the skills tree.
#   mods      per mod: `claude plugin validate` and `claude plugin test`, the
#             pair the mods docs recommend for CI. Type-checking stays a local
#             step: Claude Code writes a mod's type files only in a session
#             where the mod is being developed (2.1.295 and later).
#
# Needs `claude` on PATH. No sign-in or network: every run uses a
# throwaway HOME and an unreachable API endpoint, so nothing is sent anywhere.
#
#   bash test/claude-config.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
failed=0

fail() { echo "::error::$*"; failed=1; }

# Run claude in an empty HOME, away from this repo's own settings and hooks.
offline_claude() {
  local home="$1"; shift
  (cd "$home" && env -i HOME="$home" PATH="$PATH" TERM=dumb \
    ANTHROPIC_API_KEY=offline ANTHROPIC_BASE_URL=http://127.0.0.1:9 \
    claude "$@" </dev/null)
}

# Prints doctor's "Invalid settings" lines for a settings file; empty if clean.
settings_errors() {
  local home="$WORK/doctor-$RANDOM"
  mkdir -p "$home/.claude"
  cp "$1" "$home/.claude/settings.json"
  offline_claude "$home" doctor 2>&1 | sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g' |
    awk '/^Invalid settings/ { on = 1; next } on && /^- / { print; next } on && !/^  / { on = 0 }'
}

echo "== settings: the check still catches a bad file"
jq '.permissions.defaultMode = "not-a-mode" | .model = 42' "$ROOT/.claude/settings.json" > "$WORK/bad.json"
if [ -z "$(settings_errors "$WORK/bad.json")" ]; then
  fail "claude doctor no longer reports a known-bad settings.json; this check has gone blind"
fi

echo "== settings: .claude/settings.json"
errors="$(settings_errors "$ROOT/.claude/settings.json")"
if [ -n "$errors" ]; then
  echo "$errors"
  fail ".claude/settings.json does not match Claude Code's settings schema"
fi

echo "== skills: .agents/skills"
claude plugin validate --strict "$ROOT/.agents/skills" || fail "a skill in .agents/skills does not validate"

shopt -s nullglob
for mod in "$ROOT"/.claude/mods/*/; do
  mod="${mod%/}"
  name="$(basename "$mod")"
  echo "== mod: $name"
  claude plugin validate --strict "$mod" || { fail "mod $name does not validate"; continue; }
  claude plugin test "$mod" || fail "mod $name tests fail"
done

if [ "$failed" -ne 0 ]; then
  exit 1
fi
echo "ok: Claude Code config checks pass"
