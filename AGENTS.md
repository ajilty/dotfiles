# AGENTS.md

Operational notes for LLM agents working in this dotfiles repo. Read this *before* poking at git state — the conventions here are non-obvious and a few will look like bugs if you don't know them.

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
3. **New top-level files need either `-f` or an explicit `!` rule.** README.md, AGENTS.md, etc. are tracked because they were added with `-f`. If you add a new top-level doc, do the same.

## Identity is enforced by a pre-commit hook

`core.hooksPath = ~/.dotfiles-hooks` (set in `.config/git/dotfiles.config`, included via `[includeIf "gitdir:~/.dotfiles/"]` in `~/.config/git/config`). The `pre-commit` hook refuses any commit whose author or committer isn't `ajilty <github@ajilty.com>`.

- **Don't `--no-verify`.** If the hook trips, the includeIf isn't matching — usually because `GIT_DIR` is unset or the user-level git config isn't loaded. Diagnose with `dotfiles config --show-origin user.email`.
- **Don't pass `--author=` or set `GIT_AUTHOR_*` env vars** to "fix" identity at commit time. Fix the include block instead.

## `dotfiles-update` can leave merge state

`dotfiles-update` does `dotfiles pull` which uses `--autostash`. If the stash pop conflicts with incoming changes (most commonly on `.claude/settings.json` because both local and upstream evolve it), you'll see `UU <file>` in `dotfiles status`.

While any path is `UU`, **git refuses every commit, including unrelated ones**. Resolve first:

1. Check the file — autostash often resolves cleanly in-place with no conflict markers, in which case `dotfiles add -f <file>` clears the `UU` and you're done.
2. If markers are present, edit them out, then `dotfiles add -f <file>`.
3. Then proceed with whatever else you were committing.

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

## Don'ts

- Don't `git init` anywhere under `~`. Subdirectories under `$HOME` are part of the dotfiles work tree.
- Don't push without confirming with the user. The remote is public.
- Don't commit `.agents/.claude/`, `.agents/**/.DS_Store`, or `.agents/**/__pycache__/` — they're filtered by re-ignore rules but can still be force-added by accident.
- Don't trust `git status` from a subdirectory unless you've used the `dotfiles` alias or set `GIT_DIR`/`GIT_WORK_TREE`. Plain `git status` will look for a `.git` and find nothing useful.
