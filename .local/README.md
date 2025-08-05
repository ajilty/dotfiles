# Local Overrides & Additions

## Configurations
- `~/.local/config/git/config` (file) Automatically` included by `~/.config/git/config`
- `~/.local/config/shell/environment` (file) Automatically includes `environment` by `~/.config/shell/environment`
- `~/.local/config/ssh/*` (files in directory) Automatically included by ~/.ssh/config

## Binaries
- `~/.local/bin/*` (files in directory) Automatically included by `~/.config/shell/environment`

If you have your own `.local` configs in a synced folder, link it like this: `ln -s "$(pwd)" "$HOME/.local/config" `
