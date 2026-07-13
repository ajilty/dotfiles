#!/bin/bash
# github-keys: SSH authorized_keys management from GitHub.
#
# Functions:
#   github-keys-append - Fetch a GitHub user's public keys and append any
#                        not already present to authorized_keys (idempotent).
#                        Usage: github-keys-append [gh_user] [target_path]

github-keys-append ()
{
    local gh_user="${1:-$USER}"
    local target_path="${2:-$HOME/.ssh/authorized_keys}"
    local keys key added=0

    keys=$(curl -fsSL "https://github.com/${gh_user}.keys") || {
        echo "failed to fetch keys for ${gh_user}" >&2
        return 1
    }
    if [ -z "$keys" ]; then
        echo "no public keys published for ${gh_user}" >&2
        return 1
    fi

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    touch "$target_path"
    chmod 600 "$target_path"

    while IFS= read -r key; do
        [ -z "$key" ] && continue
        if ! grep -qxF "$key" "$target_path"; then
            printf '%s\n' "$key" >> "$target_path"
            added=$((added + 1))
        fi
    done <<EOF
$keys
EOF
    echo "added ${added} new key(s) for ${gh_user} to ${target_path}"
}
