#!/bin/bash
# 00-xdg: XDG Base Directory Specification and local binaries
# Loaded first - provides XDG_* variables used by other modules

export XDG_CONFIG_HOME="$HOME/.config"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export PATH=$PATH:~/.local/bin

# Local binaries
export PATH=$PATH:~/bin
