#!/bin/bash
# dotfiles: Helpers for the bare-repo dotfiles workflow
#
# Functions:
#   dotfiles-blocklist-sync - Fetch the private content blocklist from a gist
#                             into ~/.local/config/dotfiles/blocklist. The
#                             pre-commit hook scans staged diffs against this
#                             file to block accidental publication of names,
#                             emails, host paths, etc.

function dotfiles-blocklist-sync() {
    local gist_id_file="$HOME/.local/config/dotfiles/gist-id"
    local out_file="$HOME/.local/config/dotfiles/blocklist"
    local tmp_file="${out_file}.tmp.$$"

    if [[ ! -f "$gist_id_file" ]]; then
        echo "dotfiles-blocklist-sync: gist id file missing." >&2
        echo "  Create $gist_id_file containing just the private gist ID," >&2
        echo "  then re-run. The gist must contain a file named blocklist.txt." >&2
        return 1
    fi

    local gist_id
    gist_id=$(tr -d '[:space:]' < "$gist_id_file")
    if [[ -z "$gist_id" ]]; then
        echo "dotfiles-blocklist-sync: $gist_id_file is empty." >&2
        return 1
    fi

    if ! command -v gh >/dev/null 2>&1; then
        echo "dotfiles-blocklist-sync: gh CLI not installed." >&2
        return 1
    fi

    if ! gh auth status --hostname github.com >/dev/null 2>&1; then
        echo "dotfiles-blocklist-sync: gh not authenticated. Run: gh auth login --hostname github.com" >&2
        return 1
    fi

    mkdir -p "$(dirname "$out_file")"

    if ! gh api "gists/$gist_id" --jq '.files["dotfiles-blocklist.txt"].content' > "$tmp_file" 2>/dev/null; then
        rm -f "$tmp_file"
        echo "dotfiles-blocklist-sync: gh api fetch failed for gist $gist_id." >&2
        echo "  Check the gist ID and that it contains a file named dotfiles-blocklist.txt." >&2
        return 1
    fi

    if [[ ! -s "$tmp_file" ]]; then
        rm -f "$tmp_file"
        echo "dotfiles-blocklist-sync: fetched blocklist is empty. Refusing to overwrite." >&2
        return 1
    fi

    mv "$tmp_file" "$out_file"

    local pattern_count
    pattern_count=$(grep -cv -E '^\s*(#|$)' "$out_file" || true)
    echo "blocklist synced ($pattern_count patterns) -> $out_file"
}
