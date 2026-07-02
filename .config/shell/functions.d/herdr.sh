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

    local old_ver new_ver herdr_bin
    old_ver="$(herdr --version 2>/dev/null | awk '{print $NF}')"

    echo "herdr-update: upgrading herdr via Homebrew..."
    if ! { brew update && brew upgrade herdr; }; then
        echo "herdr-update: brew upgrade failed." >&2
        return 1
    fi

    herdr_bin="$(command -v herdr)"
    new_ver="$("$herdr_bin" --version 2>/dev/null | awk '{print $NF}')"

    if [[ "$old_ver" == "$new_ver" ]]; then
        echo "herdr-update: already on ${new_ver}; no live handoff needed."
        return 0
    fi

    echo "herdr-update: ${old_ver} -> ${new_ver}; handing off live panes to the new server..."
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
