# `~/skills` — homegrown skill workspace

Source-of-truth directory for custom agent skills. Each skill source under
`~/skills/<name>/SKILL.md` is installed into the canonical store at
`~/.agents/skills/<name>/SKILL.md`, which is what's tracked in the dotfiles
repo and what agents (Claude Code, Codex, Gemini CLI, Copilot CLI) load.

## Layout

| Path | Tracked? | Purpose |
| --- | --- | --- |
| `~/skills/<name>/SKILL.md` | No (gitignored) | Source you edit |
| `~/skills/<name>-workspace/` | No (gitignored) | Eval artifacts, drafts, snapshots — no `SKILL.md`, so `skills-sync` ignores it |
| `~/skills/README.md` | Yes (force-tracked) | This file |
| `~/.agents/skills/<name>/SKILL.md` | Yes | Canonical install target; what agents read |
| `~/bin/skills-sync` | Yes | Helper that pushes source → canonical |

The whole `~/skills/` tree is gitignored by the dotfiles inverse-allowlist
(`*` + `!.agents/**`) *except* for specific files force-added with
`dotfiles add -f` (this README, and any future workspace-level config).

## Development loop

When you edit (or create) a skill source:

```sh
$EDITOR ~/skills/<name>/SKILL.md          # change the source
skills-sync <name>                         # push source → canonical
cd ~ && dotfiles status                    # see modified .agents/skills/<name>/SKILL.md
dotfiles add .agents/skills/<name>/SKILL.md
dotfiles commit -F /tmp/msg                # multi-line via -F (pre-commit hook checks author)
dotfiles push                              # public remote — confirm before pushing
```

For a new skill, `mkdir ~/skills/<name>/` and write its `SKILL.md`, then the
same loop. `skills-sync` (no args) discovers every subdirectory containing a
`SKILL.md` and installs them all in one `npx skills add` invocation.

## `skills-sync`

```
skills-sync              # sync every ~/skills/<name>/SKILL.md
skills-sync <name>...    # sync only the named skills
```

Installed at `~/bin/skills-sync` (on `PATH`). Wraps:

```sh
npx skills add ~/skills -s <name>... -g -a claude-code -y
```

Called once near the end of `bin/setup-dotfiles.sh` during fresh-machine
bootstrap — a no-op on a clean clone (the canonical store is already
restored by the `dotfiles` checkout), but useful if `~/skills/` is later
restored from a backup or another machine.

## Why this layout

- **Source ≠ install target.** Lets the same skill source serve multiple
  agents (Claude Code today, others tomorrow) via `npx skills add -a <agent>`,
  without baking agent-specific paths into the source.
- **`.agents/skills/` is tracked, `~/skills/` isn't.** The canonical install
  is what every machine needs identically; the source workspace can carry
  eval artifacts and in-flight drafts that shouldn't enter version control.
- **Per-file force-tracking exceptions** (README, helper script if relocated
  here) follow the same precedent as `.config/shell/functions.d/brew-sync.sh`
  — selective tracked files inside an otherwise-ignored tree.

## See also

- `CLAUDE.md` / `AGENTS.md` at `$HOME` — top-level operational notes; points
  here for skill-workspace specifics
- `~/.agents/skills/dotfiles-repo/SKILL.md` — the dotfiles bare-repo workflow
  used in the development loop above
