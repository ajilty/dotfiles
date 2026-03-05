#!/bin/bash
# VSCode editor configuration

export PATH=$PATH:/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin
export PATH=$PATH:/Applications/Visual\ Studio\ Code\ -\ Insiders.app/Contents/Resources/app/bin
if command -v code 1>/dev/null 2>&1; then
    export EDITOR="code --wait"
fi
