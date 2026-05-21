# AGENTS.md

Operational notes for this dotfiles repo have moved to the `dotfiles-repo` skill at [`.agents/skills/dotfiles-repo/SKILL.md`](.agents/skills/dotfiles-repo/SKILL.md). Agents with skill auto-discovery (Claude Code, Codex, Gemini CLI, Copilot CLI) load it on demand; the description triggers on bare-repo cues, the `dotfiles` alias, inverse-allowlist `.gitignore`, the `ajilty <github@ajilty.com>` pre-commit identity hook, and `dotfiles pull` rebase/autostash conflicts.

**Homegrown skills.** Source-of-truth lives at `~/skills/<name>/SKILL.md` (gitignored), canonical install at `~/.agents/skills/<name>/SKILL.md` (tracked, restored by the dotfiles checkout). Sync source → canonical with the `skills-sync` helper (`~/bin/skills-sync`, on `PATH`):

```sh
skills-sync              # sync every ~/skills/<name>/SKILL.md
skills-sync <name>...    # sync specific skills
```

`bin/setup-dotfiles.sh` calls it once during bootstrap. See [`skills/README.md`](skills/README.md) for workspace conventions, the edit→sync→commit loop, and the layout rationale.

Quick digest for tools that auto-load `AGENTS.md` but don't read skills:

- Bare repo at `~/.dotfiles`, worktree `$HOME`. Use the `dotfiles` alias, never plain `git`.
- `.gitignore` is inverse-allowlist (`*` + `!.agents/**`): `dotfiles add -u` for tracked files, `dotfiles add -f` for new ones outside `.agents/`.
- Pre-commit hook enforces author `ajilty <github@ajilty.com>`; never `--no-verify` or `--author=`.
- `dotfiles pull` is `git pull --rebase --autostash`; see the skill for conflict recovery (autostash-pop vs replay, the `update-index --refresh` gotcha).
- Multi-line commit messages: `dotfiles commit -F <file>`. Public remote — don't push without user confirmation.
