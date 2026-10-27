#!/usr/bin/env bash
# `dotfiles try <branch>`: the branch in its own git worktree, run with HOME
# pointed there, untracked state linked in from the real home, and the real
# home left on master. Covers a remote-only branch, a PR number, fixing and
# committing in place (with the pre-commit checks on), picking up new pushes
# without losing local work, and an unknown branch.
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
mkdir -p "$fake_home" "$sandbox/bin"
unset XDG_CACHE_HOME GIT_DIR GIT_WORK_TREE

scratch_git() {
  # push.negotiate=false: recent git prints a harmless negotiation failure
  # against file:// remotes, which would only clutter the log.
  git -c user.name=test -c user.email=test@example.com -c push.negotiate=false "$@"
}

# Remote master mirrors the real layout in miniature: an inverse-allowlist
# .gitignore, a settings file in a dot-directory that also holds untracked
# state, the dotfiles git include, and a pre-commit hook that leaves a mark.
seed="$sandbox/seed"
git init -q --bare -b master "$remote"
scratch_git clone -q "$remote" "$seed" 2>/dev/null
mkdir -p "$seed/dir" "$seed/.claude" "$seed/.config/git" "$seed/.dotfiles-hooks"
printf '*\n' > "$seed/.gitignore"
echo master > "$seed/file"
echo keep > "$seed/dir/tracked"
echo '{"model":"master"}' > "$seed/.claude/settings.json"
printf '[user]\n  name = ajilty\n  email = github@ajilty.com\n[core]\n  hooksPath = ~/.dotfiles-hooks\n' \
  > "$seed/.config/git/dotfiles.config"
printf '#!/bin/sh\necho ran >> "$TRY_HOOK_MARK"\n' > "$seed/.dotfiles-hooks/pre-commit"
chmod +x "$seed/.dotfiles-hooks/pre-commit"
scratch_git -C "$seed" add -f .gitignore file dir/tracked .claude/settings.json \
  .config/git/dotfiles.config .dotfiles-hooks/pre-commit
scratch_git -C "$seed" commit -qm "master"
scratch_git -C "$seed" push -q origin master

# A feature branch that edits, adds and deletes, pushed but not fetched.
scratch_git -C "$seed" checkout -qb feature
echo feature > "$seed/file"
mkdir -p "$seed/new"
echo added > "$seed/new/file"
echo '{"model":"feature"}' > "$seed/.claude/settings.json"
scratch_git -C "$seed" rm -q dir/tracked
scratch_git -C "$seed" add -f file new/file .claude/settings.json
scratch_git -C "$seed" commit -qm "feature"
scratch_git -C "$seed" push -q origin feature

# Bare clone into the sandbox HOME, mirroring the real layout, master only.
scratch_git clone -q --bare --branch master "$remote" "$fake_home/.dotfiles"
git --git-dir="$fake_home/.dotfiles" config core.bare false
git --git-dir="$fake_home/.dotfiles" config core.worktree "$fake_home"
git --git-dir="$fake_home/.dotfiles" --work-tree="$fake_home" checkout -q master
git --git-dir="$fake_home/.dotfiles" branch -q -D feature

# Untracked state in the real home: beside a tracked file, inside a tracked
# directory, and inside a directory the branch empties.
echo token > "$fake_home/.claude.json"
mkdir -p "$fake_home/.claude/projects"
echo history > "$fake_home/.claude/projects/log"
echo local > "$fake_home/dir/untracked"

wt="$fake_home/.cache/dotfiles/try/feature"
real_git() { git --git-dir="$fake_home/.dotfiles" "$@"; }
try() { HOME="$fake_home" PATH="$sandbox/bin:$PATH" bash "$DOTFILES_BIN" try "$@"; }

# Remote-only branch, with a stray GIT_DIR from `dotfiles-shell` in the
# environment: the worktree is the branch, HOME is the worktree.
out="$(GIT_DIR="$fake_home/.dotfiles" GIT_WORK_TREE="$fake_home" try feature -- sh -c '
  echo "file=$(cat file)"
  echo "new=$(cat new/file)"
  echo "settings=$(cat .claude/settings.json)"
  echo "deleted=$([ -e dir/tracked ] && echo present || echo gone)"
  echo "untracked=$(cat dir/untracked)"
  echo "signin=$(readlink .claude.json)"
  echo "history=$(cat .claude/projects/log)"
  echo "repo=$([ -e .dotfiles ] && echo linked || echo absent)"
  echo "home=$HOME"
  echo "top=$(git rev-parse --show-toplevel)"
  echo "branch=$(git branch --show-current)"
  echo "status=[$(git status --porcelain)]"
' 2>"$sandbox/banner")" || die "try feature failed: $out $(cat "$sandbox/banner")"
for want in 'file=feature' 'new=added' 'settings={"model":"feature"}' 'deleted=gone' \
            'untracked=local' "signin=$fake_home/.claude.json" 'history=history' \
            'repo=absent' "home=$wt" "top=$wt" 'branch=feature' 'status=[]'; do
  grep -qxF -- "$want" <<<"$out" || die "expected '$want' in: $out"
done
grep -q "dotfiles try: feature in $wt" "$sandbox/banner" || die "banner missing: $(cat "$sandbox/banner")"
info "remote-only branch: own worktree, branch content, untracked state linked and invisible to git"

# The real home is untouched.
[ "$(cat "$fake_home/file")" = master ] || die "real home file changed"
[ ! -e "$fake_home/new" ] || die "real home gained the branch's new path"
[ -e "$fake_home/dir/tracked" ] || die "real home lost a tracked file"
[ "$(real_git symbolic-ref --short HEAD)" = master ] || die "real home left master"
[ -z "$(real_git --work-tree="$fake_home" status --porcelain -uno)" ] || die "real worktree dirty after try"
info "real home still on master and clean"

# A new push reaches a rerun as a fast-forward.
echo feature2 > "$seed/file"
scratch_git -C "$seed" commit -qam "feature2"
scratch_git -C "$seed" push -q origin feature
[ "$(try feature -- cat file 2>/dev/null)" = feature2 ] || die "rerun did not pick up the new push"
info "rerun fast-forwards to new pushes"

# Fix in place: the commit lands on the branch, with the dotfiles identity
# and pre-commit hook coming from the include try passes in.
export TRY_HOOK_MARK="$sandbox/hook-ran"
try feature -- sh -c 'echo fixed > file && git commit -qam "fix in place"' 2>/dev/null \
  || die "commit inside try failed"
[ -s "$TRY_HOOK_MARK" ] || die "pre-commit hook did not run for a commit inside try"
[ "$(real_git log -1 --format='%an <%ae>|%s' feature)" = 'ajilty <github@ajilty.com>|fix in place' ] \
  || die "commit not on feature with the dotfiles identity: $(real_git log -1 --format='%an <%ae>|%s' feature)"
[ "$(real_git log --oneline master | wc -l | tr -d ' ')" = 1 ] || die "master gained a commit"
info "commit inside try lands on the branch with identity and hook"

# Local work survives a rerun, even when origin moves on: no merge, a note.
echo feature3 > "$seed/file"
scratch_git -C "$seed" commit -qam "feature3"
scratch_git -C "$seed" push -q origin feature
out="$(try feature -- cat file 2>&1)"
grep -qx fixed <<<"$out" || die "rerun lost the local commit: $out"
grep -q "kept your local changes" <<<"$out" || die "no note about the unmerged push: $out"
info "rerun keeps local work when origin diverged"

# A PR number resolves through gh to the same branch and folder.
printf '#!/bin/sh\necho feature\n' > "$sandbox/bin/gh"
chmod +x "$sandbox/bin/gh"
out="$(try 7 -- sh -c 'echo "$HOME"' 2>/dev/null)"
[ "$out" = "$wt" ] || die "PR number did not reuse the feature worktree: $out"
info "PR number resolves to its branch"

# Unknown branch: a clear error, no folder.
if out="$(try no-such-branch -- true 2>&1)"; then
  die "unknown branch accepted: $out"
fi
grep -q "no branch 'no-such-branch'" <<<"$out" || die "unexpected error: $out"
[ ! -e "$fake_home/.cache/dotfiles/try/no-such-branch" ] || die "folder built for an unknown branch"
info "unknown branch refused"
