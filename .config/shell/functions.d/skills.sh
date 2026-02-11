# always install global skills when adding new skills
# skills directories are already symlinked to the global skills directory, so they will be available globally
skills() {
  if [ "$1" = "add" ]; then
    shift
    command npx skills add -g -a amp -y "$@"
  else
    command npx skills "$@"
  fi
}