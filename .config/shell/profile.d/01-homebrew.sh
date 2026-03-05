#!/bin/bash
# 01-homebrew: Homebrew configuration for macOS and Linux
# Loaded second - provides HOMEBREW_PREFIX used by other modules

if [ -d "/opt/homebrew/bin" ]; then
    export HOMEBREW_PREFIX="/opt/homebrew"
elif [ -d "/home/linuxbrew/.linuxbrew/bin" ]; then
    export HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
fi

if [ -n "$HOMEBREW_PREFIX" ]; then
    export HOMEBREW_CELLAR="$HOMEBREW_PREFIX/Cellar"
    export HOMEBREW_REPOSITORY="$HOMEBREW_PREFIX"
    export PATH="$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin${PATH+:$PATH}"
    export MANPATH="$HOMEBREW_PREFIX/share/man${MANPATH+:$MANPATH}:"
    export INFOPATH="$HOMEBREW_PREFIX/share/info:${INFOPATH:-}"
    export HOMEBREW_NO_AUTO_UPDATE=1
fi
