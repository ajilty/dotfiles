#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/test/lib.sh"

usage() {
  cat <<'EOF'
Usage: test/in-container.sh <ubuntu|fedora|amazonlinux>

Builds and runs the container-based tests for the selected OS.
EOF
}

runtime=""
if command -v docker >/dev/null 2>&1; then
  runtime="docker"
elif command -v podman >/dev/null 2>&1; then
  runtime="podman"
else
  die "docker or podman is required"
fi

os="${1:-}"
case "$os" in
  ubuntu|fedora|amazonlinux)
    ;;
  *)
    usage
    exit 2
    ;;
esac

dockerfile="${TEST_DIR}/container/${os}.Dockerfile"
if [ ! -f "$dockerfile" ]; then
  die "Missing Dockerfile: $dockerfile"
fi

image="dotfiles-test-${os}"

info "Building container image: $image"
"$runtime" build -f "$dockerfile" -t "$image" "$ROOT_DIR"

# Interactively run tests inside the container and remove it afterwards
info "Running container tests for: $os"
"$runtime" run --rm -it \
  "$image" 