#!/usr/bin/env bash
# public-guard (.config/git/public-guard) checks pushes to public ajilty repos
# on GitHub. Real `git push` runs against local bare repos, with the remote's
# url naming a GitHub repo and its pushurl pointing at the local copy, and a
# fake `gh` on PATH answering whether that repo is public.
set -euo pipefail

echo "Testing public-guard, the push guard for public ajilty repos"
source "$DOTFILES_TEST_LIB"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GUARD="$ROOT_DIR/.config/git/public-guard"

sandbox="$(create_sandbox_dir)"
trap 'rm -rf "$sandbox"' EXIT

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR
export GIT_AUTHOR_NAME=ajilty GIT_AUTHOR_EMAIL=github@ajilty.com
export GIT_COMMITTER_NAME=ajilty GIT_COMMITTER_EMAIL=github@ajilty.com
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$sandbox/gitconfig"
export HOME="$sandbox/home" XDG_CONFIG_HOME="$sandbox/home/.config"
blocklist="$HOME/.local/config/dotfiles/blocklist"
mkdir -p "$(dirname "$blocklist")" "$sandbox/bin" "$sandbox/hooks"
: > "$GIT_CONFIG_GLOBAL"
printf 'private-string@example.com\nre:secret-[0-9]+\ntwo words\n' > "$blocklist"

# Fake gh: `gh api repos/<owner>/<repo> --jq ...` prints the line for that
# repo from $sandbox/gh-answers ("<owner>/<repo> <visibility> [parent]"),
# or fails when the repo is not listed there.
cat > "$sandbox/bin/gh" <<EOF
#!/usr/bin/env bash
[ "\$1" = api ] || exit 1
for a in "\$@"; do case "\$a" in repos/*) repo="\${a#repos/}" ;; esac; done
# HANG: never answer, and ignore SIGALRM the way gh (a Go program) does.
if grep -q '^HANG' "$sandbox/gh-answers"; then trap '' ALRM; sleep 30; exit 0; fi
line=\$(grep -i "^\$repo " "$sandbox/gh-answers") || exit 1
set -- \$line
echo "\$2 \${3:-} \${3:-}"
EOF
chmod +x "$sandbox/bin/gh"
export PATH="$sandbox/bin:$PATH"
answer() { printf '%s\n' "$@" > "$sandbox/gh-answers"; }

# The hook as git would run it, under the bash running this test.
printf '#!/bin/sh\nexec "%s" "%s" push "$@"\n' "$BASH" "$GUARD" > "$sandbox/hooks/pre-push"
chmod +x "$sandbox/hooks/pre-push"

git init -q --bare "$sandbox/public.git"
git init -q --bare "$sandbox/other.git"
repo="$sandbox/repo"
git init -q -b master "$repo"
g() { git -C "$repo" "$@"; }
g config core.hooksPath "$sandbox/hooks"
g remote add origin https://github.com/ajilty/demo.git
g config remote.origin.pushurl "$sandbox/public.git"
printf 'seed\n' > "$repo/file"
g add file
g commit -qm seed
g push -q origin master 2>/dev/null || true  # may be blocked before answers exist
answer "ajilty/demo public"
g push -q origin master
# Fetch from the local copy: the url names GitHub and must never be contacted.
g fetch -q "$sandbox/public.git" "+refs/heads/*:refs/remotes/origin/*"
base="$(g rev-parse HEAD)"

# try <file content> <message>: commit on top of base, push, reset.
try() {
  printf '%s\n' "$1" > "$repo/added"
  g add added
  g commit -qm "$2"
  local rc=0
  out="$(g push origin HEAD:refs/heads/master 2>&1)" || rc=$?
  g reset -q --hard "$base"
  g push -q -f origin "$base:refs/heads/master" --no-verify 2>/dev/null
  return "$rc"
}
blocked() { if try "$@"; then die "push passed but should block: $*"; fi; }

try 'a harmless line' 'add a file' || die "blocked a clean push: $out"
info "passes a clean push to a public repo"

blocked 'mail Private-String@Example.com' 'add a file'
case "$out" in *"matches blocklist pattern: private-string@example.com"*"ajilty/demo is public"*) ;;
  *) die "unexpected hit message: $out" ;; esac
info "blocks a blocklisted string in added content"

blocked 'harmless' 'mention secret-7 in the message'
blocked 'harmless' $'two\nwords across lines'
info "blocks a hit in the commit message, also when wrapped across lines"

blocked '++ private-string@example.com' 'add a file'
info "blocks an added line that starts with ++"

printf 'x\n' > "$repo/private-string@example.com.txt"
g add .
g commit -qm 'add a file'
if g push origin HEAD:refs/heads/master >/dev/null 2>&1; then die "passed a blocklisted file name"; fi
g reset -q --hard "$base"
info "blocks a blocklisted file name"

g commit -q --allow-empty -m 'release'
g tag -a v1 -m 'tagged secret-9'
if g push origin v1 >/dev/null 2>&1; then die "passed a blocklisted annotated tag message"; fi
g tag -d v1 >/dev/null
g reset -q --hard "$base"
info "blocks a blocklisted annotated tag message"

GIT_AUTHOR_EMAIL=work@corp.example blocked 'harmless' 'add a file'
case "$out" in *"expected 'ajilty <github@ajilty.com>'"*) ;; *) die "unexpected identity message: $out" ;; esac
info "blocks a commit with another identity"

out="$(GIT_COMMITTER_NAME=GitHub GIT_COMMITTER_EMAIL=noreply@github.com try 'harmless' 'merged on the web' 2>&1)" \
  || die "blocked a commit GitHub committed: $out"
GIT_AUTHOR_NAME=GitHub GIT_AUTHOR_EMAIL=noreply@github.com blocked 'harmless' 'authored as GitHub'
info "accepts GitHub as committer, never as author"

# Visibility comes from GitHub: private passes, unknown is checked as public.
answer "ajilty/demo private"
try 'private-string@example.com' 'add a file' || die "blocked a push to a private repo: $out"
info "leaves private repos alone"
answer "ajilty/other public"
blocked 'private-string@example.com' 'add a file'
case "$out" in *"could not ask GitHub whether ajilty/demo is public"*) ;; *) die "unexpected unknown message: $out" ;; esac
info "checks a repo as public when GitHub cannot be asked"

# Other owners and other hosts are not this guard's business.
answer "ajilty/demo public"
g remote set-url origin https://github.com/someone/demo.git
try 'private-string@example.com' 'add a file' || die "blocked a push to another owner: $out"
info "leaves other owners alone"

# Every spelling of the repo's URL is recognized.
for u in ssh://git@GitHub.com/Ajilty/demo.git git@github.com:AJILTY/demo \
         ssh://git@ssh.github.com:443/ajilty/demo.git \
         https://user@www.github.com/ajilty/demo/ gh:ajilty/demo; do
  g remote set-url origin "$u"
  g config url.https://github.com/.insteadOf gh:
  blocked 'private-string@example.com' 'add a file'
done
g remote set-url origin https://github.com/ajilty/demo.git
info "recognizes ssh, ssh-over-443, scp-style, mixed-case, user, www and insteadOf URLs"

# Missing or unusable blocklist: the push cannot be checked, so it blocks.
mv "$blocklist" "$blocklist.off"
blocked 'harmless' 'add a file'
case "$out" in *"no readable blocklist"*) ;; *) die "unexpected no-blocklist message: $out" ;; esac
mv "$blocklist.off" "$blocklist"
printf '# only a comment\n' > "$blocklist.empty"; cp "$blocklist" "$blocklist.keep"; mv "$blocklist.empty" "$blocklist"
blocked 'harmless' 'add a file'
printf 'private-string@example.com\nre:broken(\n' > "$blocklist"
blocked 'harmless' 'add a file'
case "$out" in *"failed to run"*) ;; *) die "unexpected broken-pattern message: $out" ;; esac
mv "$blocklist.keep" "$blocklist"
info "blocks when the blocklist is missing, empty or has a broken pattern"

# A commit first pushed to some other remote is not public: still checked.
g remote add internal https://github.com/acme/internal.git
g config remote.internal.pushurl "$sandbox/other.git"
printf 'private-string@example.com\n' > "$repo/added"
g add added
g commit -qm 'internal work'
g push -q internal HEAD:refs/heads/master
g fetch -q "$sandbox/other.git" "+refs/heads/*:refs/remotes/internal/*"
if g push origin HEAD:refs/heads/leak >/dev/null 2>&1; then die "passed commits already on a private remote"; fi
g reset -q --hard "$base"
info "checks commits that are only on another remote"

# A fork sync: the parent's commits are already public, whoever wrote them.
answer "ajilty/demo public okta/demo"
git init -q -b master "$sandbox/up"
git -C "$sandbox/up" fetch -q "$repo" master
git -C "$sandbox/up" reset -q --hard FETCH_HEAD
printf 'upstream text with private-string@example.com\n' > "$sandbox/up/upfile"
git -C "$sandbox/up" add upfile
GIT_AUTHOR_NAME=okta GIT_AUTHOR_EMAIL=dev@okta.example GIT_COMMITTER_NAME=okta GIT_COMMITTER_EMAIL=dev@okta.example \
  git -C "$sandbox/up" commit -qm 'upstream change'
g remote add upstream https://github.com/okta/demo.git
g fetch -q "$sandbox/up" master:refs/remotes/upstream/master
g merge -q --ff-only upstream/master
out="$(g push origin HEAD:refs/heads/master 2>&1)" || die "blocked a fork sync from the parent: $out"
g push -q -f origin "$base:refs/heads/master" --no-verify 2>/dev/null
g reset -q --hard "$base"
info "passes a fork sync of the parent's commits"

# A root commit going to an empty branch is scanned (log.showRoot off).
g config log.showRoot false
g checkout -q --orphan fresh
g rm -rq --cached . >/dev/null
printf 'private-string@example.com\n' > "$repo/root"
g add root
g commit -qm 'root'
if g push origin fresh >/dev/null 2>&1; then die "passed a hit in a root commit"; fi
g checkout -q -f master
g config --unset log.showRoot
info "scans a root commit"

# A force-push over a remote tip this clone never fetched cannot be listed.
out="$(cd "$repo" && printf 'refs/heads/master %s refs/heads/master %s\n' "$base" 1111111111111111111111111111111111111111 \
  | "$BASH" "$GUARD" push origin "$sandbox/public.git" 2>&1)" && die "passed an unlistable push"
case "$out" in *"could not list the commits"*) ;; *) die "unexpected unlistable message: $out" ;; esac
info "blocks when the outgoing commits cannot be listed"

# A delete sends nothing and passes.
g push -q origin "$base:refs/heads/gone"
g push -q origin :refs/heads/gone || die "blocked a branch delete"
info "passes a branch delete"

# --public skips the lookup: no gh, no GitHub URL, still checked.
out="$(cd "$repo" && printf 'refs/heads/master %s refs/heads/master %s\n' "$base" 0000000000000000000000000000000000000000 \
  | PATH="/usr/bin:/bin" "$BASH" "$GUARD" push --public x /nowhere 2>&1)" || die "--public blocked a clean push: $out"
info "checks with --public and no GitHub lookup"

# File names and content the diff text would not show.
g mv file private-string@example.com
g commit -qm 'rename'
if g push origin HEAD:refs/heads/master >/dev/null 2>&1; then die "passed a rename to a blocklisted name"; fi
g reset -q --hard "$base"
: > "$repo/secret-5.txt"
g add secret-5.txt
g commit -qm 'empty file'
if g push origin HEAD:refs/heads/master >/dev/null 2>&1; then die "passed an empty file with a blocklisted name"; fi
g reset -q --hard "$base"
printf 'bin\000private-string@example.com\n' > "$repo/blob.bin"
g add blob.bin
g commit -qm 'binary'
if g push origin HEAD:refs/heads/master >/dev/null 2>&1; then die "passed blocklisted bytes in a binary file"; fi
g reset -q --hard "$base"
info "blocks blocklisted names on renames and empty files, and content in binary files"

blocked 'harmless' $'subject\n\ndiff --git a/x b/x\nthen secret-3 in the body'
info "scans the whole message, even past a line that looks like a diff"

# Merges: what a merge itself adds is scanned; a fork sync's merge is not
# blamed for the parent's already-public content.
g checkout -q -b side "$base"
printf 'side\n' > "$repo/side"; g add side; g commit -qm side
g checkout -q master
g merge -q --no-ff --no-commit side
printf 'private-string@example.com\n' > "$repo/evil"; g add evil
g commit -qm 'merge side'
if g push origin HEAD:refs/heads/master >/dev/null 2>&1; then die "passed a hit added by a merge commit"; fi
g reset -q --hard "$base"
g branch -qD side
answer "ajilty/demo public okta/demo"
printf 'mine\n' > "$repo/mine"; g add mine; g commit -qm mine
g merge -q --no-edit upstream/master
out="$(g push origin HEAD:refs/heads/master 2>&1)" || die "blocked merging the parent's public commits: $out"
g push -q -f origin "$base:refs/heads/master" --no-verify 2>/dev/null
g reset -q --hard "$base"
answer "ajilty/demo public"
info "scans what a merge adds, but not the parent's commits it brings in"

# A remote that fetches from a private repo proves nothing about what is
# public, even when it pushes to the public one.
g remote add mirror https://github.com/acme/internal.git
g config remote.mirror.pushurl https://github.com/ajilty/demo.git
g config "url.$sandbox/public.git.insteadOf" https://github.com/ajilty/demo.git
case "$(g remote get-url --push mirror)" in "$sandbox"/*) ;; *) die "mirror would push to GitHub" ;; esac
g fetch -q "$sandbox/other.git" "+refs/heads/*:refs/remotes/mirror/*"
g checkout -q -b fromint mirror/master
if g push mirror HEAD:refs/heads/master >/dev/null 2>&1; then die "trusted commits from a remote that fetches elsewhere"; fi
g checkout -q master
g branch -qD fromint
g config --unset "url.$sandbox/public.git.insteadOf"
g remote remove mirror
info "does not trust a remote that fetches from another repo"

# Every ref of a multi-ref push, and the tagger of an annotated tag.
g branch -q clean "$base"
printf 'private-string@example.com\n' > "$repo/added"; g add added; g commit -qm hit
if g push origin clean HEAD:refs/heads/two >/dev/null 2>&1; then die "passed a hit on the second ref of a push"; fi
g reset -q --hard "$base"
g branch -qD clean
GIT_COMMITTER_NAME=someone GIT_COMMITTER_EMAIL=someone@corp.example g tag -a v2 -m 'release'
if g push origin v2 >/dev/null 2>&1; then die "passed a tag with another tagger"; fi
g tag -d v2 >/dev/null
info "checks every ref of a push, and the tagger of a tag"

# An octopus merge shows no diff of its own, so it blocks.
g branch -q a "$base"; g branch -q b "$base"
g checkout -q a; printf 'a\n' > "$repo/a"; g add a; g commit -qm a
g checkout -q b; printf 'b\n' > "$repo/b"; g add b; g commit -qm b
g checkout -q master
g merge -q --no-ff --no-edit a b
[ "$(g rev-list --parents -1 HEAD | wc -w | tr -d " ")" = 4 ] || die "test setup: not an octopus merge"
if g push origin HEAD:refs/heads/master >/dev/null 2>&1; then die "passed an octopus merge"; fi
g reset -q --hard "$base"
g branch -qD a b
info "blocks an octopus merge it cannot check"

# A GitHub lookup that never answers times out and is checked as public.
answer "HANG"
start=$(date +%s)
out="$(PUBLIC_GUARD_LOOKUP_SECONDS=2 try 'private-string@example.com' 'add a file' 2>&1)" \
  && die "passed when the GitHub lookup hung: $out"
[ $(( $(date +%s) - start )) -lt 20 ] || die "a hung GitHub lookup was not cut off"
answer "ajilty/demo public"
info "cuts off a GitHub lookup that hangs, and checks the repo as public"

info "public-guard checks public ajilty pushes and fails closed"
