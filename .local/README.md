# Local Overrides & Additions

## Configurations
- `~/.local/config/git/config` (file) Automatically` included by `~/.config/git/config`
- `~/.local/config/shell/environment` (file) Automatically includes `environment` by `~/.config/shell/environment`
- `~/.local/config/ssh/*` (files in directory) Automatically included by ~/.ssh/config

## Binaries
- `~/.local/bin/*` (files in directory) Automatically included by `~/.config/shell/environment`

If you have your own `.local` configs in a synced folder, link it like this: `ln -s "$(pwd)" "$HOME/.local/config" `

## Scoped overrides on top of `.local`

`~/.local/config/git/config` provides the *baseline* git identity (typically the work account, since `.local` follows whichever cloud-storage account is synced). For specific repos that should use a different identity, `~/.config/git/config` declares `[includeIf]` blocks evaluated *after* the unconditional `.local` include, so they override the baseline:

- `gitdir:~/.dotfiles` → `~/.config/git/dotfiles.config` → ajilty identity + `core.hooksPath = ~/.dotfiles-hooks` (pre-commit allowlist guards against work-identity commits leaking in)
- `gitdir:~/gits/github.com/ajilty/` → `~/.config/git/identity.config` → ajilty identity

To add another scope, drop a new `[includeIf]` block in `~/.config/git/config` pointing at the appropriate fragment under `~/.config/git/`.
