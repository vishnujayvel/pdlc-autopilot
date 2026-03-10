#!/bin/bash
# tests/helpers/common-setup.bash — Shared BATS setup for PDLC hook tests

REPO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
HOOKS_DIR="${REPO_DIR}/hooks"

setup() {
  TEST_WORK_DIR="$(mktemp -d)"
  # Source state library and override paths to temp dir
  source "${HOOKS_DIR}/lib/pdlc-state.sh"
  PDLC_STATE_DIR="${TEST_WORK_DIR}/.pdlc/state"
  PDLC_HANDOFF="${PDLC_STATE_DIR}/HANDOFF.md"
  PDLC_MARKER="${PDLC_STATE_DIR}/.compact_marker"
}

teardown() {
  rm -rf "${TEST_WORK_DIR}"
}

# Helper: create HANDOFF.md with given frontmatter in a workdir
create_handoff() {
  local workdir="$1"
  local content="$2"
  mkdir -p "${workdir}/.pdlc/state"
  printf '%s\n' "$content" > "${workdir}/.pdlc/state/HANDOFF.md"
}

# Helper: run a hook script from a given workdir with optional stdin
run_hook() {
  local script="$1"
  local workdir="$2"
  local stdin_data="${3:-}"
  if [[ -n "$stdin_data" ]]; then
    (cd "$workdir" && printf '%s' "$stdin_data" | bash "${HOOKS_DIR}/${script}")
  else
    (cd "$workdir" && bash "${HOOKS_DIR}/${script}" < /dev/null 2>/dev/null)
  fi
}
