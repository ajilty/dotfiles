#!/bin/bash
# dotfiles: Helpers for the bare-repo dotfiles workflow
#
# Functions:
#   dotfiles-blocklist-sync - Fetch the private content blocklist from a gist
#                             into ~/.local/config/dotfiles/blocklist. The
#                             pre-commit hook scans staged diffs against this
#                             file to block accidental publication of names,
#                             emails, host paths, etc. Runs
#                             dotfiles-blocklist-scan after a successful fetch.
#   dotfiles-blocklist-scan - Grep the FULL dotfiles history (all refs) against
#                             the blocklist. The pre-commit hook only sees
#                             staged diffs, so a pattern added after a string
#                             was committed is never re-checked; this scan
#                             closes that gap.

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

    dotfiles-blocklist-scan
}

function dotfiles-blocklist-scan() {
    # Optional arg: git dir to scan (default: the live dotfiles repo).
    local git_dir="${1:-$HOME/.dotfiles}"
    local blocklist="$HOME/.local/config/dotfiles/blocklist"

    if [[ ! -f "$blocklist" ]]; then
        echo "dotfiles-blocklist-scan: no blocklist at $blocklist. Run dotfiles-blocklist-sync first." >&2
        return 1
    fi

    local patterns_tmp="${TMPDIR:-/tmp}/blocklist-scan.$$"
    grep -v -E '^[[:space:]]*(#|$)' "$blocklist" > "$patterns_tmp"
    if [[ ! -s "$patterns_tmp" ]]; then
        rm -f "$patterns_tmp"
        echo "dotfiles-blocklist-scan: blocklist has no patterns; nothing to scan."
        return 0
    fi

    local -a revs
    revs=($(git --git-dir="$git_dir" rev-list --all))

    # -I skips binary blobs; match semantics mirror the pre-commit hook
    # (case-insensitive fixed strings).
    local hits
    hits=$(git --git-dir="$git_dir" grep -I -l -i -F -f "$patterns_tmp" "${revs[@]}" 2>/dev/null)

    if [[ -z "$hits" ]]; then
        rm -f "$patterns_tmp"
        echo "blocklist history scan clean (${#revs[@]} commits)"
        return 0
    fi

    local n_commits
    n_commits=$(echo "$hits" | cut -d: -f1 | sort -u | wc -l | tr -d ' ')
    echo "ERROR: blocklist patterns found in committed history ($n_commits of ${#revs[@]} commits):" >&2
    echo "  files:" >&2
    echo "$hits" | sed 's/^[^:]*://' | sort -u | sed 's/^/    /' >&2
    echo "  patterns:" >&2
    local pattern
    while IFS= read -r pattern; do
        if git --git-dir="$git_dir" grep -q -I -i -F -e "$pattern" "${revs[@]}" 2>/dev/null; then
            echo "    - $pattern" >&2
        fi
    done < "$patterns_tmp"
    rm -f "$patterns_tmp"
    echo "  History already public? Scrub with git-filter-repo + force push (see dotfiles skill)." >&2
    return 1
}
