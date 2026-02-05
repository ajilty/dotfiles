# Dotfiles

## Requirements

- `zsh`
- `git`
- `curl` or `wget`, also `rsync` (for [Zinit](https://github.com/zdharma-continuum/zinit))

See [test/Brewfile](test/Brewfile) for other dependencies used in this dotfiles setup.

## Setup

On new machines, the following commands will set these dotfiles
They are careful not to overwrite files if they already exist.
You can modify this behavior with flags to the `reset` command.

An alias to `dotfiles` should be used **after** this set-up

### Quick
`bash -c "$(curl -fsSL https://raw.githubusercontent.com/ajilty/dotfiles/refs/heads/master/bin/setup-dotfiles.sh)"`


## Interactive
```bash
# start from home directory
cd ~
# clone just the .git directory to a subpath
git clone --bare https://github.com/ajilty/dotfiles.git $HOME/.dotfiles
# fetch without pulling down files
git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME fetch --all
# pull down files, handle conflicts with current go reckless with `reset --hard`
git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME reset --merge
# restart shell
exec zsh
```

## Usage

| Action                | Command                                                                 |
|-----------------------|-------------------------------------------------------------------------|
| View tracked files    | `dotfiles-tracked`                                                      |
| Add tracked files     | `dotfiles add -f <file or directory to add>`<br>`dotfiles commit <msg>`<br>`dotfiles push`                                                                                             |
| Update     | `dotfiles-update`                                                                  |
| Shell    | `dotfiles-shell`                                                         |

Also see [Zinit commands](https://github.com/zdharma-continuum/zinit?tab=readme-ov-file#zinit-commands)

## Testing

Local sandbox (creates `test/sandbox-<timestamp>` and keeps it for inspection):

```bash
./test/sandbox-run.sh
```

Container-based (requires Docker or Podman):

```bash
./test/container-run.sh ubuntu
./test/container-run.sh fedora
./test/container-run.sh amazonlinux
```

The test dependencies are defined in `test/Brewfile`.

# Resources

- https://www.atlassian.com/git/tutorials/dotfiles
- https://shreevatsa.wordpress.com/2008/03/30/zshbash-startup-files-loading-order-bashrc-zshrc-etc/
- https://github.com/zdharma-continuum/zinit
