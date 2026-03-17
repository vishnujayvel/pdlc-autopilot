#!/usr/bin/env bats
# tests/unit/pdlc-skeptic.bats — Unit tests for hooks/lib/pdlc-skeptic.sh

load ../helpers/common-setup

FIXTURES_DIR=""

setup() {
  TEST_WORK_DIR="$(mktemp -d)"
  source "${HOOKS_DIR}/lib/pdlc-skeptic.sh"
  PDLC_STATE_DIR="${TEST_WORK_DIR}/.pdlc/state"
  PDLC_HANDOFF="${PDLC_STATE_DIR}/HANDOFF.md"
  FIXTURES_DIR="${REPO_DIR}/tests/fixtures/spec-lifecycle"
}

teardown() {
  rm -rf "${TEST_WORK_DIR}"
}

# ──────────────────────────────────────────────────────────
# Lens 1: Value — pdlc_skeptic_check_value
# ──────────────────────────────────────────────────────────

@test "check_value: returns PASS for spec with SC- markers and no vague language" {
  run pdlc_skeptic_check_value "${FIXTURES_DIR}/clean/spec.md"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "PASS:value"
}

@test "check_value: returns WARN for spec with vague language in success criteria" {
  run pdlc_skeptic_check_value "${FIXTURES_DIR}/skeptic-vague/spec.md"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "WARN:value:vague language"
  echo "$output" | grep -iq "fast"
}

@test "check_value: returns FAIL for spec with no SC- markers" {
  # Create a spec without any success criteria
  local no_sc="${TEST_WORK_DIR}/no-sc-spec.md"
  cat > "$no_sc" <<'EOF'
# Feature Specification: No Success Criteria

## Requirements

- **FR-001**: System MUST do something
EOF
  run pdlc_skeptic_check_value "$no_sc"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "FAIL:value:no success criteria found"
}

@test "check_value: returns INFO for missing spec file" {
  run pdlc_skeptic_check_value "${TEST_WORK_DIR}/nonexistent.md"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "INFO:value"
}

# ──────────────────────────────────────────────────────────
# Lens 2: Feasibility — pdlc_skeptic_check_feasibility
# ──────────────────────────────────────────────────────────

@test "check_feasibility: returns PASS for spec with Given/When/Then" {
  run pdlc_skeptic_check_feasibility "${FIXTURES_DIR}/clean/spec.md"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "PASS:feasibility"
}

@test "check_feasibility: returns WARN for spec without acceptance scenarios" {
  run pdlc_skeptic_check_feasibility "${FIXTURES_DIR}/skeptic-vague/spec.md"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "WARN:feasibility"
}

@test "check_feasibility: returns INFO for missing spec file" {
  run pdlc_skeptic_check_feasibility "${TEST_WORK_DIR}/nonexistent.md"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "INFO:feasibility"
}

# ──────────────────────────────────────────────────────────
# Lens 3: Usability — pdlc_skeptic_check_usability
# ──────────────────────────────────────────────────────────

@test "check_usability: returns PASS for spec with User Story and actor" {
  run pdlc_skeptic_check_usability "${FIXTURES_DIR}/clean/spec.md"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "PASS:usability"
}

@test "check_usability: returns WARN for spec without user stories" {
  run pdlc_skeptic_check_usability "${FIXTURES_DIR}/skeptic-vague/spec.md"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "WARN:usability"
}

@test "check_usability: returns WARN when stories exist but no actors" {
  local no_actors="${TEST_WORK_DIR}/no-actors.md"
  cat > "$no_actors" <<'EOF'
# Feature Specification: No Actors

### User Story 1 - Something

The system should do something.
EOF
  run pdlc_skeptic_check_usability "$no_actors"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "WARN:usability:user stories found but no actor descriptions (As a/an)"
}

@test "check_usability: returns INFO for missing spec file" {
  run pdlc_skeptic_check_usability "${TEST_WORK_DIR}/nonexistent.md"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "INFO:usability"
}

# ──────────────────────────────────────────────────────────
# Lens 4: Viability — pdlc_skeptic_check_viability
# ──────────────────────────────────────────────────────────

@test "check_viability: returns PASS for spec with Assumptions section" {
  run pdlc_skeptic_check_viability "${FIXTURES_DIR}/clean/spec.md"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "PASS:viability"
}

@test "check_viability: returns WARN for spec without scope markers" {
  run pdlc_skeptic_check_viability "${FIXTURES_DIR}/skeptic-vague/spec.md"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "WARN:viability"
}

@test "check_viability: returns INFO for missing spec file" {
  run pdlc_skeptic_check_viability "${TEST_WORK_DIR}/nonexistent.md"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "INFO:viability"
}

# ──────────────────────────────────────────────────────────
# Lens 5: Ethics — pdlc_skeptic_check_ethics
# ──────────────────────────────────────────────────────────

@test "check_ethics: returns PASS for spec with Edge Cases section" {
  run pdlc_skeptic_check_ethics "${FIXTURES_DIR}/clean/spec.md"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "PASS:ethics"
}

@test "check_ethics: returns WARN for spec without Edge Cases section" {
  run pdlc_skeptic_check_ethics "${FIXTURES_DIR}/skeptic-vague/spec.md"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "WARN:ethics"
}

@test "check_ethics: returns WARN for empty Edge Cases section" {
  local empty_edge="${TEST_WORK_DIR}/empty-edge.md"
  cat > "$empty_edge" <<'EOF'
# Feature Specification

### Edge Cases

## Requirements
EOF
  run pdlc_skeptic_check_ethics "$empty_edge"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "WARN:ethics:edge cases section is empty"
}

@test "check_ethics: returns INFO for missing spec file" {
  run pdlc_skeptic_check_ethics "${TEST_WORK_DIR}/nonexistent.md"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "INFO:ethics"
}

# ──────────────────────────────────────────────────────────
# Report: pdlc_skeptic_report
# ──────────────────────────────────────────────────────────

@test "report: returns all 5 lens results for well-formed spec" {
  run pdlc_skeptic_report "${FIXTURES_DIR}/clean/spec.md"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "PASS:value"
  echo "$output" | grep -q "PASS:feasibility"
  echo "$output" | grep -q "PASS:usability"
  echo "$output" | grep -q "PASS:viability"
  echo "$output" | grep -q "PASS:ethics"
}

@test "report: returns findings for vague spec" {
  run pdlc_skeptic_report "${FIXTURES_DIR}/skeptic-vague/spec.md"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "WARN:value"
  echo "$output" | grep -q "WARN:feasibility"
  echo "$output" | grep -q "WARN:usability"
  echo "$output" | grep -q "WARN:viability"
  echo "$output" | grep -q "WARN:ethics"
}

@test "report: returns INFO for missing spec file" {
  run pdlc_skeptic_report "${TEST_WORK_DIR}/nonexistent.md"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "INFO"
}

@test "report: always returns 0 (Observer pattern)" {
  run pdlc_skeptic_report "${FIXTURES_DIR}/skeptic-vague/spec.md"
  [[ "$status" -eq 0 ]]
}

@test "report: respects custom vague word list" {
  local custom_spec="${TEST_WORK_DIR}/custom-vague.md"
  cat > "$custom_spec" <<'EOF'
# Feature Specification

## Success Criteria

### Measurable Outcomes

- **SC-001**: System should be blazing
EOF
  PDLC_SKEPTIC_VAGUE_WORDS="blazing|amazing" run pdlc_skeptic_check_value "$custom_spec"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "WARN:value:vague language"
  echo "$output" | grep -iq "blazing"
}
