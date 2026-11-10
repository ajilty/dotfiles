#!/bin/bash
# trust-me: install your default SSH agent key (1Password) on a remote host.
#
# Functions:
#   trust-me - Install one public key from the SSH agent that ssh uses for
#              the target into user@host's authorized_keys (via ssh-copy-id,
#              using the password once), then confirm that exact key logs in.
#              Usage: trust-me user@host [comment-text]
#              Default key: the first key the agent offers, which is the key
#              ssh tries first unless a Host block pins another identity.
#              comment-text picks the first key whose comment contains it
#              (case-insensitive). Non-standard port: use an ssh config alias.

trust-me ()
{
    local target="$1" match="$2" sock keys key tmp rc
    if [ -z "$target" ]; then
        echo "usage: trust-me user@host [comment-text]" >&2
        return 2
    fi

    # Use the agent ssh itself would use for this target (from ~/.ssh/config).
    sock=$(ssh -G "$target" 2>/dev/null | sed -n 's/^identityagent //p')
    case "$sock" in
        none) echo "trust-me: $target is configured to use no SSH agent" >&2; return 1 ;;
        ""|SSH_AUTH_SOCK) sock="$SSH_AUTH_SOCK" ;;
    esac
    sock="${sock/#\~/$HOME}"
    # A host that pins its own key would make both the install's duplicate
    # check and the login check pass with that key instead of this one.
    if ssh -G "$target" 2>/dev/null | grep -qx 'identitiesonly yes'; then
        echo "trust-me: $target has IdentitiesOnly yes in ~/.ssh/config, so the check can't prove this key; install manually" >&2
        return 1
    fi

    keys=$(SSH_AUTH_SOCK="$sock" ssh-add -L 2>/dev/null) || {
        echo "trust-me: the SSH agent has no keys (is 1Password unlocked?)" >&2
        return 1
    }
    if [ -n "$match" ]; then
        key=$(printf '%s\n' "$keys" | awk -v m="$(printf '%s' "$match" | tr '[:upper:]' '[:lower:]')" \
            '{ c = $0; sub(/^[^ ]+ [^ ]+ ?/, "", c); if (index(tolower(c), m)) { print; exit } }')
    else
        key=$(printf '%s\n' "$keys" | head -1)
    fi
    case "$key" in
        ssh-*|ecdsa-*|sk-*) ;;
        *) echo "trust-me: no matching key in the agent" >&2; return 1 ;;
    esac

    tmp=$(mktemp -d) || return 1
    # The private key stays in 1Password. ssh-copy-id wants a "private" file
    # next to the .pub; the public key in both lets it run without -f, which
    # keeps its already-installed check, and ssh signs via the agent.
    printf '%s\n' "$key" > "$tmp/key.pub"
    cp "$tmp/key.pub" "$tmp/key"
    echo "installing: ${key%% *} ...${key: -40}"

    ssh-copy-id -o IdentitiesOnly=yes -o ControlPath=none -i "$tmp/key" "$target"
    rc=$?
    if [ $rc -eq 0 ]; then
        # Prove this exact key works: no other keys, no password, no reused connection.
        if ssh -i "$tmp/key.pub" -o IdentitiesOnly=yes -o PreferredAuthentications=publickey \
               -o ControlPath=none -o BatchMode=yes "$target" true; then
            echo "trust-me: key login to $target works"
        else
            echo "trust-me: key-only login with this key failed (approval prompt denied, or the server rejects keys)" >&2
            rc=1
        fi
    fi
    rm -rf "$tmp"
    return $rc
}
