#!/usr/bin/env bash
# skill-sync: copies vendor-shipped agent skills into the store, repairs a
# dangling vendor symlink, reports drift through the nudge cache, and skips
# tools that are not installed. Runs against a sandbox HOME with a fake
# Caskroom and a fake skill-printing binary; never touches the real store.
set -euo pipefail

echo "Testing skill-sync copy, repair, check cache and nudge wiring"
source "$DOTFILES_TEST_LIB"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SKILL_SYNC="$ROOT_DIR/bin/skill-sync"

sandbox="$(create_sandbox_dir)"
trap 'rm -rf "$sandbox"' EXIT
fake_home="$sandbox/home"; mkdir -p "$fake_home/bin"
export HOME="$fake_home" HOMEBREW_PREFIX="$sandbox/brew" XDG_CACHE_HOME="$fake_home/.cache"
store="$fake_home/.agents/skills"; cache="$fake_home/.cache/dotfiles/skill-nudge"

# Fake cask at two versions, newest wins.
for v in 0.11.1 0.15.3; do
  d="$HOMEBREW_PREFIX/Caskroom/terminal-browser/$v/terminal-browser/skills/default/terminal-browser"
  mkdir -p "$d"; printf -- '---\nname: terminal-browser\nversion: %s\n---\n' "$v" > "$d/SKILL.md"
done
# Fake herdr that prints a skill.
cat > "$fake_home/bin/herdr" <<'FAKE'
#!/bin/sh
printf -- '---\nname: herdr\n---\nbody %s\n' "${HERDR_FAKE_VER:-1}"
FAKE
# Only the sandbox bin plus system tools, so a real herdr or brew on this machine never leaks in.
chmod +x "$fake_home/bin/herdr"; export PATH="$fake_home/bin:/usr/bin:/bin"

# 1. Dangling vendor symlink (the failure this script exists for) gets replaced by a copy.
mkdir -p "$store"; ln -s "$HOMEBREW_PREFIX/Caskroom/terminal-browser/0.11.1/gone" "$store/terminal-browser"
if bash "$SKILL_SYNC" check terminal-browser >/dev/null; then die "check did not count a vendor symlink as behind"; fi
out="$(bash "$SKILL_SYNC" terminal-browser)"
[ ! -L "$store/terminal-browser" ] || die "symlink survived sync"
grep -q 'version: 0.15.3' "$store/terminal-browser/SKILL.md" || die "did not copy the newest cask version"
case "$out" in *"dotfiles track "*) ;; *) die "hint must be 'track' (add -f), never 'add -u': $out" ;; esac
# GNU stat first: BSD stat rejects -c silently, GNU stat -f would print a filesystem line.
[ "$(stat -c %a "$store/terminal-browser" 2>/dev/null || stat -f %Lp "$store/terminal-browser")" = "755" ] || die "store dir not 755"
info "dangling symlink replaced by a 755 copy of the newest version, hint says track"

# A Finder .DS_Store inside the store copy must not read as drift.
touch "$store/terminal-browser/.DS_Store"
bash "$SKILL_SYNC" check terminal-browser >/dev/null || die ".DS_Store counted as drift"

# 2. cmd source lands in the store; check is clean afterwards and the cache is empty.
bash "$SKILL_SYNC" herdr >/dev/null
grep -q '^body 1' "$store/herdr/SKILL.md" || die "herdr skill not copied"
bash "$SKILL_SYNC" check >/dev/null || die "check reports drift right after sync"
[ -f "$cache" ] && [ ! -s "$cache" ] || die "cache should exist and be empty when current"
info "both tools current, cache empty"

# 3. Upgrade the binary: check flags it, names it, exits 1; sync clears it.
export HERDR_FAKE_VER=2
if bash "$SKILL_SYNC" check >/dev/null; then die "check missed a changed skill"; fi
grep -q 'herdr' "$cache" || die "cache does not name the stale tool: $(cat "$cache")"
grep -q 'skill-sync' "$cache" || die "cache does not say what to run: $(cat "$cache")"
info "drift detected: $(cat "$cache")"
# A named sync of the OTHER tool must not clear herdr's drift from the cache.
bash "$SKILL_SYNC" terminal-browser >/dev/null
grep -q 'herdr' "$cache" || die "named sync of terminal-browser wiped herdr from the nudge"
bash "$SKILL_SYNC" >/dev/null
[ ! -s "$cache" ] || die "cache not cleared after sync"
grep -q '^body 2' "$store/herdr/SKILL.md" || die "store not refreshed after upgrade"
info "sync refreshed the copy and cleared the cache"

# 4. Tool not installed: skipped, never an error, never a nudge; silent on a full run.
rm "$fake_home/bin/herdr"
bash "$SKILL_SYNC" herdr | grep -q 'skipped' || die "named sync of a missing tool should say skipped"
out="$(bash "$SKILL_SYNC")" || die "missing tool should not fail sync"
case "$out" in *skipped*) die "full run should stay quiet about absent tools: $out" ;; esac
bash "$SKILL_SYNC" check >/dev/null || die "missing tool should not count as drift"
info "missing tool skipped, quietly on a full run"

# 5. A copy that is not tracked in the dotfiles repo is its own nudge, cleared by tracking it.
export DOTFILES_DIR="$fake_home/.dotfiles"
git init -q --bare "$DOTFILES_DIR"; git --git-dir="$DOTFILES_DIR" config core.bare false
sg() { git -C "$fake_home" --git-dir="$DOTFILES_DIR" --work-tree="$fake_home" -c user.name=t -c user.email=t@example.com "$@"; }
sg add -f .agents/skills/herdr >/dev/null && sg commit -qm "track herdr"
if bash "$SKILL_SYNC" check >/dev/null; then die "untracked terminal-browser copy not flagged"; fi
grep -q 'not tracked: terminal-browser' "$cache" || die "cache does not name the untracked copy: $(cat "$cache")"
grep -q 'dotfiles track' "$cache" || die "cache does not say how to track: $(cat "$cache")"
grep -q 'herdr' "$cache" && die "tracked herdr wrongly listed: $(cat "$cache")"
info "untracked copy nudged: $(cat "$cache")"
sg add -f .agents/skills/terminal-browser >/dev/null && sg commit -qm "track terminal-browser"
bash "$SKILL_SYNC" check >/dev/null || die "still flagged after tracking: $(cat "$cache")"
(cd "$fake_home/bin" && bash "$SKILL_SYNC" check >/dev/null) || die "check from a subdirectory of HOME mis-flags tracked copies: $(cat "$cache")"
info "tracking clears the nudge, from HOME and from a subdirectory"

# 5b. brew wrapper: `brew upgrade` passes args through, runs skill-sync, keeps brew's exit code.
cat > "$fake_home/bin/brew" <<'FAKE'
#!/bin/sh
printf '%s\n' "$@" > "$BREW_ARGS_FILE"; exit 3
FAKE
chmod +x "$fake_home/bin/brew"
cp "$SKILL_SYNC" "$fake_home/bin/skill-sync"
export BREW_ARGS_FILE="$sandbox/brew-args"; export HERDR_FAKE_VER=3
cat > "$fake_home/bin/herdr" <<'FAKE'
#!/bin/sh
printf -- '---\nname: herdr\n---\nbody %s\n' "${HERDR_FAKE_VER:-1}"
FAKE
chmod +x "$fake_home/bin/herdr"
rc=0; bash -c "source '$ROOT_DIR/.config/shell/functions.d/brew-sync.sh'; brew upgrade --cask 'a b' c >/dev/null" || rc=$?
[ "$rc" = 3 ] || die "brew upgrade wrapper returned $rc, expected brew's 3"
[ "$(cat "$BREW_ARGS_FILE")" = "$(printf 'upgrade\n--cask\na b\nc')" ] || die "brew args mangled: $(cat "$BREW_ARGS_FILE")"
grep -q '^body 3' "$store/herdr/SKILL.md" || die "brew upgrade did not run skill-sync"
info "brew upgrade wrapper: args intact, exit code kept, skill-sync ran"

# 6. Nudge module stays silent when sourced non-interactively, and parses in both shells.
printf 'Agent skills behind the installed tools: herdr.\n' > "$cache"
out="$(bash -c '. "$0"' "$ROOT_DIR/.config/shell/functions.d/dotfiles-nudge.sh" 2>&1)"
[ -z "$out" ] || die "non-interactive shell printed a nudge: $out"
bash -n "$ROOT_DIR/.config/shell/functions.d/dotfiles-nudge.sh"
bash -n "$ROOT_DIR/.config/shell/functions.d/brew-sync.sh"
bash -n "$ROOT_DIR/.config/shell/functions.d/herdr.sh"
if command -v zsh >/dev/null 2>&1; then
  zsh -n "$ROOT_DIR/.config/shell/functions.d/dotfiles-nudge.sh"
  zsh -n "$ROOT_DIR/.config/shell/functions.d/brew-sync.sh"
  zsh -n "$ROOT_DIR/.config/shell/functions.d/herdr.sh"
fi
info "nudge module silent non-interactively; modules parse in bash and zsh"
echo "skill-sync tests passed"
