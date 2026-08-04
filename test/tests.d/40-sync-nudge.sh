#!/usr/bin/env bash
# The sync-status nudge pipeline: `dotfiles sync-status` must write an
# accurate drift line to the cache (and clear it when back in sync), and
# the functions.d nudge module must stay silent in non-interactive shells.
#
# Everything runs against a sandbox HOME with its own scratch remote and
# bare clone, so the test never touches the real ~/.dotfiles.
set -euo pipefail

echo "Testing dotfiles sync-status cache and nudge module"
source "$DOTFILES_TEST_LIB"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOTFILES_BIN="$ROOT_DIR/bin/dotfiles"

sandbox="$(create_sandbox_dir)"
trap 'rm -rf "$sandbox"' EXIT

remote="$sandbox/remote.git"
fake_home="$sandbox/home"
mkdir -p "$fake_home"

scratch_git() {
  git -c user.name=test -c user.email=test@example.com "$@"
}

# Seed a remote with one commit, then (later) a second the clone won't have.
seed="$sandbox/seed"
git init -q --bare -b master "$remote"
scratch_git clone -q "$remote" "$seed" 2>/dev/null
echo one > "$seed/file"
scratch_git -C "$seed" add file
scratch_git -C "$seed" commit -qm "first"
scratch_git -C "$seed" push -q origin master

# Bare clone into the sandbox HOME, mirroring the real layout.
scratch_git clone -q --bare "$remote" "$fake_home/.dotfiles"
git --git-dir="$fake_home/.dotfiles" config core.bare false
git --git-dir="$fake_home/.dotfiles" config core.worktree "$fake_home"
git --git-dir="$fake_home/.dotfiles" --work-tree="$fake_home" checkout -q master

# Push a new commit to the remote so the clone is 1 behind.
echo two > "$seed/file"
scratch_git -C "$seed" commit -qam "second"
scratch_git -C "$seed" push -q origin master

cache="$fake_home/.cache/dotfiles/sync-nudge"

HOME="$fake_home" bash "$DOTFILES_BIN" sync-status >/dev/null
[ -s "$cache" ] || die "cache empty despite being behind remote"
grep -q "1 behind" "$cache" || die "cache missing '1 behind': $(cat "$cache")"
grep -q "dotfiles pull" "$cache" || die "cache missing pull hint: $(cat "$cache")"
info "behind state detected: $(cat "$cache")"

# Dirty worktree should surface as uncommitted.
echo local-change > "$fake_home/file"
HOME="$fake_home" bash "$DOTFILES_BIN" sync-status >/dev/null
grep -q "1 uncommitted" "$cache" || die "cache missing '1 uncommitted': $(cat "$cache")"
info "dirty state detected: $(cat "$cache")"

# Catch up fully: cache must go empty and the command must say in sync.
git --git-dir="$fake_home/.dotfiles" --work-tree="$fake_home" checkout -q -- file
git --git-dir="$fake_home/.dotfiles" --work-tree="$fake_home" -c rebase.autoStash=true pull -q --rebase origin master
out="$(HOME="$fake_home" bash "$DOTFILES_BIN" sync-status)"
[ ! -s "$cache" ] || die "cache not cleared after catching up: $(cat "$cache")"
case "$out" in *"in sync"*) ;; *) die "expected in-sync output, got: $out" ;; esac
info "in-sync state clears the cache"

# An unpushed local commit should surface as ahead with a push hint.
echo three > "$fake_home/file"
git --git-dir="$fake_home/.dotfiles" --work-tree="$fake_home" add file
git --git-dir="$fake_home/.dotfiles" --work-tree="$fake_home" \
  -c user.name=test -c user.email=test@example.com commit -qm "local"
HOME="$fake_home" bash "$DOTFILES_BIN" sync-status >/dev/null
grep -q "1 ahead" "$cache" || die "cache missing '1 ahead': $(cat "$cache")"
grep -q "dotfiles push" "$cache" || die "cache missing push hint: $(cat "$cache")"
info "ahead state detected: $(cat "$cache")"

# The nudge module must produce no output when sourced non-interactively.
nudge_out="$(HOME="$fake_home" bash -c '. "$0"' "$ROOT_DIR/.config/shell/functions.d/dotfiles-nudge.sh" 2>&1)"
[ -z "$nudge_out" ] || die "nudge module emitted output in a non-interactive shell: $nudge_out"
info "nudge module silent in non-interactive shells"

# Syntax must hold in both shells that source functions.d.
bash -n "$ROOT_DIR/.config/shell/functions.d/dotfiles-nudge.sh"
if command -v zsh >/dev/null 2>&1; then
  zsh -n "$ROOT_DIR/.config/shell/functions.d/dotfiles-nudge.sh"
fi
info "nudge module parses in bash and zsh"
