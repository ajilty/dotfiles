#!/usr/bin/env bash
# `dotfiles try <rev>`: a branch's tracked files in a scratch home, with
# everything untracked linked back to the real home, and nothing written to
# the real worktree. Covers the three ways a revision arrives (local branch,
# remote-only branch, PR number), a path the branch deletes, write isolation,
# that the repo is unreachable inside, and the error for an unknown revision.
#
# Everything runs against a sandbox HOME with its own scratch remote and bare
# clone, so the test never touches the real ~/.dotfiles.
set -euo pipefail

echo "Testing dotfiles try"
source "$DOTFILES_TEST_LIB"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOTFILES_BIN="$ROOT_DIR/bin/dotfiles"

sandbox="$(create_sandbox_dir)"
trap 'rm -rf "$sandbox"' EXIT

remote="$sandbox/remote.git"
fake_home="$sandbox/home"
export TMPDIR="$sandbox/tmp"
mkdir -p "$fake_home" "$TMPDIR"

scratch_git() {
  # push.negotiate=false: recent git prints a harmless negotiation failure
  # against file:// remotes, which would only clutter the log.
  git -c user.name=test -c user.email=test@example.com -c push.negotiate=false "$@"
}

# Remote: master with a file at the top, one inside a directory, and a
# settings file inside a dot-directory that will also hold untracked state.
seed="$sandbox/seed"
git init -q --bare -b master "$remote"
scratch_git clone -q "$remote" "$seed" 2>/dev/null
mkdir -p "$seed/dir" "$seed/.claude"
echo master > "$seed/file"
echo keep > "$seed/dir/tracked"
echo '{"model":"master"}' > "$seed/.claude/settings.json"
scratch_git -C "$seed" add file dir/tracked .claude/settings.json
scratch_git -C "$seed" commit -qm "master"
scratch_git -C "$seed" push -q origin master

# A feature branch that edits, adds and deletes, pushed but not fetched by
# the clone; and the same commit served as a pull request head.
scratch_git -C "$seed" checkout -qb feature
echo feature > "$seed/file"
mkdir -p "$seed/new"
echo added > "$seed/new/file"
echo '{"model":"feature"}' > "$seed/.claude/settings.json"
scratch_git -C "$seed" rm -q dir/tracked
scratch_git -C "$seed" add file new/file .claude/settings.json
scratch_git -C "$seed" commit -qm "feature"
scratch_git -C "$seed" push -q origin feature
scratch_git -C "$seed" push -q origin feature:refs/pull/7/head

# Bare clone into the sandbox HOME, mirroring the real layout (master only).
scratch_git clone -q --bare --branch master "$remote" "$fake_home/.dotfiles"
git --git-dir="$fake_home/.dotfiles" config core.bare false
git --git-dir="$fake_home/.dotfiles" config core.worktree "$fake_home"
git --git-dir="$fake_home/.dotfiles" --work-tree="$fake_home" checkout -q master
# A bare clone copies every head; drop the branch so it is remote-only here.
git --git-dir="$fake_home/.dotfiles" branch -q -D feature

# Untracked state in the real home: beside a tracked file, inside a tracked
# directory, and inside a directory the branch empties.
echo token > "$fake_home/.claude.json"
mkdir -p "$fake_home/.claude/projects"
echo history > "$fake_home/.claude/projects/log"
echo local > "$fake_home/dir/untracked"

try() { HOME="$fake_home" bash "$DOTFILES_BIN" try "$@"; }

# Remote-only branch: fetched, then the scratch home reflects it.
out="$(try feature -- sh -c '
  echo "file=$(cat file)"
  echo "new=$(cat new/file)"
  echo "settings=$(cat .claude/settings.json)"
  echo "deleted=$([ -e dir/tracked ] && echo present || echo gone)"
  echo "untracked=$(cat dir/untracked)"
  echo "signin=$(readlink .claude.json)"
  echo "history=$(cat .claude/projects/log)"
  echo "home=$HOME pwd=$(pwd) try=$DOTFILES_TRY"
' 2>"$sandbox/banner")" || die "try feature failed: $out $(cat "$sandbox/banner")"
grep -qx 'file=feature' <<<"$out" || die "edited file not from the branch: $out"
grep -qx 'new=added' <<<"$out" || die "added file missing: $out"
grep -qx 'settings={"model":"feature"}' <<<"$out" || die "settings not from the branch: $out"
grep -qx 'deleted=gone' <<<"$out" || die "a path the branch deleted came back: $out"
grep -qx 'untracked=local' <<<"$out" || die "untracked file in an emptied directory not reachable: $out"
grep -qx "signin=$fake_home/.claude.json" <<<"$out" || die "top-level untracked file not linked: $out"
grep -qx 'history=history' <<<"$out" || die "untracked file inside a tracked directory not linked: $out"
grep -q "home=$TMPDIR/dotfiles-try-" <<<"$out" || die "HOME not under TMPDIR: $out"
grep -q 'try=origin/feature' <<<"$out" || die "DOTFILES_TRY not set to the resolved ref: $out"
grep -q 'dotfiles try: origin/feature' "$sandbox/banner" || die "banner missing: $(cat "$sandbox/banner")"
info "remote-only branch: edits, additions and deletions all visible; untracked state linked"

# The real home is untouched: same content, nothing extra, worktree clean.
[ "$(cat "$fake_home/file")" = master ] || die "real home file changed"
[ ! -e "$fake_home/new" ] || die "real home gained the branch's new path"
[ -e "$fake_home/dir/tracked" ] || die "real home lost a tracked file"
[ -z "$(git --git-dir="$fake_home/.dotfiles" --work-tree="$fake_home" status --porcelain -uno)" ] \
  || die "real worktree dirty after try"
info "real home untouched"

# Writes: a tracked path stays in the scratch copy; a linked path writes
# through to the real file (shared state like sign-in is meant to).
try feature -- sh -c 'echo scratch > file; echo refreshed > .claude.json' 2>/dev/null
[ "$(cat "$fake_home/file")" = master ] || die "write to a tracked path reached the real home"
[ "$(cat "$fake_home/.claude.json")" = refreshed ] || die "write through a link did not reach the real file"
info "writes to tracked paths stay in the scratch home; linked paths write through"

# Local branch and PR number resolve too; a rerun rebuilds from scratch.
git --git-dir="$fake_home/.dotfiles" branch -q local-copy origin/feature
out="$(try local-copy -- sh -c 'cat file; echo "$DOTFILES_TRY"' 2>/dev/null)"
[ "$out" = $'feature\nlocal-copy' ] || die "local branch: $out"
out="$(try 7 -- sh -c 'cat file; echo "$DOTFILES_TRY"' 2>/dev/null)"
[ "$out" = $'feature\norigin/pr/7' ] || die "PR number: $out"
info "local branch and PR number resolve"

# Inside, the repo is out of reach: not linked in (so even the branch's own
# copy of the script, or plain git, finds nothing), and this script says why.
out="$(try feature -- sh -c '[ -e .dotfiles ] && echo linked || echo absent' 2>/dev/null)"
[ "$out" = absent ] || die "repo linked into the scratch home"
if out="$(try feature -- git --git-dir="\$HOME/.dotfiles" status 2>&1)"; then
  die "git reached a repo from inside the scratch home: $out"
fi
if out="$(try feature -- bash "$DOTFILES_BIN" commit -qm nope 2>&1)"; then
  die "commit allowed inside try: $out"
fi
grep -q "unavailable inside" <<<"$out" || die "unexpected refusal message: $out"
[ "$(git --git-dir="$fake_home/.dotfiles" log --oneline master | wc -l)" -eq 1 ] || die "master gained a commit"
info "no repo inside a try; dotfiles explains and refuses"

# Unknown revision: a clear error, nothing built.
if out="$(try no-such-branch -- true 2>&1)"; then
  die "unknown revision accepted: $out"
fi
grep -q "not a branch here or on origin" <<<"$out" || die "unexpected error: $out"
[ ! -e "$TMPDIR/dotfiles-try-$(id -u)/no-such-branch" ] || die "scratch home built for an unknown revision"
info "unknown revision refused"
