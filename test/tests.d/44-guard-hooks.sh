#!/usr/bin/env bash
# The commit-time and push-time content guards (.dotfiles-hooks/pre-commit and
# pre-push) must fail closed: a private string anywhere in the text blocks,
# however large the text, and a pattern that cannot run blocks too. Only
# "every pattern ran and none matched" lets a commit or push through.
#
# Runs both hooks directly against a scratch repo in a sandbox HOME.
set -euo pipefail

echo "Testing dotfiles commit and push content guards"
source "$DOTFILES_TEST_LIB"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PRE_COMMIT="$ROOT_DIR/.dotfiles-hooks/pre-commit"
PRE_PUSH="$ROOT_DIR/.dotfiles-hooks/pre-push"

sandbox="$(create_sandbox_dir)"
trap 'rm -rf "$sandbox"' EXIT

fake_home="$sandbox/home"
blocklist="$fake_home/.local/config/dotfiles/blocklist"
repo="$sandbox/repo"
mkdir -p "$(dirname "$blocklist")" "$repo"

# Cut every tie to the caller's git: a test started from inside a hook or a
# `dotfiles` shell inherits GIT_DIR and would otherwise commit to that repo.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR
# The identity both hooks expect, set by environment, with no user or system
# git config in play (XDG_CONFIG_HOME would otherwise still reach the real one).
export GIT_AUTHOR_NAME=ajilty GIT_AUTHOR_EMAIL=github@ajilty.com
export GIT_COMMITTER_NAME=ajilty GIT_COMMITTER_EMAIL=github@ajilty.com
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export XDG_CONFIG_HOME="$fake_home/.config"

g() { HOME="$fake_home" git -C "$repo" "$@"; }
g init -q -b master
printf 'seed\nold line with private-string@example.com\n' > "$repo/file"
g add file
g commit -qm "seed"
base="$(g rev-parse HEAD)"

# 300 KB of filler: more than a pipe holds, so a writer feeding `grep -q`
# is still writing when grep exits on an early hit.
filler="$sandbox/filler"
i=0
while [ "$i" -lt 6000 ]; do
  printf 'filler line %05d: nothing private here, only padding text\n' "$i"
  i=$((i + 1))
done > "$filler"

set_blocklist() { printf "$@" > "$blocklist"; }
# HOOK_LIMIT, when set, caps the size of any file the hook writes, which is
# how a full disk looks to it.
HOOK_LIMIT=""
limit() { if [ -n "$HOOK_LIMIT" ]; then ulimit -f "$HOOK_LIMIT"; fi; }
run_pre_commit() { (cd "$repo" && limit && HOME="$fake_home" bash "$PRE_COMMIT" 2>&1); }
# Stage one file's content, run the hook, leave the index as it was.
commit_check() {  # commit_check <source-file>
  cp "$1" "$repo/staged"
  g add staged
  local rc=0
  out="$(run_pre_commit)" || rc=$?
  g rm -q --cached staged
  rm -f "$repo/staged"
  return "$rc"
}

# ---- pre-commit ---------------------------------------------------------
set_blocklist 'private-string@example.com\nre:secret-[0-9]+\n'

printf 'a harmless line\n' > "$sandbox/clean"
commit_check "$sandbox/clean" || die "pre-commit blocked clean content: $out"
info "pre-commit passes clean content"

printf 'mail Private-String@Example.com\n' > "$sandbox/hit"
if commit_check "$sandbox/hit"; then die "pre-commit passed a blocklisted string: $out"; fi
case "$out" in *"content guard tripped"*) ;; *) die "unexpected hit message: $out" ;; esac
info "pre-commit blocks a fixed-string hit, case-insensitively"

{ printf 'see secret-42 on line one\n'; cat "$filler"; } > "$sandbox/early"
if commit_check "$sandbox/early"; then
  die "pre-commit passed a hit at the top of a 300 KB diff: $out"
fi
case "$out" in *"re:secret-"*) ;; *) die "early-hit output missing the pattern: $out" ;; esac
info "pre-commit blocks a hit at the top of a 300 KB diff"

# A hook that cannot stage the text it scans must block, not pass: the hit is
# on the last line, so nothing short of scanning the whole text finds it.
{ cat "$filler"; printf 'see secret-42 on the last line\n'; } > "$sandbox/late"
HOOK_LIMIT=8
if commit_check "$sandbox/late"; then
  die "pre-commit passed when it could not write its scan file: $out"
fi
HOOK_LIMIT=""
info "pre-commit blocks when it cannot write its scan file"

# Removing a leaked line is the fix we want, so it must not block.
printf 'seed\n' > "$repo/file"
g add file
out="$(run_pre_commit)" || die "pre-commit blocked the removal of a leaked line: $out"
g reset -q --hard "$base"
info "pre-commit lets a leaked line be removed"

set_blocklist 'private-string@example.com\r\nre:secret-[0-9]+\r\n'
if commit_check "$sandbox/hit"; then die "pre-commit missed a hit with a CRLF blocklist: $out"; fi
info "pre-commit reads a CRLF blocklist"

set_blocklist 'string-not-here\nre:broken[\n'
if commit_check "$sandbox/clean"; then
  die "pre-commit passed although a pattern could not run: $out"
fi
case "$out" in *"failed to run"*) ;; *) die "unexpected broken-pattern message: $out" ;; esac
info "pre-commit blocks when a pattern cannot run"

# ---- pre-push -----------------------------------------------------------
# One commit on top of the seed, checked as an update of an existing branch.
push_check() {  # push_check <source-file> <commit message>
  cp "$1" "$repo/pushed"
  g add pushed
  g commit -qm "$2"
  local tip rc=0
  tip="$(g rev-parse HEAD)"
  out="$(cd "$repo" && limit && printf 'refs/heads/master %s refs/heads/master %s\n' "$tip" "$base" \
        | HOME="$fake_home" bash "$PRE_PUSH" 2>&1)" || rc=$?
  g reset -q --hard "$base"
  return "$rc"
}

set_blocklist 'private-string@example.com\nre:secret-[0-9]+\n'

push_check "$sandbox/clean" "add a file" || die "pre-push blocked a clean commit: $out"
info "pre-push passes a clean commit"

if push_check "$sandbox/hit" "add a file"; then die "pre-push passed a blocklisted string: $out"; fi
case "$out" in *"matches blocklist pattern: private-string@example.com"*) ;; *) die "unexpected hit message: $out" ;; esac
info "pre-push blocks a hit in added content"

if push_check "$sandbox/clean" "mention secret-7 in the message"; then
  die "pre-push passed a blocklisted commit message: $out"
fi
info "pre-push blocks a hit in the commit message"

if push_check "$sandbox/early" "add a large file"; then
  die "pre-push passed a hit at the top of a 300 KB commit: $out"
fi
case "$out" in *"re:secret-"*) ;; *) die "early-hit output missing the pattern: $out" ;; esac
info "pre-push blocks a hit at the top of a 300 KB commit"

HOOK_LIMIT=8
if push_check "$sandbox/late" "add a large file"; then
  die "pre-push passed when it could not write its scan file: $out"
fi
HOOK_LIMIT=""
info "pre-push blocks when it cannot write its scan file"

set_blocklist 'private-string@example.com\r\nre:secret-[0-9]+\r\n'
if push_check "$sandbox/hit" "add a file"; then die "pre-push missed a hit with a CRLF blocklist: $out"; fi
info "pre-push reads a CRLF blocklist"

set_blocklist 'string-not-here\nre:broken[\n'
if push_check "$sandbox/clean" "add a file"; then
  die "pre-push passed although a pattern could not run: $out"
fi
case "$out" in *"failed to run"*"Push blocked"*) ;; *) die "unexpected broken-pattern message: $out" ;; esac
info "pre-push blocks when a pattern cannot run"

# No blocklist yet (fresh machine): identity is still checked, content is not.
rm -f "$blocklist"
push_check "$sandbox/hit" "add a file" || die "pre-push failed with no blocklist present: $out"
info "pre-push without a blocklist checks identity only"

info "commit and push content guards fail closed"
