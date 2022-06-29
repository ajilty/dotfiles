Configuration files for many of the tools that I including.:
- docker kubectl aws gcloud
- go
- git

# Requirements
- zsh 
- jinga2 (for .aws templates)

Install on macOS
```bash
sudo port install -y zsh py38-jinja2
```
Install on Ubuntu/Debian
```
sudo apt install -y zsh python-jinja2
```

# Guide

## Setup

One new machines, the following commands will set these dot files
They are careful not to overrite files if they already exit. 
You can modify this behavior with flags to the `reset` command.

An alias to `config` should be used after initial set-up
```
cd ~
git clone --bare https://github.com/ajilty/dotfiles.git $HOME/.dotfiles
git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME fetch --all
git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME reset --merge
git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME submodule update --force --recursive --init --remote
```
## Add

By default, files are not tracked. To add more files to be tracked or to add changes of existing tracked files:
```bash
cd ~
config add <file or directory to add>
config commit <msg>
config push
```

## Update 

To pull updates from sub modules (like zsh plug-ins and themes)
```
cd ~
config submodule update --force --recursive --init --remote
```

# Resource
- https://www.atlassian.com/git/tutorials/dotfiles
- https://shreevatsa.wordpress.com/2008/03/30/zshbash-startup-files-loading-order-bashrc-zshrc-etc/
