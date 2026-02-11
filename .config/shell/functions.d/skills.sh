# always install global skills when adding new skills
# skills directories are already symlinked to the global skills directory, so they will be available globally
skills() {
  if [ "$1" = "add" ]; then
    shift
    command npx skills add -g -a kimi-cli -y "$@"
  elif [ "$1" = "link" ]; then
    local source_dir="../.agents/skills"
    local source_dir_abs="~/.agents/skills"
    local target_dirs=(
      "~/.claude/skills"
      "~/.copilot/skills"
      "~/.gemini/skills"
      "~/.codex/skills"
    )

    if [ ! -d "$source_dir_abs" ]; then
      echo "skills link: creating missing source directory: $source_dir_abs" >&2
      # create the source directory if it doesn't exist
      mkdir -p "$source_dir_abs"
    fi

    local target_dir
    for target_dir in "${target_dirs[@]}"; do
      rm -rf "${target_dir}"
      mkdir -p "$(dirname "${target_dir}")"
      ln -s "$source_dir" "${target_dir}"
    done

    # Show links to confirm they are in place.
    ls -ld "${target_dirs[@]}"
  else
    command npx skills "$@"
  fi
}