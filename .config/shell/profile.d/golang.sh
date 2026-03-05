#!/bin/bash
# Go language environment

export GOPATH="$XDG_DATA_HOME/go"
export PATH="$PATH:$GOPATH/bin"

# Rancher Desktop (if installed)
if [ -d "$HOME/.rd/bin" ]; then
    export RD_BIN="$HOME/.rd/bin"
    export PATH="$RD_BIN:$PATH"
    if [ -f "$RD_BIN/rancher-desktop" ]; then
        export RD_BIN="$RD_BIN/rancher-desktop"
    fi
fi
