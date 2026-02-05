#!/bin/bash

# Prerequisite Checks

# Check if git is installed
if ! [ -x "$(command -v git)" ]; then
    echo 'Error: git is not installed.' >&2
    exit 1
fi

# Check for rsync
if ! [ -x "$(command -v rsync)" ]; then
    echo 'Error: rsync is not installed.' >&2
    exit 1
fi

# Check for curl or wget
if ! [ -x "$(command -v curl)" ] && ! [ -x "$(command -v wget)" ]; then
    echo 'Error: curl or wget is not installed.' >&2
    exit 1
fi

# Check if zsh is installed. If it is not installed, figure out which package manager is on the system (either apt, yum, or macports) and install zsh
if ! [ -x "$(command -v zsh)" ]; then
    echo 'Error: zsh is not installed.' >&2
    if [ -x "$(command -v apt)" ]; then
        apt install zsh
    elif [ -x "$(command -v yum)" ]; then
        yum install zsh
    elif [ -x "$(command -v port)" ]; then
        port install zsh
    else
        echo 'Error: Could not find a package manager to install zsh.' >&2
        exit 1
    fi
fi

# Clone the dotfiles repository
DOTFILES_REPO_URL=${DOTFILES_REPO_URL:-"https://github.com/ajilty/dotfiles.git"}
echo "Cloning dotfiles from $DOTFILES_REPO_URL to $HOME/.dotfiles..."
cd ~
git clone --bare "$DOTFILES_REPO_URL" $HOME/.dotfiles

# Install dotfiles and submodules
git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME fetch --all
git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME reset --hard
git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME submodule update --force --recursive --init --remote

# Restart terminal
if [ "${DOTFILES_NO_EXEC_ZSH:-0}" != "1" ]; then
    exec zsh
fi