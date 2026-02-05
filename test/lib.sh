#!/usr/bin/env bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="${ROOT_DIR}/test"
TESTS_DIR="${TEST_DIR}/tests.d"

log() {
  printf '%s\n' "$*"
}

info() {
  printf 'info: %s\n' "$*"
}

warn() {
  printf 'warn: %s\n' "$*"
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

timestamp() {
  date "+%Y%m%d-%H%M%S"
}

create_sandbox_dir() {
  local base
  local dir
  base="${TEST_DIR}/sandbox-$(timestamp)"
  dir="$base"
  if [ -e "$dir" ]; then
    dir="${base}-$$"
  fi
  mkdir -p "$dir"
  printf '%s\n' "$dir"
}

run_with_timeout() {
  local timeout_seconds
  local log_file
  local start
  local pid
  local now

  timeout_seconds="$1"
  shift
  log_file="$1"
  shift

  start=$(date +%s)
  "$@" >"$log_file" 2>&1 &
  pid=$!

  while kill -0 "$pid" 2>/dev/null; do
    now=$(date +%s)
    if [ $((now - start)) -ge "$timeout_seconds" ]; then
      kill "$pid" 2>/dev/null || true
      sleep 1
      kill -9 "$pid" 2>/dev/null || true
      return 124
    fi
    sleep 2
  done

  wait "$pid"
}
