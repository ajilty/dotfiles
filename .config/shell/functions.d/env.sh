#!/bin/sh
# env: On-demand environment preset loading with 1Password secret injection
# Compatible with bash and zsh.
#
# Preset files are *.env files in:
#   ~/.config/shell/env.d/       (tracked via dotfiles)
#   ~/.local/config/shell/env.d/ (machine-local, not tracked)
#
# Local presets override tracked ones if both share the same name.
#
# Each .env file contains export KEY=VALUE lines. Values may use
# op:// references which are resolved at runtime via `op inject`.
#
# Usage:
#   env              # list available presets
#   env <preset>     # load a preset
#   env-claude       # shorthand (auto-registered per preset)

_ENV_TRACKED_DIR="${HOME}/.config/shell/env.d"
_ENV_LOCAL_DIR="${HOME}/.local/config/shell/env.d"

# Portable env-file finder (avoids bare globs that fail in zsh nomatch)
# Outputs one .env path per line; safe with empty directories.
_env_find() {
    local dir="$1"
    [ -d "$dir" ] && find "$dir" -maxdepth 1 -name '*.env' -type f 2>/dev/null | sort
}

# Core loader: resolve op:// references and export into current shell
_env_load() {
    local preset="$1"
    local env_file=""

    # Local overrides tracked
    if [ -f "${_ENV_LOCAL_DIR}/${preset}.env" ]; then
        env_file="${_ENV_LOCAL_DIR}/${preset}.env"
    elif [ -f "${_ENV_TRACKED_DIR}/${preset}.env" ]; then
        env_file="${_ENV_TRACKED_DIR}/${preset}.env"
    else
        echo "env: preset '${preset}' not found" >&2
        echo "  Searched: ${_ENV_TRACKED_DIR}/${preset}.env" >&2
        echo "            ${_ENV_LOCAL_DIR}/${preset}.env" >&2
        return 1
    fi

    # Check if any uncommented op:// references exist in the file
    if grep -v '^\s*#' "$env_file" 2>/dev/null | grep -q 'op://'; then
        # Need op CLI for injection
        if ! command -v op >/dev/null 2>&1; then
            echo "env: 1Password CLI (op) is not installed" >&2
            return 1
        fi

        # Pre-export OP_ACCOUNT from the file so op knows which account to use
        local acct
        acct="$(grep -v '^\s*#' "$env_file" | grep 'OP_ACCOUNT=' | head -1 | sed "s/.*OP_ACCOUNT=['\"]*//" | sed "s/['\"].*//")"
        if [ -n "$acct" ]; then
            export OP_ACCOUNT="$acct"
        fi

        # Ensure signed in
        if ! op whoami >/dev/null 2>&1; then
            echo "env: signing in to 1Password..."
            eval "$(op signin)" || { echo "env: sign-in failed" >&2; return 1; }
        fi

        # Inject secrets and eval the result
        local resolved
        resolved="$(op inject -i "$env_file")" || {
            echo "env: failed to resolve secrets in ${env_file}" >&2
            return 1
        }
        eval "$resolved"
    else
        # No op:// references — source directly
        # shellcheck disable=SC1090
        . "$env_file"
    fi

    echo "env: loaded '${preset}' from ${env_file}"
}

# List available presets
_env_list() {
    local name src seen="" output=""

    # Collect all presets: merge tracked + local, local overrides tracked
    # Use a temp file to avoid subshell variable scoping issues with pipes
    local tmpfile
    tmpfile="$(mktemp)" || return 1

    # Tracked presets
    _env_find "$_ENV_TRACKED_DIR" >> "$tmpfile"
    # Local presets
    _env_find "$_ENV_LOCAL_DIR" >> "$tmpfile"

    while IFS= read -r f; do
        name="$(basename "$f" .env)"

        # Skip duplicates (first occurrence wins: tracked dir is listed first,
        # but we label source based on whether a local copy exists)
        case " ${seen} " in
            *" ${name} "*) continue ;;
        esac
        seen="${seen} ${name}"

        src="tracked"
        [ -f "${_ENV_LOCAL_DIR}/${name}.env" ] && src="local"

        output="${output}  env-${name}  (${src})
"
    done < "$tmpfile"
    rm -f "$tmpfile"

    if [ -z "$output" ]; then
        echo "env: no presets found"
        echo "  Add .env files to:"
        echo "    ${_ENV_TRACKED_DIR}/"
        echo "    ${_ENV_LOCAL_DIR}/"
        return 0
    fi

    echo "Available env presets:"
    printf '%s' "$output"
}

# Main entrypoint: env [preset]
env() {
    if [ -z "$1" ]; then
        # Show system environment variables first
        command env
        echo ""
        # Then show our presets
        _env_list
    else
        _env_load "$1"
    fi
}

# Auto-register env-<name> shorthand functions for discovered presets
_env_register() {
    local f name

    for f in $(_env_find "$_ENV_TRACKED_DIR") $(_env_find "$_ENV_LOCAL_DIR"); do
        name="$(basename "$f" .env)"
        # Only register if function doesn't already exist
        if ! command -v "env-${name}" >/dev/null 2>&1; then
            eval "env-${name}() { _env_load '${name}'; }"
        fi
    done
}

_env_register
