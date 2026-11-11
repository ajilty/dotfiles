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

# `blocklist check`: vets text no hook sees (a PR title and description),
# from files or stdin, with the same fixed and regex semantics. It must
# fail closed: only "every pattern ran and none matched" exits 0.
run_check() { HOME="$fake_home" bash "$DOTFILES_BIN" blocklist check "$@" 2>&1; }

printf 'private-string@example.com\nre:secret-[0-9]+\nalpha beta\n' > "$blocklist_dir/blocklist"
printf '## Why\nA harmless description.\n' > "$sandbox/clean.md"
printf '## Why\nMail Private-String@Example.com about it.\n' > "$sandbox/fixed.md"
printf 'Refers to secret-42 in passing.\n' > "$sandbox/regex.md"

out="$(run_check "$sandbox/clean.md")" || die "clean text failed the check: $out"
case "$out" in *"check clean (3 patterns)"*) ;; *) die "unexpected clean-check message: $out" ;; esac
info "clean text passes the check"

if out="$(run_check "$sandbox/fixed.md")"; then
  die "check passed despite a blocklisted string (case-insensitive): $out"
fi
grep -q "private-string@example.com" <<<"$out" || die "check output missing the fixed pattern: $out"
info "fixed-string hit fails the check"

if out="$(run_check "$sandbox/clean.md" "$sandbox/regex.md")"; then
  die "check passed despite a regex hit in the second file: $out"
fi
grep -q "re:secret-" <<<"$out" || die "check output missing the regex pattern: $out"
info "regex hit in any named file fails the check"

if out="$(printf 'title with secret-7\n' | run_check)"; then
  die "check passed on stdin despite a hit: $out"
fi
out="$(printf 'a clean title\n' | run_check)" || die "clean stdin failed the check: $out"
info "stdin is checked when no file is named"

# A hit on line 1 of a large text: a `printf | grep -q` under pipefail
# reads the early grep exit as a miss.
{ printf 'private-string@example.com\n'; head -c 300000 /dev/zero | tr '\0' 'x' | fold -w 80; } > "$sandbox/large.md"
if out="$(run_check "$sandbox/large.md")"; then
  die "check passed despite an early hit in large text: $out"
fi
info "early hit in large text fails the check"

# A hit wrapped across two lines, and CRLF text.
printf 'see alpha\nbeta for details\n' > "$sandbox/wrapped.md"
if out="$(run_check "$sandbox/wrapped.md")"; then
  die "check passed despite a hit wrapped across lines: $out"
fi
printf 'see alpha \n    beta for details\n' > "$sandbox/wrapped-indented.md"
if out="$(run_check "$sandbox/wrapped-indented.md")"; then
  die "check passed despite a wrapped hit with trailing space and indent: $out"
fi
printf 'see alpha\rbeta for details\r' > "$sandbox/lone-cr.md"
if out="$(run_check "$sandbox/lone-cr.md")"; then
  die "check passed despite a hit wrapped across lone-CR line endings: $out"
fi
printf 'ends with secret-9\r\n' > "$sandbox/crlf.md"
if out="$(run_check "$sandbox/crlf.md")"; then
  die "check passed despite a hit in CRLF text: $out"
fi
info "wrapped and CRLF hits fail the check"

# Nothing to check is not clean.
: > "$sandbox/empty.md"
if out="$(run_check "$sandbox/empty.md")"; then
  die "check passed on an empty file: $out"
fi
if out="$(printf '' | run_check)"; then
  die "check passed on empty stdin: $out"
fi
case "$out" in *"nothing to check"*) ;; *) die "unexpected empty-input message: $out" ;; esac
info "empty input refuses, never reads as clean"

if out="$(run_check "$sandbox/does-not-exist.md")"; then
  die "check passed on a missing file: $out"
fi
case "$out" in *"cannot read"*) ;; *) die "unexpected missing-file message: $out" ;; esac
info "missing file refuses, never reads as clean"

# Blocklist problems are failures too: a CRLF blocklist still matches, an
# invalid regex or a pattern-less list is an error, not a pass.
printf 'private-string@example.com\r\n' > "$blocklist_dir/blocklist"
if out="$(run_check "$sandbox/fixed.md")"; then
  die "check passed with a CRLF blocklist line: $out"
fi
printf 're:secret-[0-9\n' > "$blocklist_dir/blocklist"
if out="$(run_check "$sandbox/clean.md")"; then
  die "check passed although a pattern could not run: $out"
fi
case "$out" in *"pattern failed to run"*) ;; *) die "unexpected bad-pattern message: $out" ;; esac
printf '# only a comment\n' > "$blocklist_dir/blocklist"
if out="$(run_check "$sandbox/clean.md")"; then
  die "check passed with a pattern-less blocklist: $out"
fi
info "CRLF, invalid and pattern-less blocklists never read as clean"

if [ "$(id -u)" -ne 0 ]; then
  printf 'private-string@example.com\n' > "$blocklist_dir/blocklist"
  chmod 000 "$blocklist_dir/blocklist"
  if out="$(run_check "$sandbox/fixed.md")"; then
    die "check passed with an unreadable blocklist: $out"
  fi
  chmod 644 "$blocklist_dir/blocklist"
  info "unreadable blocklist never reads as clean"
fi

rm -f "$blocklist_dir/blocklist"
if out="$(run_check "$sandbox/clean.md")"; then
  die "check passed with no blocklist present: $out"
fi
case "$out" in *"no blocklist at"*) ;; *) die "unexpected missing-blocklist message: $out" ;; esac
info "missing blocklist refuses to check"
