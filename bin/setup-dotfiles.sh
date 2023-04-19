#!/bin/bash

# Check if git is installed
if ! [ -x "$(command -v git)" ]; then
    echo 'Error: git is not installed.' >&2
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

cd ~
git clone --bare https://github.com/ajilty/dotfiles.git $HOME/.dotfiles

# Install dotfiles and submodules
git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME fetch --all
git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME reset --hard
git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME submodule update --force --recursive --init --remote

# Restart terminal
exec zsh