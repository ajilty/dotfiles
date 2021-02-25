# Requirements
- zsh 

# Guide
```
git clone --bare https://github.com/ajilty/dotfiles.git $HOME/.dotfiles
git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME fetch --all
git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME reset --mixed master
git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME submodule update --force --recursive --init --remote
```
