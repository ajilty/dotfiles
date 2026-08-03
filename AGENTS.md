# AGENTS.md

**All user-level config on this machine flows through the dotfiles system**: shell config, `~/.config`, `~/.claude`, `~/bin`, `~/.agents`, package manifests. Before creating or editing any of it, run `dotfiles help` (the `dotfiles` command at `~/bin/dotfiles` is self-documenting and works in non-interactive shells, bash or zsh). Don't fall back to generic defaults for config placement, git usage in `$HOME`, or package installs; hook into this system.

Deeper operational notes live in the `dotfiles-repo` skill at [`.agents/skills/dotfiles-repo/SKILL.md`](.agents/skills/dotfiles-repo/SKILL.md). Agents with skill auto-discovery (Claude Code, Codex, Gemini CLI, Copilot CLI) load it on demand; the description triggers on intent cues (editing user config, installing packages, tracking new dotfiles) and symptom cues (paths-are-ignored warnings, the `ajilty <github@ajilty.com>` pre-commit identity hook, `dotfiles pull` rebase/autostash conflicts). In Claude Code, a PreToolUse hook (`dotfiles hook`, a subcommand of the same script) additionally reminds agents once per session when they touch managed config, run brew installs, or handle credentials outside `with-secrets`.

**Homegrown skills, two lanes.** Portable skills are authored in the `ajilty/agentic` repo (`skills/`) and distributed as plugins via the ajilty marketplace. Machine-specific skills (e.g. `dotfiles-repo`) are authored at `~/skills/<name>/SKILL.md` (tracked here via the `!skills/**` allowlist), with the canonical install at `~/.agents/skills/<name>/SKILL.md` (its per-skill re-ignore rule keeps the copy untracked). Sync source → install with the `skills-sync` helper (`~/bin/skills-sync`, on `PATH`):

```sh
skills-sync              # sync every ~/skills/<name>/SKILL.md
skills-sync <name>...    # sync specific skills
```

`bin/setup-dotfiles.sh` calls it once during bootstrap. See [`skills/README.md`](skills/README.md) for workspace conventions, the edit→sync→commit loop, and the layout rationale.

**Secrets and env presets.** Never hardcode secrets or `op run --env-file=...` invocations. Use `with-secrets <preset> [--] <command>` (`~/bin/with-secrets`, on `PATH`): it resolves `<preset>.env` from `~/.local/config/shell/env.d/` (work, untracked) then `~/.config/shell/env.d/` (personal, tracked) and execs the command through 1Password `op run`, so `op://` references never land in configs. This is the standard for anything that spawns a command with credentials: MCP server entries (`"command": "with-secrets", "args": ["<preset>", ...]`), cron jobs, one-off runs. Interactive shells use the `env <preset>` function to source the same files. To add a credential: create/extend a preset file with `export VAR="op://vault/item/field"`.

Quick digest for tools that auto-load `AGENTS.md` but don't read skills (`dotfiles help` has the full contract):

- Bare repo at `~/.dotfiles`, worktree `$HOME`. Use the `dotfiles` command, never plain `git`.
- `.gitignore` is inverse-allowlist (`*` + `!` rules): `dotfiles add -u` for tracked files, `dotfiles track <path>` for new ones.
- Pre-commit hook enforces author `ajilty <github@ajilty.com>`; never `--no-verify` or `--author=`.
- `dotfiles pull` is `git pull --rebase --autostash`; see the skill for conflict recovery (autostash-pop vs replay, the `update-index --refresh` gotcha).
- Multi-line commit messages: `dotfiles commit -F <file>`. Public remote: don't push without user confirmation.
- Package installs: record with `brew-sync save <category> <pkg>` into `~/.config/homebrew/Brewfile.*`.
