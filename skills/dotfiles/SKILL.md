---
name: dotfiles
description: >-
  Use BEFORE changing any user-level config on this machine and when working in the ajilty dotfiles bare git repo at ~/.dotfiles (worktree $HOME, `dotfiles` command). Intent triggers: editing shell config or anything under ~/.config, ~/.claude, ~/bin, ~/.agents, or ~/skills; creating new user config files; installing or removing Homebrew packages (brew-sync flow); tracking new dotfiles. Symptom triggers: `dotfiles add` warning paths-are-ignored on tracked files, the pre-commit hook rejecting commits whose author is not ajilty (github@ajilty.com), `dotfiles pull` leaving UU/DU paths or mid-rebase --autostash state with `.dotfiles/rebase-merge/`, "WARN dotfiles blocklist not initialized" on a fresh machine, or confusion at the inverse-allowlist .gitignore pattern (`*` plus `!` rules). Also covers committing the tracked Neovim config at ~/.config/nvim.
---

# dotfiles

Operational notes for LLM agents working with the ajilty dotfiles system: a bare git repo at `~/.dotfiles/` with `$HOME` as the work tree, managed through the `dotfiles` command. The conventions are non-obvious and a few will look like bugs if you don't know them.

**First stop: run `dotfiles help`.** The command (a script at `~/bin/dotfiles`, works in non-interactive shells, bash and zsh alike) documents day-to-day usage itself: staging rules (`add -u` vs `track`), identity rules, commit mechanics, the pull-recovery quickstart, and subcommands (`tracked`, `track`, `update`). Unrecognized subcommands pass through to git with the right `--git-dir`/`--work-tree`. Never use plain `git` against `$HOME`. This file only covers what the help screen can't: recovery depth, skill management, and system layout.

## Improve this system when it fails you

If you hit a gap, a wrong instruction, or an undocumented edge (in this skill, in `dotfiles help`, or in the `dotfiles hook` guard), propose a concrete fix in your wrap-up: the exact text or code change, and where it goes. Prefer moving day-to-day facts into `dotfiles help` (the tool documents itself); reserve this skill for recovery procedures and conventions. Don't silently work around a documentation failure: the workaround dies with your session, the fix compounds.

## Gitignore mechanics beyond the help screen

`.gitignore` is an inverse allowlist: `*` ignores everything, `!` rules re-include whole trees (`!.agents/**`, `!skills/**`), and re-ignore rules filter cruft back out inside them. Two consequences `dotfiles help` doesn't cover:

1. **Global `~/.config/git/ignore` is short-circuited inside this repo.** The repo-level `*` matches before git consults the global file, and `!.agents/**` re-includes everything under `.agents/` including cruft your global ignore would normally filter. Cruft filters for `.agents/` must live in this repo's `.gitignore`.
2. **`track` (add -f) vs editing `.gitignore` solve opposite problems.** To *include* a new file hidden by `*`: `dotfiles track` (never a one-off `!` rule; the existing `!` rules cover whole trees deliberately). To *exclude* something an allowlist rule re-included (cruft, or an installed duplicate of a homegrown skill): add a line to the re-ignore block in `~/.gitignore`, and if the path is already tracked, also `dotfiles rm -r --cached <path>` (ignore rules alone never untrack).

## `dotfiles pull` recovery (deep)

`dotfiles pull` is `git pull --rebase --autostash`. While any path is `UU`/`DU`/`UD`, git refuses every commit, including unrelated ones. Two conflict flavors that look similar:

- **Autostash-pop conflict**: the rebase finished, but reapplying the pre-pull dirty worktree conflicts. No `.dotfiles/rebase-merge/` metadata.
- **Real replay conflict**: a local commit replayed onto the fetched tip conflicts. `.dotfiles/rebase-merge/` exists (`msgnum`/`end`/`onto`/`stopped-sha`) and `git branch` reports `(no branch, rebasing master)`.

Resolution:

1. Inspect: `dotfiles status`, `cat .dotfiles/rebase-merge/{stopped-sha,message}` if present, `dotfiles show <stopped-sha>`.
2. Resolve each path: `add -f <file>` for modify-modify; `dotfiles rm -f <file>` to accept upstream's deletion, but **always check whether content moved before assuming data loss**: `dotfiles grep <keyword> <upstream-tip> -- <related-dir>/`.
3. `dotfiles -c core.editor=true rebase --continue` (the `-c` skips the editor prompt in non-interactive contexts).

**Gotcha: `rebase --continue` refuses with "you must edit all merge conflicts" though nothing is unmerged.** Check `git update-index --refresh`: if it lists an unrelated dirty path as `needs update` (commonly `.claude/settings.json`), that unstaged file blocks the next commit step. Park it (`cp` aside, `dotfiles checkout -- <file>`, continue, restore).

**Gotcha: stray top-level `MERGE_MSG` from a prior failed pull** looks like an active merge but is leftover. Safe to `rm` if there's no `MERGE_HEAD` beside it and `.dotfiles/rebase-merge/` has its own `message`.

## Content guard (blocklist) bootstrap

The pre-commit hook scans staged diffs against a private blocklist fetched from a gist. On a fresh machine, `WARN: dotfiles blocklist not initialized` means the scan is skipped (commits still pass). One-time setup:

```bash
mkdir -p ~/.local/config/dotfiles
echo "<private-gist-id>" > ~/.local/config/dotfiles/gist-id
chmod 600 ~/.local/config/dotfiles/gist-id
dotfiles-blocklist-sync
```

The gist must contain a file literally named `dotfiles-blocklist.txt`. After 30 days the local copy goes stale (warns, still scans); re-run `dotfiles-blocklist-sync`.

**History scan.** The hook only checks staged added lines, so a pattern added to the blocklist *after* a matching string was committed is never re-checked. `dotfiles-blocklist-scan` (run automatically after every `dotfiles-blocklist-sync`; both in `~/.config/shell/functions.d/dotfiles.sh`) greps the entire history, all refs, against the blocklist and fails loudly on a hit. On a hit: fix the worktree file first (or the string re-enters history on the next commit), then scrub with `git filter-repo --replace-text` on a fresh mirror clone, verify (`git log --all -S <pattern>` and `git grep -iF <pattern> $(git rev-list --all)` both empty), and force-push only with explicit user confirmation. GitHub keeps old SHAs and read-only `refs/pull/*` fetchable until a support purge; note that residual in the wrap-up.

## Installing agent skills

Skills are managed by the `npx skills` CLI (vercel-labs/skills). Canonical store: `~/.agents/skills/`; `~/.claude/skills` is a symlink to it, so one install serves every agent. Lockfile `~/.agents/.skill-lock.json` (tracked) records source repo, SHA, and install time for CLI-installed skills.

```bash
npx skills add <owner/repo> -g -s <skill-name> -a claude-code -y
# multiple skills from one repo: REPEAT -s, never comma-separate (comma silently fails)
npx skills find <query> | npx skills ls -g | npx skills check | npx skills update | npx skills remove -g -s <name>
```

After install, `dotfiles status` shows lockfile `M` plus a new untracked skill dir. Stage with `dotfiles track .agents/skills/<name>` and `dotfiles add -u .agents/.skill-lock.json`.

Gotchas:

- **Reinstall to register an existing skill**: if a skill is on disk but missing from the lockfile, `rm -rf` both `~/.agents/skills/<name>` and `~/.claude/skills/<name>` first, then `npx skills add`.
- **Stale lockfile entries** (in lockfile, not on disk) don't auto-clean; edit `.skill-lock.json` directly.
- **Authored skills have two lanes.** Portable skills are authored in the agentic repo (`~/gits/github.com/ajilty/agentic/skills/`) and distributed as plugins via the ajilty marketplace; that repo's guards plugin lints frontmatter on write. Machine-specific skills (like this one) stay in `~/skills/<name>/SKILL.md` (tracked via `!skills/**`) and are synced to `~/.agents/skills/<name>/` with `skills-sync` (`~/bin/skills-sync`). The installed copy is a *copy*, not a symlink: edits aren't live until re-synced. Each such installed copy gets a `.agents/skills/<name>/` re-ignore line in `~/.gitignore` so only the source is tracked; local-path installs never appear in the lockfile.
- **New machine-specific skill**: create `~/skills/<name>/SKILL.md`, run `skills-sync <name>`, add the `.agents/skills/<name>/` re-ignore line, stage `skills/<name>/` and the gitignore change. Portable skills go to the agentic repo instead.
- **Authoring workspaces stay local**: `~/skills/<name>-workspace/` dirs are excluded by the `skills/*-workspace/` re-ignore rule; if one shows up in `dotfiles status`, restore the rule, don't force-add.
- **Heavy skills** (multi-MB doc bundles) bloat the repo; confirm with the user before installing. Security scanner ratings in the install summary vary; treat "High Risk" as a prompt to skim the SKILL.md, not an automatic block.

## Neovim config

`~/.config/nvim/` is a LazyVim-based config, tracked. It began as a `LazyVim/starter` clone with `.git` removed: never re-clone the starter over it or `git init` inside it.

- Tracked: `init.lua`, `lua/**`, `stylua.toml`, `lazy-lock.json`, `CHEATSHEET.md`. New plugin specs under `lua/plugins/` need `dotfiles track` like any new file.
- NOT tracked, never should be: `~/.local/share/nvim/`, `~/.local/state/nvim/`, `~/.cache/nvim/`. Regenerates from `lazy-lock.json` (`nvim --headless "+Lazy! sync" +qa`).
- `lazy-lock.json` is a lockfile: stage with `add -u` and commit so machines pin identical plugin versions.
- Brew deps in `Brewfile.dev`: `neovim`, `tree-sitter-cli` (the `tree-sitter` formula is only the C library, no binary), `fd` (Snacks explorer hardcodes it), `lazygit`. `:checkhealth config` verifies.

## What lives where

- `~/bin/dotfiles` — the management command (script; `dotfiles help` for the contract). Its `hook` subcommand is the agent guard, registered as a PreToolUse hook in `~/.claude/settings.json`: reminds agents once per session when they touch managed config, run brew installs, or handle credentials outside `with-secrets`. Informational only, never blocks.
- `~/.gitignore` — repo-level inverse allowlist. `~/.config/git/ignore` — global ignores (tracked; short-circuited inside this repo, see above).
- `~/.config/git/dotfiles.config` — hooksPath + identity, included via `[includeIf "gitdir:~/.dotfiles/"]`; hooks live in `~/.dotfiles-hooks/`.
- `~/.agents/skills/` — canonical skills tree (tracked); `~/.claude/skills` symlinks to it; `~/.agents/.skill-lock.json` — CLI-install manifest (tracked).
- `~/.config/homebrew/Brewfile.*` — categorized package manifests, maintained via `brew-sync`.
- `~/.claude/settings.json` — tracked; `~/.claude/settings.local.json` — local-only (globally ignored).
- `~/.local/config/` — work/local-only config (env presets, dotfiles gist-id); part of the system but intentionally untracked.
- `dotfiles-shell` alias — exports `GIT_DIR`/`GIT_WORK_TREE` for a whole shell when that's more convenient than the wrapper.

## Anti-patterns

- Don't `git init` anywhere under `~`; subdirectories of `$HOME` are part of the dotfiles work tree (nested code checkouts like `~/gits/` have their own repos and are ignored, not part of this one).
- Don't push without confirming with the user: the remote is public.
- Don't `--no-verify`, `--author=`, or `GIT_AUTHOR_*`; if identity fails, diagnose with `dotfiles config --show-origin user.email`.
- Don't trust plain `git status` anywhere under `~`: use `dotfiles`, or `dotfiles-shell` first.
- Don't commit `.agents/.claude/`, `.DS_Store`, or `__pycache__` under `.agents/`; re-ignore rules filter them but force-adds bypass that.
