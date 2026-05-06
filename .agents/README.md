# Shared agent skills

This directory is the canonical home for **agent skills** shared across every
agent CLI on this machine — Claude Code, Codex, Gemini CLI, GitHub Copilot,
and anything else that adopts the `.agents/skills/` convention.

```
~/.agents/
├── README.md            ← you are here
├── .skill-lock.json     ← npx skills lockfile (unreliable; informational)
└── skills/
    ├── find-skills/
    ├── skill-creator/
    └── ...
```

## How each agent CLI discovers these skills

| CLI | Discovery mechanism | Symlink in dotfiles? |
|---|---|---|
| **Claude Code** | Reads `~/.claude/skills/` only | `~/.claude/skills` → `../.agents/skills` (tracked) |
| **Codex** | Reads `$HOME/.agents/skills` natively as `USER` scope (current docs) | None needed |
| **Gemini CLI** | Reads `~/.agents/skills/` natively as user-scope alias | None needed |
| **GitHub Copilot CLI** | Reads `~/.agents/skills/` natively as personal scope | None needed |

Codex's bundled `SYSTEM` skills (skill-creator, skill-installer, openai-docs,
imagegen, plugin-creator) live at `~/.codex/skills/.system/` and are managed by
the Codex installer — never replace `~/.codex/skills` with a parent symlink to
this directory or those system skills will disappear from Codex's discovery.

## Adding a skill

The `skills` shell function (in `~/.config/shell/functions.d/skills.sh`)
wraps `npx skills` so installs land only in the canonical `.agents/skills/`
location — never fanning out per-agent symlinks:

```sh
skills add anthropics/skills@find-skills -g    # user-scope (~/.agents/skills/)
skills add anthropics/skills@find-skills       # project-scope (<cwd>/.agents/skills/)
```

Under the hood: `npx skills add -a kimi-cli -y "$@"`. The `-a kimi-cli` is
a **sentinel** — kimi-cli isn't a recognized agent in the CLI's registry,
so the per-agent symlink branch becomes a no-op. Pass `-g` (or `--global`)
yourself when you want a user-scope install; omit it for project scope.

After `skills add`, the new directory shows up in `git status` because the
top-level `.gitignore` un-ignores `.agents/**`. Stage and commit normally.

## Bootstrap on a fresh machine

1. Clone the dotfiles repo (the contents of `.agents/` come down with it).
2. Claude Code uses the tracked `~/.claude/skills` symlink — already in place.
3. The other CLIs find skills natively; no further action needed.

There is **no** `skills link` step required for normal use. The function
provides one for legacy multi-agent setups but it would clobber Codex's
`.system/` directory, so don't run it for Codex.

## The lockfile

`~/.agents/.skill-lock.json` is written by `npx skills` and tracks "which
skill came from where." It has been observed to go stale (e.g. recording a
skill that has since been removed). Treat it as informational; the source of
truth is the actual content under `~/.agents/skills/`. `npx skills
experimental_install` exists to restore from a lockfile but is marked
experimental — not relied on here.
