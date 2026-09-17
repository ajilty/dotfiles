#!/usr/bin/env bash
# `dotfiles blocklist scan`: the history guard that keeps private strings
# out of this public repo. A clean scan must exit 0 even though `git grep`
# itself exits 1 when it matches nothing, and a real hit must fail loudly.
#
# Runs against a scratch bare repo in a sandbox HOME, never the real one.
set -euo pipefail

echo "Testing dotfiles blocklist scan"
source "$DOTFILES_TEST_LIB"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOTFILES_BIN="$ROOT_DIR/bin/dotfiles"

sandbox="$(create_sandbox_dir)"
trap 'rm -rf "$sandbox"' EXIT

fake_home="$sandbox/home"
blocklist_dir="$fake_home/.local/config/dotfiles"
mkdir -p "$blocklist_dir"

git init -q --bare -b master "$fake_home/.dotfiles"
git --git-dir="$fake_home/.dotfiles" config core.bare false
git --git-dir="$fake_home/.dotfiles" config core.worktree "$fake_home"
printf 'hello world\ncontact: private-string@example.com\n' > "$fake_home/file"
git --git-dir="$fake_home/.dotfiles" --work-tree="$fake_home" add -f file
git --git-dir="$fake_home/.dotfiles" --work-tree="$fake_home" \
  -c user.name=test -c user.email=test@example.com commit -qm "seed"

run_scan() { HOME="$fake_home" bash "$DOTFILES_BIN" blocklist scan 2>&1; }

# No blocklist at all: refuse, don't pretend the history is clean.
if out="$(run_scan)"; then
  die "scan passed with no blocklist present: $out"
fi
case "$out" in *"no blocklist at"*) ;; *) die "unexpected missing-blocklist message: $out" ;; esac
info "missing blocklist refuses to scan"

# Clean history: git grep exits 1 on no-match, which must not fail the scan.
printf '# patterns\nstring-not-in-this-repo\n' > "$blocklist_dir/blocklist"
out="$(run_scan)" || die "clean scan exited non-zero: $out"
case "$out" in *"scan clean"*) ;; *) die "unexpected clean-scan message: $out" ;; esac
info "clean scan passes: $out"

# A pattern that IS in history, as a fixed string and as a regex.
printf 'private-string@example.com\nre:hello [a-z]+\n' > "$blocklist_dir/blocklist"
if out="$(run_scan)"; then
  die "scan passed despite a blocklisted string in history: $out"
fi
case "$out" in *"found in committed history"*) ;; *) die "unexpected hit message: $out" ;; esac
grep -q "private-string@example.com" <<<"$out" || die "hit output missing the fixed pattern: $out"
grep -q "re:hello" <<<"$out" || die "hit output missing the regex pattern: $out"
info "leaked string detected by both fixed and regex patterns"

# Comments only: nothing to scan, but not an error.
printf '# only a comment\n' > "$blocklist_dir/blocklist"
out="$(run_scan)" || die "comment-only blocklist exited non-zero: $out"
case "$out" in *"no patterns"*) ;; *) die "unexpected empty-pattern message: $out" ;; esac
info "comment-only blocklist is a no-op"
