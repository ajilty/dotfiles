#!/bin/bash
# brew-sync: Categorized Homebrew package management.
#
# Public:
#   brew         - wraps `brew install`/`brew reinstall` to offer saving
#                  each package into a modular ~/.config/homebrew/Brewfile.*
#   brew-sync    - lists installed packages not in any Brewfile and
#                  optionally walks them through the same save flow
#
# Brewfiles are discovered dynamically by globbing Brewfile.* — drop a
# new Brewfile.<category> in the dir and it shows up in the menu.
# Works under bash and zsh; no array indexing, no `read -t`.

_brew_sync_dir="${XDG_CONFIG_HOME:-$HOME/.config}/homebrew"

# --- helpers ---------------------------------------------------------

_brew_sync_categories() {
    local f name
    for f in "$_brew_sync_dir"/Brewfile.*; do
        [ -e "$f" ] || continue
        name="${f##*/Brewfile.}"
        printf '%s\n' "$name"
    done
}

# 0 if `$1 "$2"` already appears in any Brewfile. $1 is brew|cask|tap.
_brew_sync_listed() {
    grep -F -q -- "$1 \"$2\"" "$_brew_sync_dir"/Brewfile.* 2>/dev/null
}

# 0 if `$1 "$2"` appears in the persistent ignore list.
_brew_sync_ignored() {
    grep -F -q -- "$1 \"$2\"" "$_brew_sync_dir/.ignore" 2>/dev/null
}

# Append `$1 "$2"` to .ignore, creating the file with a header on first use.
_brew_sync_ignore_add() {
    local file="$_brew_sync_dir/.ignore"
    if [ ! -f "$file" ]; then
        {
            echo "# brew-sync ignore list. Lines here are NEVER prompted by \`brew()\` or \`brew-sync\`."
            echo "# Remove a line (or this whole file) to start being prompted again."
        } > "$file"
    fi
    printf '%s "%s"\n' "$1" "$2" >> "$file"
}

# Print existing section names (one per line) from $1.
_brew_sync_sections() {
    awk '
        NR<=2 && /^#/ { next }                        # file header
        /^#+[[:space:]]+[^[:space:]]/ {               # section header
            sub(/^#+[[:space:]]+/, "")
            sub(/[[:space:]]+$/, "")
            print
        }
    ' "$1"
}

# Case-insensitive substring match: pkg name vs section names. Print first hit.
_brew_sync_guess_section() {
    local pkg="$1" file="$2" lc_pkg lc_s s
    lc_pkg=$(printf '%s' "$pkg" | tr '[:upper:]' '[:lower:]')
    while IFS= read -r s; do
        [ -z "$s" ] && continue
        lc_s=$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]')
        case "$lc_pkg" in
            *"$lc_s"*) printf '%s\n' "$s"; return ;;
        esac
    done <<EOF
$(_brew_sync_sections "$file")
EOF
}

# Insert "$line" into "$file" under "$section" (just before the next section
# header) or at EOF when "$section" is empty/"(end)".
_brew_sync_insert() {
    local file="$1" section="$2" line="$3" tmp
    if [ -z "$section" ] || [ "$section" = "(end)" ]; then
        # ensure trailing newline before appending
        if [ -s "$file" ] && [ "$(tail -c1 "$file" | wc -l)" -eq 0 ]; then
            printf '\n' >> "$file"
        fi
        printf '%s\n' "$line" >> "$file"
        return
    fi
    tmp="$file.tmp.$$"
    # Buffered insertion: hold the previous line so we can place the new
    # entry BEFORE a trailing blank line that precedes the next section
    # header (preserves the file's "blank line before each header" style).
    awk -v sect="$section" -v ins="$line" '
        function flush_buf() { if (have_buf) { print buf; have_buf=0 } }
        BEGIN { in_sect=0; printed=0; have_buf=0 }
        {
            if (!printed && in_sect && /^#+[[:space:]]+[^[:space:]]/) {
                # next section header reached; place ins before any
                # buffered blank separator, then the separator, then header
                if (have_buf && buf ~ /^[[:space:]]*$/) {
                    print ins
                    print buf
                    have_buf=0
                } else {
                    flush_buf()
                    print ins
                }
                printed=1
                in_sect=0
                print
                next
            }
            flush_buf()
            if (in_sect && /^[[:space:]]*$/) {
                buf=$0; have_buf=1
            } else {
                print
            }
            if (!in_sect) {
                t=$0
                sub(/^#+[[:space:]]+/, "", t)
                sub(/[[:space:]]+$/, "", t)
                if (t == sect) in_sect=1
            }
        }
        END {
            if (!printed && in_sect) {
                if (have_buf && buf ~ /^[[:space:]]*$/) {
                    print ins
                    print buf
                } else {
                    flush_buf()
                    print ins
                }
            } else {
                flush_buf()
            }
        }
    ' "$file" > "$tmp" && mv "$tmp" "$file"
}

# Prompt for which Brewfile + section, then write. $1=kind (brew|cask), $2=pkg.
_brew_sync_prompt_save() {
    [ -t 0 ] && [ -t 1 ] || return 0
    _brew_sync_listed "$1" "$2" && return 0
    _brew_sync_ignored "$1" "$2" && return 0

    local cats reply file section hint sections menu tap_name
    cats=$(_brew_sync_categories | paste -sd'|' -)
    [ -n "$cats" ] || return 0

    printf '\nSave `%s` to a Brewfile?\n  [%s]  (Enter to skip, ! to ignore forever) > ' "$2" "$cats"
    IFS= read -r reply || { echo; return 0; }
    [ -z "$reply" ] && return 0

    if [ "$reply" = "!" ]; then
        _brew_sync_ignore_add "$1" "$2"
        printf '  ✓ added to .ignore (never ask again)\n'
        return 0
    fi

    file="$_brew_sync_dir/Brewfile.$reply"
    if [ ! -f "$file" ]; then
        printf '  ✗ no such Brewfile.%s\n' "$reply" >&2
        return 0
    fi

    section=""
    sections=$(_brew_sync_sections "$file")
    if [ -n "$sections" ]; then
        hint=$(_brew_sync_guess_section "$2" "$file")
        menu=$(printf '%s\n(end)\n+New' "$sections" | paste -sd'|' -)
        if [ -n "$hint" ]; then
            printf 'Section in Brewfile.%s?  (hint: %s)\n  [%s]  (Enter to skip saving) > ' \
                "$reply" "$hint" "$menu"
        else
            printf 'Section in Brewfile.%s?\n  [%s]  (Enter to skip saving) > ' \
                "$reply" "$menu"
        fi
        IFS= read -r section || { echo; return 0; }
        [ -z "$section" ] && return 0
        # Resolve the input:
        #   (end)        -> insert at EOF (handled by _brew_sync_insert)
        #   +New | +     -> prompt for new section name, then create header
        #   +<name>      -> shortcut: create section <name>
        #   <name>       -> must match an existing section (case-insensitive)
        local create_new=0
        case "$section" in
            "(end)")
                : ;;
            "+New"|"+")
                printf '  New section name > '
                IFS= read -r section || { echo; return 0; }
                [ -z "$section" ] && return 0
                create_new=1
                ;;
            "+"*)
                section="${section#+}"
                create_new=1
                ;;
            *)
                # Validate against parsed sections (case-insensitive). Resolve
                # to exact-case name so _brew_sync_insert's match succeeds.
                local resolved="" lc_input s
                lc_input=$(printf '%s' "$section" | tr '[:upper:]' '[:lower:]')
                while IFS= read -r s; do
                    [ -z "$s" ] && continue
                    if [ "$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]')" = "$lc_input" ]; then
                        resolved="$s"
                        break
                    fi
                done <<EOF
$sections
EOF
                if [ -z "$resolved" ]; then
                    printf '  ✗ no such section "%s" in Brewfile.%s (use +%s to create it)\n' \
                        "$section" "$reply" "$section" >&2
                    return 0
                fi
                section="$resolved"
                ;;
        esac
        if [ "$create_new" -eq 1 ]; then
            # Append "## <name>" header to file so the subsequent insert finds it.
            if [ -s "$file" ] && [ "$(tail -c1 "$file" | wc -l)" -eq 0 ]; then
                printf '\n' >> "$file"
            fi
            printf '\n## %s\n' "$section" >> "$file"
        fi
    fi

    # Tap auto-add for user/tap/pkg names (skip local paths).
    case "$2" in
        ./*|/*|~*) : ;;
        */*/*)
            tap_name="${2%/*}"  # strip last segment -> user/tap
            if ! _brew_sync_listed tap "$tap_name"; then
                _brew_sync_insert "$file" "$section" "tap \"$tap_name\""
            fi
            ;;
    esac

    _brew_sync_insert "$file" "$section" "$1 \"$2\""
    printf '  ✓ added to Brewfile.%s\n' "$reply"
}

# Decide formula vs cask for a positional that had no explicit flag.
_brew_sync_detect_kind() {
    if command brew list --cask "$1" >/dev/null 2>&1; then
        echo cask
    else
        echo brew
    fi
}

# --- public ----------------------------------------------------------

brew() {
    case "$1" in
        install|reinstall) ;;
        *) command brew "$@"; return $? ;;
    esac

    local sub="$1"; shift
    local kind="" skip_prompt=0 a k
    for a in "$@"; do
        case "$a" in
            --cask|--casks)                   kind=cask ;;
            --formula|--formulae)             kind=brew ;;
            -n|--dry-run|--only-dependencies) skip_prompt=1 ;;
        esac
    done

    command brew "$sub" "$@" || return $?
    [ "$skip_prompt" -eq 1 ] && return 0

    for a in "$@"; do
        case "$a" in
            -*)        continue ;;
            ./*|/*|~*) continue ;;
        esac
        k="$kind"
        [ -z "$k" ] && k=$(_brew_sync_detect_kind "$a")
        _brew_sync_prompt_save "$k" "$a"
    done
}

brew-sync() {
    local installed_brew installed_cask pkg reply
    local untracked_b="" untracked_c=""

    installed_brew=$(command brew leaves 2>/dev/null)
    installed_cask=$(command brew list --cask 2>/dev/null)

    # Accumulate untracked packages as newline-separated lists so iteration
    # works identically in bash and zsh (no reliance on word-splitting).
    while IFS= read -r pkg; do
        [ -z "$pkg" ] && continue
        _brew_sync_listed brew "$pkg" && continue
        _brew_sync_ignored brew "$pkg" && continue
        untracked_b="$untracked_b$pkg
"
    done <<EOF
$installed_brew
EOF
    while IFS= read -r pkg; do
        [ -z "$pkg" ] && continue
        _brew_sync_listed cask "$pkg" && continue
        _brew_sync_ignored cask "$pkg" && continue
        untracked_c="$untracked_c$pkg
"
    done <<EOF
$installed_cask
EOF

    echo "# Untracked formulae (brew leaves):"
    if [ -n "$untracked_b" ]; then
        printf '%s' "$untracked_b" | sed 's/^/  /'
    else
        echo "  (none)"
    fi
    echo "# Untracked casks:"
    if [ -n "$untracked_c" ]; then
        printf '%s' "$untracked_c" | sed 's/^/  /'
    else
        echo "  (none)"
    fi
    if [ -s "$_brew_sync_dir/.ignore" ]; then
        local ignored_lines
        ignored_lines=$(grep -E '^(brew|cask) "' "$_brew_sync_dir/.ignore" 2>/dev/null)
        if [ -n "$ignored_lines" ]; then
            echo "# Ignored:"
            printf '%s\n' "$ignored_lines" | sed 's/^/  /'
        fi
    fi

    [ -z "$untracked_b$untracked_c" ] && return 0

    printf '\nDo you want to address the out-of-sync ones? (Enter to skip) > '
    IFS= read -r reply || { echo; return 0; }
    [ -z "$reply" ] && return 0

    # Read pkg list on FD 3 so the inner prompt's read still talks to the
    # terminal on FD 0; otherwise _brew_sync_prompt_save sees non-tty stdin
    # and silently early-returns.
    while IFS= read -r pkg <&3; do
        [ -z "$pkg" ] && continue
        _brew_sync_prompt_save brew "$pkg"
    done 3<<EOF
$untracked_b
EOF
    while IFS= read -r pkg <&3; do
        [ -z "$pkg" ] && continue
        _brew_sync_prompt_save cask "$pkg"
    done 3<<EOF
$untracked_c
EOF
    printf '\n(review: dotfiles diff ~/.config/homebrew/)\n'
}
