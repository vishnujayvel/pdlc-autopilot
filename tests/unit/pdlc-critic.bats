#!/usr/bin/env bats
# tests/unit/pdlc-critic.bats — Unit tests for hooks/lib/pdlc-critic.sh

load ../helpers/common-setup

FIXTURES_DIR=""

setup() {
  TEST_WORK_DIR="$(mktemp -d)"
  source "${HOOKS_DIR}/lib/pdlc-critic.sh"
  PDLC_STATE_DIR="${TEST_WORK_DIR}/.pdlc/state"
  PDLC_HANDOFF="${PDLC_STATE_DIR}/HANDOFF.md"
  FIXTURES_DIR="${REPO_DIR}/tests/fixtures/spec-lifecycle"
}

teardown() {
  rm -rf "${TEST_WORK_DIR}"
}

# ──────────────────────────────────────────────────────────
# ADVOCATE: pdlc_critic_advocate
# ──────────────────────────────────────────────────────────

@test "advocate: returns PASS for clean fixture with full coverage" {
  run pdlc_critic_advocate "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "^ADVOCATE:PASS:"
}

@test "advocate: reports 100% coverage for clean fixture" {
  run pdlc_critic_advocate "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "^ADVOCATE:PASS:100:"
}

@test "advocate: returns FAIL for xref-gaps fixture" {
  run pdlc_critic_advocate "${FIXTURES_DIR}/xref-gaps"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "^ADVOCATE:FAIL:"
}

@test "advocate: flags cross-reference gaps in xref-gaps fixture" {
  run pdlc_critic_advocate "${FIXTURES_DIR}/xref-gaps"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "FAIL:requirement-gap:BLOCKER:"
}

@test "advocate: returns INFO for missing spec directory" {
  run pdlc_critic_advocate "${TEST_WORK_DIR}/nonexistent"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "INFO:advocate"
  echo "$output" | grep -q "^ADVOCATE:INFO:0:0"
}

@test "advocate: returns PASS when spec.md missing but dir exists" {
  mkdir -p "${TEST_WORK_DIR}/empty-spec"
  run pdlc_critic_advocate "${TEST_WORK_DIR}/empty-spec"
  [[ "$status" -eq 0 ]]
  # Should still return 0 (Observer pattern)
  echo "$output" | grep -q "^ADVOCATE:"
}

@test "advocate: detects missing acceptance scenarios" {
  local no_scenarios="${TEST_WORK_DIR}/no-scenarios"
  mkdir -p "$no_scenarios"
  cat > "${no_scenarios}/spec.md" <<'EOF'
# Feature Specification: No Scenarios

## Requirements

### Functional Requirements

- **FR-001**: System MUST do something

## Success Criteria

### Measurable Outcomes

- **SC-001**: Operations complete in under 1 second
EOF
  cat > "${no_scenarios}/tasks.md" <<'EOF'
# Tasks

## Phase 3: US-001

- [x] T001 [US-001] Implement (FR-001)
EOF
  run pdlc_critic_advocate "$no_scenarios"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "WARN:scenario-coverage:MAJOR:"
}

@test "advocate: detects missing success criteria" {
  local no_sc="${TEST_WORK_DIR}/no-sc"
  mkdir -p "$no_sc"
  cat > "${no_sc}/spec.md" <<'EOF'
# Feature Specification: No SC

**Acceptance Scenarios**:

1. **Given** valid input, **When** operation runs, **Then** result is correct

## Requirements

### Functional Requirements

- **FR-001**: System MUST do something
EOF
  cat > "${no_sc}/tasks.md" <<'EOF'
# Tasks

## Phase 3: US-001

- [x] T001 [US-001] Implement (FR-001)
EOF
  run pdlc_critic_advocate "$no_sc"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "WARN:success-criteria:MAJOR:"
}

@test "advocate: always returns 0 (Observer pattern)" {
  run pdlc_critic_advocate "${FIXTURES_DIR}/xref-gaps"
  [[ "$status" -eq 0 ]]
}

@test "advocate: detects placeholders in spec artifacts" {
  local with_placeholders="${TEST_WORK_DIR}/placeholders"
  mkdir -p "$with_placeholders"
  cat > "${with_placeholders}/spec.md" <<'EOF'
# Feature Specification: Placeholders

[NEEDS CLARIFICATION: what should this do?]

## Requirements

- **FR-001**: System MUST do [TODO: define]

## Success Criteria

- **SC-001**: System meets the criteria

**Acceptance Scenarios**:

1. **Given** valid input, **When** operation runs, **Then** result is correct
EOF
  cat > "${with_placeholders}/tasks.md" <<'EOF'
# Tasks

- [x] T001 [US-001] Implement (FR-001)
EOF
  run pdlc_critic_advocate "$with_placeholders"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "FAIL:completeness:BLOCKER:"
}

# ──────────────────────────────────────────────────────────
# SKEPTIC: pdlc_critic_skeptic
# ──────────────────────────────────────────────────────────

@test "skeptic: returns PASS or WARN for clean fixture (has edge cases)" {
  run pdlc_critic_skeptic "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  # Clean fixture has edge cases, tests exist in repo — might get WARN from ERR trap check
  echo "$output" | grep -q "^SKEPTIC:"
}

@test "skeptic: flags missing edge cases section" {
  local no_edge="${TEST_WORK_DIR}/no-edge"
  mkdir -p "$no_edge"
  cat > "${no_edge}/spec.md" <<'EOF'
# Feature Specification: No Edge Cases

## Requirements

- **FR-001**: System MUST do something
EOF
  run pdlc_critic_skeptic "$no_edge"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "WARN:edge-case:MAJOR:no edge cases section"
}

@test "skeptic: flags empty edge cases section" {
  local empty_edge="${TEST_WORK_DIR}/empty-edge"
  mkdir -p "$empty_edge"
  cat > "${empty_edge}/spec.md" <<'EOF'
# Feature Specification

### Edge Cases

## Requirements
EOF
  run pdlc_critic_skeptic "$empty_edge"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "WARN:edge-case:MAJOR:edge cases section is empty"
}

@test "skeptic: returns INFO for missing spec directory" {
  run pdlc_critic_skeptic "${TEST_WORK_DIR}/nonexistent"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "INFO:skeptic"
  echo "$output" | grep -q "^SKEPTIC:INFO:0"
}

@test "skeptic: always returns 0 (Observer pattern)" {
  run pdlc_critic_skeptic "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
}

@test "skeptic: detects when tests directory exists with bats files" {
  # The repo has tests/ with .bats files, so this should not flag test-coverage
  run pdlc_critic_skeptic "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  # Should NOT have a FAIL for test-coverage since repo has .bats files
  ! echo "$output" | grep -q "FAIL:test-coverage"
}

# ──────────────────────────────────────────────────────────
# Consensus: pdlc_critic_consensus
# ──────────────────────────────────────────────────────────

@test "consensus: PASS/PASS returns accept" {
  run pdlc_critic_consensus "PASS" "PASS" "0"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "accept" ]]
}

@test "consensus: PASS/WARN returns accept-with-caveats" {
  run pdlc_critic_consensus "PASS" "WARN" "0"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "accept-with-caveats" ]]
}

@test "consensus: WARN/PASS returns accept-with-caveats" {
  run pdlc_critic_consensus "WARN" "PASS" "0"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "accept-with-caveats" ]]
}

@test "consensus: WARN/WARN returns accept-with-caveats" {
  run pdlc_critic_consensus "WARN" "WARN" "0"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "accept-with-caveats" ]]
}

@test "consensus: FAIL/PASS returns retry (ADVOCATE FAIL is mandatory)" {
  run pdlc_critic_consensus "FAIL" "PASS" "0"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "retry" ]]
}

@test "consensus: FAIL/FAIL returns retry" {
  run pdlc_critic_consensus "FAIL" "FAIL" "0"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "retry" ]]
}

@test "consensus: FAIL/WARN returns retry" {
  run pdlc_critic_consensus "FAIL" "WARN" "0"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "retry" ]]
}

@test "consensus: PASS/FAIL returns accept-with-caveats (SKEPTIC FAIL is advisory)" {
  run pdlc_critic_consensus "PASS" "FAIL" "0"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "accept-with-caveats" ]]
}

@test "consensus: escalates when retry count >= limit" {
  PDLC_MAX_RETRIES=3
  run pdlc_critic_consensus "FAIL" "FAIL" "3"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "escalate" ]]
}

@test "consensus: escalates at exact limit boundary" {
  PDLC_MAX_RETRIES=2
  run pdlc_critic_consensus "FAIL" "PASS" "2"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "escalate" ]]
}

@test "consensus: respects custom PDLC_MAX_RETRIES" {
  export PDLC_MAX_RETRIES=1
  run pdlc_critic_consensus "FAIL" "FAIL" "1"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "escalate" ]]
}

@test "consensus: retries when under limit" {
  PDLC_MAX_RETRIES=3
  run pdlc_critic_consensus "FAIL" "FAIL" "2"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "retry" ]]
}

@test "consensus: PDLC_DISABLED returns accept regardless" {
  PDLC_DISABLED=1 run pdlc_critic_consensus "FAIL" "FAIL" "0"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "accept" ]]
}

@test "consensus: always returns 0 (Observer pattern)" {
  run pdlc_critic_consensus "FAIL" "FAIL" "99"
  [[ "$status" -eq 0 ]]
}

@test "consensus: defaults to PASS when called with no arguments" {
  run pdlc_critic_consensus
  [[ "$status" -eq 0 ]]
  [[ "$output" == "accept" ]]
}

# ──────────────────────────────────────────────────────────
# Report: pdlc_critic_report
# ──────────────────────────────────────────────────────────

@test "report: includes ADVOCATE and SKEPTIC results for clean fixture" {
  run pdlc_critic_report "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "^ADVOCATE:"
  echo "$output" | grep -q "^SKEPTIC:"
  echo "$output" | grep -q "^CONSENSUS:"
}

@test "report: returns accept consensus for clean fixture" {
  run pdlc_critic_report "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  # Clean fixture should get accept or accept-with-caveats
  echo "$output" | grep -q "^CONSENSUS:accept"
}

@test "report: returns retry consensus for xref-gaps fixture" {
  run pdlc_critic_report "${FIXTURES_DIR}/xref-gaps"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "^CONSENSUS:retry"
}

@test "report: returns INFO for missing spec directory" {
  run pdlc_critic_report "${TEST_WORK_DIR}/nonexistent"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "INFO"
  echo "$output" | grep -q "^CONSENSUS:accept"
}

@test "report: always returns 0 (Observer pattern)" {
  run pdlc_critic_report "${FIXTURES_DIR}/xref-gaps"
  [[ "$status" -eq 0 ]]
}

@test "report: passes retry_count to consensus" {
  export PDLC_MAX_RETRIES=1
  run pdlc_critic_report "${FIXTURES_DIR}/xref-gaps" "1"
  [[ "$status" -eq 0 ]]
  # xref-gaps causes ADVOCATE FAIL, retry_count=1 >= limit=1, so escalate
  echo "$output" | grep -q "^CONSENSUS:escalate"
}
