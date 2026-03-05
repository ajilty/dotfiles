#!/bin/bash
# Python environment configuration

export PIP_DOWNLOAD_CACHE=$XDG_CACHE_HOME/pip
export PIP_LOG_FILE=$XDG_CACHE_HOME/pip/pip.log
export PIP_BUILD=$XDG_CACHE_HOME/pip/build

# Python Pyenv
if command -v pyenv 1>/dev/null 2>&1; then
    export PYENV_ROOT="$XDG_DATA_HOME/pyenv"
    export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
fi
