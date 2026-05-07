#!/bin/bash
# navigation: Directory navigation and workspace management
#
# Functions:
#   n    - nnn file manager wrapper with cd-on-quit support
#   cd   - Enhanced cd that launches nnn when used without arguments
#   try  - Create temporary directories in ~/tries for experiments
#   keep - Convert a try directory into a proper git repository

n ()
{
    # Block nesting of nnn in subshells
    [ "${NNNLVL:-0}" -eq 0 ] || {
        echo "nnn is already running"
        return
    }

    # The behaviour is set to cd on quit (nnn checks if NNN_TMPFILE is set)
    # If NNN_TMPFILE is set to a custom path, it must be exported for nnn to
    # see. To cd on quit only on ^G, remove the "export" and make sure not to
    # use a custom path, i.e. set NNN_TMPFILE *exactly* as follows:
    #      NNN_TMPFILE="${XDG_CONFIG_HOME:-$HOME/.config}/nnn/.lastd"
    export NNN_TMPFILE="${XDG_CONFIG_HOME:-$HOME/.config}/nnn/.lastd"

    # Unmask ^Q (, ^V etc.) (if required, see `stty -a`) to Quit nnn
    # stty start undef
    # stty stop undef
    # stty lwrap undef
    # stty lnext undef

    # The command builtin allows one to alias nnn to n, if desired, without
    # making an infinitely recursive alias
    command nnn "$@"

    [ ! -f "$NNN_TMPFILE" ] || {
        . "$NNN_TMPFILE"
        rm -f -- "$NNN_TMPFILE" > /dev/null
    }
}

function cd(){
    # if cd is used without arguments, if nnn is installed, use it and start from cwd
    if [ -z "$1" ]; then
        if command -v nnn &> /dev/null; then
            n
        else
            builtin cd
        fi
    else
        builtin cd "$@"
    fi

}

# Create or navigate to a temporary directory in ~/tries for experimentation
# Usage: try [name]
#   - Without args: creates timestamped directory (try-YYYYMMDD-HHMMSS)
#   - With name: resume ~/tries/<name> if it exists; else resume the most
#     recently modified ~/tries/*<name>* if any partial match exists;
#     else create ~/tries/<name>-YYYYMMDD-HHMMSS

alias tries='ls -1d ~/tries/*/ 2>/dev/null && find ~/tries/*/ -mindepth 1 -maxdepth 1 -type d 2>/dev/null || echo "No try directories found"'

function try() {
    mkdir -p ~/tries
    local target dir_name
    if [ -n "$1" ]; then
        local name="$1"
        if [ -d ~/tries/"$name" ]; then
            target=~/tries/"$name"
        else
            target=$(ls -td ~/tries/*"$name"*/ 2>/dev/null | head -1)
        fi
        if [ -n "$target" ]; then
            echo "Resuming $target"
            cd "$target" || return
            return
        fi
        dir_name="${name}-$(date +%Y%m%d-%H%M%S)"
    else
        dir_name="try-$(date +%Y%m%d-%H%M%S)"
    fi
    target=~/tries/"$dir_name"
    mkdir -p "$target"
    echo "Created $target"
    cd "$target" || return
}

# Convert a try directory into a proper git repository and move to ~/gits
# Usage: keep
#   - Run from within a ~/tries/* directory
#   - Prompts for repository name (defaults to current directory name)
#   - Initializes git, makes initial commit, and moves to ~/gits/github.com/{username}

function keep() {
    local current_dir=$(pwd)

    # Check if we're in a tries directory
    if [[ ! "$current_dir" =~ ^$HOME/tries/.+ ]]; then
        echo "Error: Must be run from within a ~/tries/* directory"
        return 1
    fi

    local current_name=$(basename "$current_dir")

    # Get GitHub username from gh CLI
    local gh_user=$(gh api user --jq '.login' 2>/dev/null)
    if [ -z "$gh_user" ]; then
        echo "Warning: Could not get GitHub username from gh CLI"
        gh_user="unknown"
    fi

    # Construct default path
    local default_path="$HOME/gits/github.com/$gh_user/$current_name"

    # Prompt for the full path
    echo "Enter repository path (press Enter for default):"
    echo "Default: $default_path"
    read -r user_input

    local target_dir="${user_input:-$default_path}"

    # Expand ~ to $HOME if present
    target_dir="${target_dir/#\~/$HOME}"

    # Check if target already exists
    if [ -d "$target_dir" ]; then
        echo "Error: $target_dir already exists"
        return 1
    fi

    # Initialize git if not already a repo
    if [ ! -d .git ]; then
        echo "Initializing git repository..."
        git init
        git add .
        git commit -m "Initial commit from try session"
    fi

    # Create parent directories if they don't exist
    mkdir -p "$(dirname "$target_dir")"

    # Move to target
    echo "Moving to $target_dir..."
    mv "$current_dir" "$target_dir"
    cd "$target_dir" || return

    echo "Successfully kept as $target_dir"
}
