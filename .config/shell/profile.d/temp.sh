#!/bin/bash
# Temp directory configuration with platform-specific handling

if [[ "$OSTYPE" == "darwin"* ]]; then
    if [[ "$TMPDIR" == "/var/folders/zz/"* ]] || [[ ! -w "$TMPDIR" ]]; then
        export TMPDIR=$(getconf DARWIN_USER_TEMP_DIR)
    fi
else
    if [[ -z "$TMPDIR" ]] || [[ ! -w "$TMPDIR" ]]; then
        export TMPDIR="/tmp"
    fi
    # /tmp is in memory here (tmpfs), so Claude Code scratch files written
    # there count against the user memory cap. Keep them on disk instead.
    export CLAUDE_CODE_TMPDIR="/var/tmp"
fi

if [ -d "$TMPDIR" ]; then
    export TMPPREFIX="$TMPDIR/zsh"
    export TMUX_TMPDIR="$TMPDIR"
    export HOMEBREW_TEMP="$TMPDIR"

    if [[ "$OSTYPE" == "darwin"* ]] && [ -d "/private/tmp" ]; then
        if [ "$(stat -f %Su /private/tmp)" != "$(whoami)" ]; then
            echo "Setting /private/tmp permissions to current user"
            sudo chown -R $(whoami) /private/tmp
        fi
    fi
fi
