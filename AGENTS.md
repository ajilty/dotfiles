# AGENTS.md

Operational notes for this dotfiles repo have moved to the `dotfiles-repo` skill at [`.agents/skills/dotfiles-repo/SKILL.md`](.agents/skills/dotfiles-repo/SKILL.md). Agents with skill auto-discovery (Claude Code, Codex, Gemini CLI, Copilot CLI) load it on demand; the description triggers on bare-repo cues, the `dotfiles` alias, inverse-allowlist `.gitignore`, the `ajilty <github@ajilty.com>` pre-commit identity hook, and `dotfiles pull` rebase/autostash conflicts.

**First-time bootstrap on a new machine** (or after any homegrown-skill source/install drift — see the source at [`skills/dotfiles-repo/`](skills/dotfiles-repo/)): the linked path under `.agents/skills/` is *gitignored* and populated by an explicit install step. Run once:

```sh
npx skills add ~/skills -s dotfiles-repo -g -a claude-code -y
```

Repeat with `-s <name>` for every other homegrown skill under `~/skills/`. Without this, the auto-discovery list may still advertise the skill (some harnesses scan `~/skills/` for descriptions), but invocation fails because the canonical store at `~/.agents/skills/<name>/` is empty.

Quick digest for tools that auto-load `AGENTS.md` but don't read skills:

- Bare repo at `~/.dotfiles`, worktree `$HOME`. Use the `dotfiles` alias, never plain `git`.
- `.gitignore` is inverse-allowlist (`*` + `!.agents/**`): `dotfiles add -u` for tracked files, `dotfiles add -f` for new ones outside `.agents/`.
- Pre-commit hook enforces author `ajilty <github@ajilty.com>`; never `--no-verify` or `--author=`.
- `dotfiles pull` is `git pull --rebase --autostash`; see the skill for conflict recovery (autostash-pop vs replay, the `update-index --refresh` gotcha).
- Multi-line commit messages: `dotfiles commit -F <file>`. Public remote — don't push without user confirmation.
