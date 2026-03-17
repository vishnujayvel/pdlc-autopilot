#!/usr/bin/env bats
# tests/integration/spec-quality.bats — Integration tests for unified quality report

load ../helpers/common-setup

FIXTURES_DIR=""

setup() {
  TEST_WORK_DIR="$(mktemp -d)"
  source "${HOOKS_DIR}/lib/pdlc-quality.sh"
  PDLC_STATE_DIR="${TEST_WORK_DIR}/.pdlc/state"
  PDLC_HANDOFF="${PDLC_STATE_DIR}/HANDOFF.md"
  PDLC_MARKER="${PDLC_STATE_DIR}/.compact_marker"
  FIXTURES_DIR="${REPO_DIR}/tests/fixtures/spec-lifecycle"
}

# ──────────────────────────────────────────────────────────
# pdlc_quality_report
# ──────────────────────────────────────────────────────────

@test "quality_report: returns PASS for clean fixture" {
  mkdir -p "${PDLC_STATE_DIR}"
  pdlc_write_handoff "spec_lifecycle: Tasked" ""
  run pdlc_quality_report "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "Result: PASS"
}

@test "quality_report: returns FAIL for fixture with placeholders" {
  mkdir -p "${PDLC_STATE_DIR}"
  pdlc_write_handoff "spec_lifecycle: Draft" ""
  run pdlc_quality_report "${FIXTURES_DIR}/placeholders"
  [[ "$status" -eq 1 ]]
  echo "$output" | grep -q "Result: FAIL"
}

@test "quality_report: returns FAIL for fixture with xref gaps" {
  mkdir -p "${PDLC_STATE_DIR}"
  pdlc_write_handoff "spec_lifecycle: Tasked" ""
  run pdlc_quality_report "${FIXTURES_DIR}/xref-gaps"
  [[ "$status" -eq 1 ]]
  echo "$output" | grep -q "Result: FAIL"
}

@test "quality_report: output includes lifecycle state section" {
  mkdir -p "${PDLC_STATE_DIR}"
  pdlc_write_handoff "spec_lifecycle: Planned" ""
  run pdlc_quality_report "${FIXTURES_DIR}/clean"
  echo "$output" | grep -q "Lifecycle State"
  echo "$output" | grep -q "Planned"
}

@test "quality_report: output includes placeholder section" {
  mkdir -p "${PDLC_STATE_DIR}"
  pdlc_write_handoff "spec_lifecycle: Draft" ""
  run pdlc_quality_report "${FIXTURES_DIR}/clean"
  echo "$output" | grep -q "Placeholder Detection"
}

@test "quality_report: output includes cross-reference section" {
  mkdir -p "${PDLC_STATE_DIR}"
  pdlc_write_handoff "spec_lifecycle: Draft" ""
  run pdlc_quality_report "${FIXTURES_DIR}/clean"
  echo "$output" | grep -q "Cross-Reference Consistency"
}
