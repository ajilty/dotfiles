#!/usr/bin/env bash
# PostToolUse (Write|Edit): parse the just-written file if it is JSON or YAML, and
# feed any syntax error straight back to the model so it self-corrects immediately.
#
# Input: hook payload JSON on STDIN; the target file is tool_input.file_path.
# We validate ONLY that one file — never `git diff` (misses untracked new files,
# scans unrelated dirty files, and is cwd/repo-root relative).
#
# Contract: PASS = exit 0 with NO output; FAIL = reason + parser stderr on stderr,
# exit 2 (PostToolUse blocking error: stderr is injected back into the model's
# context; plain exit 1 would only surface to the user and never self-correct).
#
# Fail-open by design: this is a lint assist, not a safety gate. Missing jq/yq,
# unreadable payload, or a vanished file all exit 0. JSONC dialects (tsconfig,
# .vscode, devcontainer) are skipped — comments are legal there and jq would
# false-positive.

set -u

command -v jq >/dev/null 2>&1 || exit 0
f=$(jq -r '.tool_input.file_path // empty' 2>/dev/null) || exit 0
[ -n "$f" ] && [ -f "$f" ] || exit 0

case "$f" in
  *tsconfig*.json|*jsconfig*.json|*/.vscode/*.json|*/.devcontainer/*.json|*devcontainer.json)
    exit 0 ;;
  *.json)
    if ! err=$(jq . "$f" 2>&1 >/dev/null); then
      printf 'syntax-guard: invalid JSON in %s\n%s\n' "$f" "$err" >&2
      exit 2
    fi ;;
  *.yaml|*.yml)
    command -v yq >/dev/null 2>&1 || exit 0
    if ! err=$(yq . "$f" 2>&1 >/dev/null); then
      printf 'syntax-guard: invalid YAML in %s\n%s\n' "$f" "$err" >&2
      exit 2
    fi ;;
esac

exit 0
