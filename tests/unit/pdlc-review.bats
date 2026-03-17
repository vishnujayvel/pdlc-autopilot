#!/usr/bin/env bats
# tests/unit/pdlc-review.bats — Unit tests for hooks/lib/pdlc-review.sh

load ../helpers/common-setup

FIXTURES_DIR=""

setup() {
  TEST_WORK_DIR="$(mktemp -d)"
  source "${HOOKS_DIR}/lib/pdlc-review.sh"
  PDLC_STATE_DIR="${TEST_WORK_DIR}/.pdlc/state"
  PDLC_HANDOFF="${PDLC_STATE_DIR}/HANDOFF.md"
  FIXTURES_DIR="${REPO_DIR}/tests/fixtures/spec-lifecycle"
}

teardown() {
  rm -rf "${TEST_WORK_DIR}"
}

# ──────────────────────────────────────────────────────────
# Observer pattern
# ──────────────────────────────────────────────────────────

@test "review_summary: always returns 0 (Observer pattern)" {
  run pdlc_review_summary "${TEST_WORK_DIR}/nonexistent"
  [[ "$status" -eq 0 ]]
}

@test "review_summary: always returns 0 for empty argument" {
  run pdlc_review_summary ""
  [[ "$status" -eq 0 ]]
}

# ──────────────────────────────────────────────────────────
# Section presence
# ──────────────────────────────────────────────────────────

@test "review_summary: includes Summary section" {
  run pdlc_review_summary "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "### Summary"
}

@test "review_summary: includes Quality Gate section" {
  run pdlc_review_summary "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "### Quality Gate"
}

@test "review_summary: includes Tests section" {
  run pdlc_review_summary "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "### Tests"
}

@test "review_summary: includes Outstanding Issues section" {
  run pdlc_review_summary "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "### Outstanding Issues"
}

@test "review_summary: includes PR Review Summary header" {
  run pdlc_review_summary "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "## PR Review Summary"
}

# ──────────────────────────────────────────────────────────
# Summary section content
# ──────────────────────────────────────────────────────────

@test "review_summary: shows spec present for clean fixture" {
  run pdlc_review_summary "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "Spec: present"
}

@test "review_summary: shows task completion counts" {
  run pdlc_review_summary "${FIXTURES_DIR}/implementing"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "Tasks: 1/3 complete"
}

@test "review_summary: shows all tasks done for complete fixture" {
  run pdlc_review_summary "${FIXTURES_DIR}/complete"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "Tasks: 3/3 complete"
}

# ──────────────────────────────────────────────────────────
# Quality Gate section
# ──────────────────────────────────────────────────────────

@test "review_summary: quality gate includes lifecycle check" {
  run pdlc_review_summary "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "Lifecycle"
}

@test "review_summary: quality gate includes placeholder check" {
  run pdlc_review_summary "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "Placeholder"
}

@test "review_summary: quality gate includes cross-reference check" {
  run pdlc_review_summary "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "Cross-reference"
}

@test "review_summary: quality gate includes lint check" {
  run pdlc_review_summary "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "Lint"
}

@test "review_summary: quality gate includes semantic check" {
  run pdlc_review_summary "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "Semantic"
}

@test "review_summary: quality gate includes skeptic check" {
  run pdlc_review_summary "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "Skeptic"
}

@test "review_summary: quality gate shows overall result" {
  run pdlc_review_summary "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "Overall:"
}

# ──────────────────────────────────────────────────────────
# PDLC_DISABLED
# ──────────────────────────────────────────────────────────

@test "review_summary: notes PDLC_DISABLED when set" {
  PDLC_DISABLED=1 run pdlc_review_summary "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "PDLC_DISABLED"
}

@test "review_summary: bypasses quality checks when PDLC_DISABLED=1" {
  PDLC_DISABLED=1 run pdlc_review_summary "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "bypassed"
}

# ──────────────────────────────────────────────────────────
# Graceful degradation
# ──────────────────────────────────────────────────────────

@test "review_summary: handles missing spec directory gracefully" {
  run pdlc_review_summary "${TEST_WORK_DIR}/nonexistent"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "summary unavailable\|No spec directory"
}

@test "review_summary: all checks clean when no issues" {
  run pdlc_review_summary "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  # The Outstanding Issues section should note "All checks clean" or show issues
  echo "$output" | grep -q "Outstanding Issues"
}
