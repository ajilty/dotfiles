#!/bin/bash
# herdr: helpers for the herdr terminal multiplexer
#
# Functions:
#   herdr-update - Homebrew-upgrade herdr, then live-handoff the running server
#                  onto the new binary so agent panes keep running (no pause).
#                  Homebrew installs can't use `herdr update --handoff`, so this
#                  chains `brew upgrade` with a manual `herdr server live-handoff`.

function herdr-update() {
    if ! command -v herdr >/dev/null 2>&1; then
        echo "herdr-update: herdr not installed." >&2
        return 1
    fi
    if ! command -v brew >/dev/null 2>&1; then
        echo "herdr-update: this helper is for Homebrew installs (brew not found)." >&2
        return 1
    fi

    local server_ver new_ver herdr_bin

    # Best-effort upgrade. brew failures must NOT block reconciling a server
    # that's already behind the on-disk binary (e.g. herdr was bumped by a
    # blanket `brew upgrade`/`brew-sync`), so a hiccup here only warns and we
    # fall through to the version-skew handoff below. That makes this function
    # idempotent and self-healing however herdr got upgraded.
    echo "herdr-update: upgrading herdr via Homebrew (best-effort)..."
    brew update >/dev/null 2>&1 || \
        echo "herdr-update: 'brew update' failed; continuing to reconcile." >&2
    brew upgrade herdr 2>&1 || \
        echo "herdr-update: 'brew upgrade herdr' failed; reconciling against current binary." >&2

    herdr_bin="$(command -v herdr)"
    new_ver="$("$herdr_bin" --version 2>/dev/null | awk '{print $NF}')"
    # Gate on the RUNNING SERVER's version, not the binary's pre-upgrade
    # version: the binary may have been upgraded outside this function
    # (blanket `brew upgrade`, another session), leaving a stale server.
    server_ver="$("$herdr_bin" status server 2>/dev/null | awk '/^version:/ {print $2}')"

    if [[ -z "$server_ver" ]]; then
        echo "herdr-update: binary at ${new_ver}; no server running, nothing to hand off."
        return 0
    fi
    if [[ "$server_ver" == "$new_ver" ]]; then
        echo "herdr-update: server already on ${new_ver}; no live handoff needed."
        return 0
    fi

    echo "herdr-update: server ${server_ver} -> ${new_ver}; handing off live panes to the new server..."
    if herdr server live-handoff --import-exe "$herdr_bin" --expected-version "$new_ver"; then
        echo "herdr-update: live handoff complete."
        herdr status server
    else
        echo "herdr-update: live handoff did not complete (experimental; possible protocol mismatch)." >&2
        echo "  Sessions were NOT restarted. To finish with a brief pause, run from a plain terminal:" >&2
        echo "    herdr server stop && herdr" >&2
        return 1
    fi
}
