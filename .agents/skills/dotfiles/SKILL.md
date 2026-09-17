---
name: dotfiles
description: >-
  Use BEFORE changing any user-level config on this machine and when working in the ajilty dotfiles bare git repo at ~/.dotfiles (worktree $HOME, `dotfiles` command). Intent triggers: editing shell config or anything under ~/.config, ~/.claude, ~/bin, or ~/.agents; creating new user config files; installing or removing Homebrew packages (brew-sync flow); tracking new dotfiles. Symptom triggers: `dotfiles add` warning paths-are-ignored on tracked files, the pre-commit hook rejecting commits whose author is not ajilty (github@ajilty.com), `dotfiles pull` leaving UU/DU paths or mid-rebase --autostash state with `.dotfiles/rebase-merge/`, "WARN dotfiles blocklist not initialized" on a fresh machine, `dotfiles doctor` reporting BROKEN under hook portability or an agent tool (moshi, herdr) claiming its hooks are out of date, or confusion at the inverse-allowlist .gitignore pattern (`*` plus `!` rules). Also covers committing the tracked Neovim config at ~/.config/nvim.
---

# dotfiles

Operational notes for LLM agents working with the ajilty dotfiles system: a bare git repo at `~/.dotfiles/` with `$HOME` as the work tree, managed through the `dotfiles` command. The conventions are non-obvious and a few will look like bugs if you don't know them.

**First stop: run `dotfiles help`.** The command (a script at `~/bin/dotfiles`, works in non-interactive shells, bash and zsh alike) documents day-to-day usage itself: staging rules (`add -u` vs `track`), identity rules, commit mechanics, the pull-recovery quickstart, and the current subcommand list (run it; the list grows). Unrecognized subcommands pass through to git with the right `--git-dir`/`--work-tree`. Never use plain `git` against `$HOME`. This file only covers what the help screen can't: recovery depth, skill management, and system layout.

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

**Squash-merged PR replay (add/add on a file you authored).** When your local commits were squash-merged upstream, the end state matches but the rebase replays the originals one at a time, and the first stops on add/add against the squash. Confirm the stopped commit's files are identical between your pre-pull tip (`dotfiles reflog`) and upstream: `dotfiles diff --stat @{u} <old-tip> -- <paths>` empty. Then `dotfiles -c core.editor=true rebase --skip`; git drops the remaining picks as "patch contents already upstream" and pops the autostash. `dotfiles preflight` predicts this case before the pull and prints the same instruction; `dotfiles preflight <old-tip> <upstream-tip>` replays a past one.

**Gotcha: `rebase --continue` refuses with "you must edit all merge conflicts" though nothing is unmerged.** Check `git update-index --refresh`: if it lists an unrelated dirty path as `needs update` (commonly `.claude/settings.json`), that unstaged file blocks the next commit step. Park it (`cp` aside, `dotfiles checkout -- <file>`, continue, restore).

**Gotcha: stray top-level `MERGE_MSG` from a prior failed pull** looks like an active merge but is leftover. Safe to `rm` if there's no `MERGE_HEAD` beside it and `.dotfiles/rebase-merge/` has its own `message`.

## Content guard (blocklist) bootstrap

The pre-commit hook scans staged diffs against a private blocklist fetched from a gist. On a fresh machine, `WARN: dotfiles blocklist not initialized` means the scan is skipped (commits still pass). One-time setup:

```bash
mkdir -p ~/.local/config/dotfiles
echo "<private-gist-id>" > ~/.local/config/dotfiles/gist-id
chmod 600 ~/.local/config/dotfiles/gist-id
dotfiles blocklist sync
```

The gist must contain a file literally named `dotfiles-blocklist.txt`. After 30 days the local copy goes stale (warns, still scans); re-run `dotfiles blocklist sync`.

**History scan.** The hook only checks staged added lines, so a pattern added to the blocklist *after* a matching string was committed is never re-checked. `dotfiles blocklist scan` (run automatically after every `dotfiles blocklist sync`) greps the entire history, all refs, against the blocklist and fails loudly on a hit. On a hit: fix the worktree file first (or the string re-enters history on the next commit), then scrub with `git filter-repo --replace-text` on a fresh mirror clone, verify (`git log --all -S <pattern>` and `git grep -iF <pattern> $(git rev-list --all)` both empty), and force-push only with explicit user confirmation. GitHub keeps old SHAs and read-only `refs/pull/*` fetchable until a support purge; note that residual in the wrap-up.

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
- **Authored skills have two lanes.** Portable skills are authored in the agentic repo (`~/gits/github.com/ajilty/agentic/skills/`) and distributed as plugins via the ajilty marketplace; that repo's guards plugin lints frontmatter on write. Machine-specific skills (like this one) live directly in the live store at `~/.agents/skills/<name>/SKILL.md`, tracked in the dotfiles repo: edit in place (Claude Code hot-loads it), `dotfiles add -u`, commit. There is no separate source copy and no sync step; local hand-authored skills never appear in the CLI lockfile.
- **New machine-specific skill**: create `~/.agents/skills/<name>/SKILL.md`, then `dotfiles track .agents/skills/<name>/`. Portable skills go to the agentic repo instead.
- **Authoring scratch stays out of the store**: eval artifacts, drafts, and snapshots don't belong under `~/.agents/skills/` (everything there is tracked); keep them anywhere else in `$HOME`, which the inverse-allowlist ignores by default.
- **Heavy skills** (multi-MB doc bundles) bloat the repo; confirm with the user before installing. Security scanner ratings in the install summary vary; treat "High Risk" as a prompt to skim the SKILL.md, not an automatic block.

## Neovim config

`~/.config/nvim/` is a LazyVim-based config, tracked. It began as a `LazyVim/starter` clone with `.git` removed: never re-clone the starter over it or `git init` inside it.

- Tracked: `init.lua`, `lua/**`, `stylua.toml`, `lazy-lock.json`, `CHEATSHEET.md`. New plugin specs under `lua/plugins/` need `dotfiles track` like any new file.
- NOT tracked, never should be: `~/.local/share/nvim/`, `~/.local/state/nvim/`, `~/.cache/nvim/`. Regenerates from `lazy-lock.json` (`nvim --headless "+Lazy! sync" +qa`).
- `lazy-lock.json` is a lockfile: stage with `add -u` and commit so machines pin identical plugin versions.
- Brew deps in `Brewfile.dev`: `neovim`, `tree-sitter-cli` (the `tree-sitter` formula is only the C library, no binary), `fd` (Snacks explorer hardcodes it), `lazygit`. `:checkhealth config` verifies.

## When a vendor installer rewrites our hook configs

moshi-hook and herdr both regenerate `~/.claude/settings.json` and
`~/.codex/hooks.json` and bake in the path the tool lived at that release.

**Upgrading is safe; `moshi-hook install` is what clobbers.** Moshi's docs are
explicit: "Pairing and installed agent hooks survive an upgrade, so there is no
need to re-pair or re-run `moshi-hook install`." The Homebrew formula has no
`post_install`, so `brew upgrade` never touches the configs either. Only an
explicit `moshi-hook install` rewrites them, and when it does it "rewrites the
current hook set, removes retired events" rather than merging, so every
hand-edit in its own entries is lost.

**Ignore the stale-hooks nag. It is permanent and it is about us.** The daemon
logs `agent hooks missing or stale; rerun install` by comparing the command
*strings* it wrote against what is in the config, not the set of events. Our
`command -v` rewrite will never match, so the warning fires forever and is not
evidence that anything changed. Running install to silence it re-pins every
path, which is the exact loop this section exists to break. Never run
`moshi-hook install` just to clear that warning.

**The signal is still recoverable, without running install.** `moshi-hook
status --json` lists a `missing[]` per target, and the entries read
"<Event> entries outdated". Today every event it names is one we already have
a moshi entry for, and it names nothing we lack, which is the string mismatch
talking. So an event it names that we have *no* entry for is the real thing:

```sh
for pair in "claude:$HOME/.claude/settings.json" "codex:$HOME/.codex/hooks.json"; do
    target="${pair%%:*}"; cfg="${pair#*:}"
    comm -13 \
      <(jq -r '.hooks | to_entries[]
               | select(any(.value[]?.hooks[]?.command // ""; test("moshi-hook")))
               | .key' "$cfg" | sort) \
      <(moshi-hook status --json \
          | jq -r --arg t "$target" '.hooks[] | select(.target==$t) | .missing[]' \
          | sed 's/ entries .*//' | sort) \
      | sed "s/^/$target: new event /"
done
```

Silence means the nag is only about our rewrite and there is nothing to do.
A named event is worth adding by hand, in the canonical form below, which
costs one entry and avoids the rewrite-and-revert cycle entirely.

If you would rather let the installer do it, that is still safe on the live
config: run `moshi-hook install`, read `dotfiles diff` to see every entry it
rewrote, re-normalize each one, and let `dotfiles doctor` confirm. The
pre-commit guard blocks the commit until they resolve at run time again, so a
half-finished pass cannot reach the repo.

Two things catch the drift, neither of which fixes it. `dotfiles doctor` reports
it under "hook portability" whenever you run it. The pre-commit hook blocks the
commit outright if a re-pinned config is staged, which is the backstop that
matters: nothing prompts you to run the doctor at the moment a config gets
rewritten.

The drill either way: rewrite each command the check names to resolve at run
time, keeping whatever `matcher`, `async`, and `timeout` fields the installer
set. Two canonical forms, and everything in these files should be one of them:

```sh
# third-party binary: resolve from PATH, no-op when not installed
h="$(command -v moshi-hook 2>/dev/null)"; [ -n "$h" ] && "$h" claude-hook || true
# our own script: $HOME-relative, no-op when the file is absent
s="$HOME/.claude/hooks/herdr-agent-state.sh"; [ -f "$s" ] && bash "$s" session || true
```

Both fail open on purpose: a machine without the tool runs the hook as a no-op
rather than erroring every event. Note that herdr's state script is *not*
tracked here, so on a fresh machine that second form is load-bearing.

An installer-written `"$HOME/.local/bin/<tool>"` looks portable and isn't: it
survives a new machine but breaks the next time the tool moves. `command -v`
also makes the install method a non-issue, which matters for moshi-hook
specifically: it ships both as a Homebrew formula (`rjyo/moshi/moshi-hook`,
tracked in `Brewfile.ai`) and as a `curl | sh` installer that drops it in
`~/.local/bin`. Same hook entry works for either.

Known exception: the `runlayer` entries are pinned to its uv tools directory.
Left as-is deliberately, since it's $HOME-relative and guarded, and `command -v`
would assume the shim is on PATH. Revisit if it ever breaks.

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
