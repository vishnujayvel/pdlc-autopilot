#!/usr/bin/env bats
# tests/unit/pdlc-semantic.bats — Unit tests for hooks/lib/pdlc-semantic.sh

load ../helpers/common-setup

FIXTURES_DIR=""

setup() {
  TEST_WORK_DIR="$(mktemp -d)"
  # Set test mode to skip LLM calls
  export PDLC_DIRECTOR_TEST_MODE=1
  source "${HOOKS_DIR}/lib/pdlc-semantic.sh"
  PDLC_STATE_DIR="${TEST_WORK_DIR}/.pdlc/state"
  PDLC_HANDOFF="${PDLC_STATE_DIR}/HANDOFF.md"
  FIXTURES_DIR="${REPO_DIR}/tests/fixtures/spec-lifecycle"
}

teardown() {
  rm -rf "${TEST_WORK_DIR}"
  unset PDLC_DIRECTOR_TEST_MODE
}

# ──────────────────────────────────────────────────────────
# pdlc_semantic_validate
# ──────────────────────────────────────────────────────────

@test "semantic_validate: returns CLEAN for fixture with all refs resolved" {
  run pdlc_semantic_validate "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "CLEAN"
}

@test "semantic_validate: returns findings for xref-gaps fixture" {
  run pdlc_semantic_validate "${FIXTURES_DIR}/xref-gaps"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "MAJOR:completeness"
}

@test "semantic_validate: returns BLOCKER for placeholder fixture" {
  run pdlc_semantic_validate "${FIXTURES_DIR}/placeholders"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "BLOCKER:correctness"
}

@test "semantic_validate: handles missing spec directory" {
  run pdlc_semantic_validate "${TEST_WORK_DIR}/nonexistent"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "INFO"
}

@test "semantic_validate: assigns severity levels" {
  run pdlc_semantic_validate "${FIXTURES_DIR}/xref-gaps"
  [[ "$status" -eq 0 ]]
  # Should contain MAJOR (xref gaps are Major severity)
  echo "$output" | grep -qE "BLOCKER|MAJOR|MINOR"
}
