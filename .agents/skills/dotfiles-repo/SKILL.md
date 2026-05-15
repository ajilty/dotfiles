---
name: dotfiles-repo
description: Use when working in the bare git dotfiles repo at ~/.dotfiles (worktree $HOME, accessed via the `dotfiles` alias / dotfiles-shell). Covers the inverse-allowlist .gitignore (`*` plus `!.agents/**`) and why `git add` warns on tracked files, the pre-commit identity hook requiring ajilty <github@ajilty.com> (do not --no-verify or --author=), `dotfiles pull` (rebase --autostash) conflict recovery including autostash-pop vs replay conflicts and the `update-index --refresh` gotcha, blocklist bootstrap on fresh machines, commit-message conventions (-F file, Co-Authored-By trailer), and the don'ts (no `git init` under $HOME, no force-pushing the public remote).
---

# dotfiles-repo

Operational notes for LLM agents working in the ajilty dotfiles repo. Read this *before* poking at git state — the conventions here are non-obvious and a few will look like bugs if you don't know them.

## Overview

This skill applies when the working tree is `$HOME` and git operations target the bare repo at `~/.dotfiles/`. Every git invocation must point at both — the `dotfiles` shell alias handles this. The `.gitignore` is an inverse allowlist, identity is enforced by a pre-commit hook, and `dotfiles pull` is a rebase with autostash that can leave the repo mid-rebase. Each of these surprises has a documented resolution path below.

## Checklist

- Always use the `dotfiles` alias (or `dotfiles-shell`), never plain `git`.
- For *new* files use `dotfiles add -f <path>`; for *tracked* files prefer `dotfiles add -u <path>` to suppress the "paths are ignored" warning.
- Never `--no-verify`, never `--author=`, never `GIT_AUTHOR_*` — fix the includeIf instead.
- Commit multi-line messages via `dotfiles commit -F <file>`; end LLM-assisted commits with the `Co-Authored-By:` trailer.

## Repo shape

This is a **bare git repo** at `~/.dotfiles/` with `$HOME` as the work tree. There is no `.git` directory in `~`. Every command must specify both:

```bash
git --git-dir=$HOME/.dotfiles --work-tree=$HOME <subcommand>
```

The `dotfiles` shell alias expands to exactly that. `~/.zshrc` defines it; in non-interactive contexts (where aliases don't expand) you must spell it out, or use `dotfiles-shell` which exports `GIT_DIR` and `GIT_WORK_TREE` for the rest of the shell.

Useful aliases (defined in `~/.zshrc` / `~/.config/shell/`):
- `dotfiles` — the bare-repo git wrapper
- `dotfiles-tracked` — `git ls-tree -r master --name-only`
- `dotfiles-update` — `dotfiles pull; zinit update --all`
- `dotfiles status` — passthrough to `git status` against the bare repo

## Gitignore mechanics (the #1 source of agent confusion)

`.gitignore` uses an **inverse-allowlist pattern**:

```
*                # ignore everything
!.agents/        # ...except the agent skills tree
!.agents/**
.agents/**/.DS_Store      # but re-ignore cruft inside it
.agents/**/__pycache__/
```

Three consequences you will hit:

1. **`git add` warns "paths are ignored" even for already-tracked files.** Because `*` matches everything, files like `.claude/settings.json` and `.config/ghostty/config.ghostty` look ignored to git's add-warning system *even though they're tracked*. Use one of:
   - `dotfiles add -u <path>` — only updates already-tracked files, no warning.
   - `dotfiles add -f <path>` — force-add, needed when adding a *new* file in an ignored directory.
2. **Global `~/.config/git/ignore` is short-circuited inside this repo.** The repo-level `*` matches before git consults the global file. So a file like `__pycache__/foo.pyc` is *not* filtered by your global ignore once it lands under `.agents/` — the `!.agents/**` allowlist re-includes it. Cruft filters under `.agents/` must live in this repo's `.gitignore`, not the global file.
3. **Any new file needs `-f` (or an explicit `!` rule).** Not just top-level — also new files inside already-tracked subtrees like `.ssh/config.d/`, `.claude/`, `.config/...`. `git status` will silently omit them until you force-add. Pattern: `dotfiles add -f .ssh/config.d/<newfile>`. README.md, AGENTS.md, etc. are tracked because they were force-added once.

## Identity is enforced by a pre-commit hook

`core.hooksPath = ~/.dotfiles-hooks` (set in `.config/git/dotfiles.config`, included via `[includeIf "gitdir:~/.dotfiles/"]` in `~/.config/git/config`). The `pre-commit` hook refuses any commit whose author or committer isn't `ajilty <github@ajilty.com>`.

- **Don't `--no-verify`.** If the hook trips, the includeIf isn't matching — usually because `GIT_DIR` is unset or the user-level git config isn't loaded. Diagnose with `dotfiles config --show-origin user.email`.
- **Don't pass `--author=` or set `GIT_AUTHOR_*` env vars** to "fix" identity at commit time. Fix the include block instead.

## `dotfiles pull` can leave merge state

`dotfiles pull` is `git pull --rebase --autostash` (`pull.rebase=true`, `rebase.autostash=true` are set per-repo). Two flavors of conflict are possible and they look similar but behave differently:

- **Autostash-pop conflict** — the rebase finished, but reapplying the pre-pull dirty worktree conflicts. No active rebase metadata in `.dotfiles/rebase-merge/`.
- **Real rebase replay conflict** — a local commit replayed onto the fetched tip conflicts. `.dotfiles/rebase-merge/` exists with `msgnum`/`end`/`onto`/`orig-head`/`stopped-sha` and `git branch` reports `(no branch, rebasing master)`.

While any path is `UU`/`DU`/`UD`, **git refuses every commit, including unrelated ones**. Resolution:

1. Inspect: `dotfiles status`, `cat .dotfiles/rebase-merge/{stopped-sha,message}` if present, and `git show <stopped-sha>` to see what the replay was trying to apply.
2. Resolve each path. `add -f <file>` for modify-modify; `dotfiles rm -f <file>` to accept upstream's deletion (e.g. when upstream restructured — **always check whether content moved before assuming data loss**: `git grep <keyword> <upstream-tip> -- <related-dir>/`).
3. Continue: `dotfiles rebase --continue` (use `-c core.editor=true` from non-interactive contexts to skip the editor prompt).

**Gotcha — `rebase --continue` refuses with "you must edit all merge conflicts" even when nothing is unmerged.** Check `git update-index --refresh` output — if it lists an unrelated path as `needs update` (commonly `.claude/settings.json`), the dirty unstaged file is blocking the next commit step. Park it (`cp` it aside, `dotfiles checkout -- <file>`, continue rebase, restore the copy) and retry.

**Gotcha — stray top-level `MERGE_MSG` from a prior failed pull.** It can confuse diagnostics (looks like an active merge), but it's only a leftover. Safe to `rm` if there's no `MERGE_HEAD` next to it and `.dotfiles/rebase-merge/` has its own `message`.

## Content guard (blocklist) needs bootstrap per machine

The `pre-commit` hook also scans the staged diff against a private blocklist fetched from a gist. On a fresh machine you'll see `WARN: dotfiles blocklist not initialized` — the commit still goes through (warn, not block), but the content scan is skipped.

One-time setup on each new machine:

```bash
mkdir -p ~/.local/config/dotfiles
echo "<private-gist-id>" > ~/.local/config/dotfiles/gist-id
chmod 600 ~/.local/config/dotfiles/gist-id
dotfiles-blocklist-sync
```

The gist must contain a file literally named `dotfiles-blocklist.txt`. After 30 days the local copy is considered stale (warns but still scans); re-run `dotfiles-blocklist-sync` to refresh.

## Commit messages

Pre-commit doesn't block on message content, but the hook runs `set -euo pipefail`, so commit via `-F <file>` (heredoc into a temp file) for multi-line messages — inline `$(cat <<'EOF' ... EOF)` heredocs interact badly with the wrapper alias in some shells.

```bash
dotfiles commit -F /tmp/msg.txt
```

End the message with the standard co-author trailer when an LLM contributed:

```
Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```

## What lives where

- `~/.gitignore` — repo-level ignores (the inverse-allowlist).
- `~/.config/git/ignore` — global ignores (consulted only when no repo-level rule matches; tracked in this repo so it deploys to every machine).
- `~/.config/git/dotfiles.config` — per-repo overrides (hooksPath + identity), included via `[includeIf "gitdir:~/.dotfiles/"]`.
- `~/.dotfiles-hooks/` — the hooks dir referenced by the includeIf above.
- `~/.agents/skills/` — vendored agent skills tree, intentionally tracked despite the global `*` ignore. New skills installed via `skills add` show up in `git status` automatically.
- `~/.claude/settings.json` — Claude Code user settings (tracked).
- `~/.claude/settings.local.json` — local-only overrides (gitignored globally via `**/.claude/settings.local.json` in `~/.config/git/ignore`).

## Anti-patterns

- Don't `git init` anywhere under `~`. Subdirectories under `$HOME` are part of the dotfiles work tree.
- Don't push without confirming with the user. The remote is public.
- Don't commit `.agents/.claude/`, `.agents/**/.DS_Store`, or `.agents/**/__pycache__/` — they're filtered by re-ignore rules but can still be force-added by accident.
- Don't trust `git status` from a subdirectory unless you've used the `dotfiles` alias or set `GIT_DIR`/`GIT_WORK_TREE`. Plain `git status` will look for a `.git` and find nothing useful.
