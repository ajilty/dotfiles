# always install global skills when adding new skills
# skills directories are already symlinked to the global skills directory, so they will be available globally

# Guard against an existing alias named "skills" (zsh parses it as a conflict).
unalias skills 2>/dev/null
skills() {
  # Unset GIT_DIR / GIT_WORK_TREE so npx skills' internal `git clone` works
  # when this function is called from inside `dotfiles-shell` (which sets
  # both vars to the bare-repo / $HOME pair). Without this, `git clone`
  # refuses with "working tree '/Users/alex' already exists".
  local _GIT_DIR_SAVED="${GIT_DIR-__unset__}" _GIT_WT_SAVED="${GIT_WORK_TREE-__unset__}"
  unset GIT_DIR GIT_WORK_TREE
  _restore_git_env() {
    [ "$_GIT_DIR_SAVED" = "__unset__" ] || export GIT_DIR="$_GIT_DIR_SAVED"
    [ "$_GIT_WT_SAVED"  = "__unset__" ] || export GIT_WORK_TREE="$_GIT_WT_SAVED"
    unset -f _restore_git_env
  }

  if [ "$1" = "add" ]; then
    shift
    # -a kimi-cli is a sentinel: not a recognized agent, so the per-agent
    # symlink branch is a no-op and the skill lands only in the canonical
    # .agents/skills/ location. Pass -g (or --global) yourself for user scope.
    command npx skills add -a kimi-cli -y "$@"
    local rc=$?
    _restore_git_env
    return $rc
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
    _restore_git_env
  else
    command npx skills "$@"
    local rc=$?
    _restore_git_env
    return $rc
  fi
}