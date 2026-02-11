# always install global skills when adding new skills
# skills directories are already symlinked to the global skills directory, so they will be available globally
skills() {
  if [ "$1" = "add" ]; then
    shift
    command npx skills add -g -a kimi-cli -y "$@"
  elif [ "$1" = "link" ]; then
    local source_dir="$HOME/.config/agents/skills"
    local target_dirs=(
      "$HOME/.claude/skills"
      "$HOME/.copilot/skills"
      "$HOME/.gemini/skills"
      "$HOME/.config/opencode/skills"
    )

    if [ ! -d "$source_dir" ]; then
      echo "skills link: missing source directory: $source_dir" >&2
      return 1
    fi

    local target_dir
    for target_dir in "${target_dirs[@]}"; do
      rm -rf "$target_dir"
      mkdir -p "$(dirname "$target_dir")"
      ln -s "$source_dir" "$target_dir"
    done

    # Show links to confirm they are in place.
    ls -ld "${target_dirs[@]}"
  else
    command npx skills "$@"
  fi
}