#!/usr/bin/env bats
# tests/unit/pdlc-test-strategy.bats — Unit tests for hooks/lib/pdlc-test-strategy.sh

load ../helpers/common-setup

FIXTURES_DIR=""

setup() {
  TEST_WORK_DIR="$(mktemp -d)"
  source "${HOOKS_DIR}/lib/pdlc-test-strategy.sh"
  FIXTURES_DIR="${REPO_DIR}/tests/fixtures/spec-lifecycle"
}

teardown() {
  rm -rf "${TEST_WORK_DIR}"
}

# ──────────────────────────────────────────────────────────
# Graceful degradation
# ──────────────────────────────────────────────────────────

@test "test_strategy: returns INFO for empty spec directory" {
  run pdlc_test_strategy "${TEST_WORK_DIR}/nonexistent"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "INFO"
}

@test "test_strategy: returns INFO for missing spec.md" {
  mkdir -p "${TEST_WORK_DIR}/empty-spec"
  run pdlc_test_strategy "${TEST_WORK_DIR}/empty-spec"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "INFO"
}

@test "test_strategy: returns INFO for empty argument" {
  run pdlc_test_strategy ""
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "INFO"
}

@test "test_strategy: always returns 0 (Observer pattern)" {
  run pdlc_test_strategy "${TEST_WORK_DIR}/nonexistent"
  [[ "$status" -eq 0 ]]
}

# ──────────────────────────────────────────────────────────
# Spec analysis — clean fixture
# ──────────────────────────────────────────────────────────

@test "test_strategy: counts user stories from clean fixture" {
  run pdlc_test_strategy "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "User stories: 2"
}

@test "test_strategy: counts acceptance scenarios from clean fixture" {
  run pdlc_test_strategy "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "Acceptance scenarios: 2"
}

@test "test_strategy: counts requirements from clean fixture" {
  run pdlc_test_strategy "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "Requirements: 3"
}

@test "test_strategy: counts edge cases from clean fixture" {
  run pdlc_test_strategy "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "Edge cases: 2"
}

# ──────────────────────────────────────────────────────────
# Test type recommendations
# ──────────────────────────────────────────────────────────

@test "test_strategy: recommends unit tests for any spec" {
  run pdlc_test_strategy "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "Unit tests: yes"
}

@test "test_strategy: recommends integration tests for multi-story spec" {
  run pdlc_test_strategy "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "Integration tests: yes"
}

@test "test_strategy: does not recommend integration for single-story spec" {
  local single_story="${TEST_WORK_DIR}/single-story"
  mkdir -p "$single_story"
  cat > "${single_story}/spec.md" <<'EOF'
# Feature Specification: Single Story

### User Story 1 - Only Story (Priority: P1)

As a user, I want one thing.

**Acceptance Scenarios**:

1. **Given** input, **When** action, **Then** result

## Requirements

- **FR-001**: System MUST work
EOF
  run pdlc_test_strategy "$single_story"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "Integration tests: no"
}

@test "test_strategy: recommends integration when spec mentions interaction" {
  local interact_spec="${TEST_WORK_DIR}/interact-spec"
  mkdir -p "$interact_spec"
  cat > "${interact_spec}/spec.md" <<'EOF'
# Feature Specification: Interaction Test

### User Story 1 - Integration (Priority: P1)

As a user, I want components to interact properly.

## Requirements

- **FR-001**: System MUST integrate with external service
EOF
  run pdlc_test_strategy "$interact_spec"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "Integration tests: yes"
}

@test "test_strategy: recommends e2e tests when spec mentions workflow" {
  local workflow_spec="${TEST_WORK_DIR}/workflow-spec"
  mkdir -p "$workflow_spec"
  cat > "${workflow_spec}/spec.md" <<'EOF'
# Feature Specification: Workflow Test

### User Story 1 - End-to-End (Priority: P1)

As a user, I want an end-to-end workflow that spans multiple phases.

## Requirements

- **FR-001**: System MUST support e2e testing
EOF
  run pdlc_test_strategy "$workflow_spec"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "E2E tests: yes"
}

# ──────────────────────────────────────────────────────────
# Plan.md integration
# ──────────────────────────────────────────────────────────

@test "test_strategy: defaults to BATS framework" {
  run pdlc_test_strategy "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "framework: BATS"
}

@test "test_strategy: detects framework from plan.md" {
  local with_plan="${TEST_WORK_DIR}/with-plan"
  mkdir -p "$with_plan"
  cat > "${with_plan}/spec.md" <<'EOF'
# Feature Specification: Plan Test

### User Story 1 - Test (Priority: P1)

As a user, I want testing.

## Requirements

- **FR-001**: System MUST work
EOF
  cat > "${with_plan}/plan.md" <<'EOF'
# Implementation Plan

## Technical Context

- **Test Framework**: Jest for unit tests
EOF
  run pdlc_test_strategy "$with_plan"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "framework: Jest"
}

@test "test_strategy: notes when plan.md is missing" {
  local no_plan="${TEST_WORK_DIR}/no-plan"
  mkdir -p "$no_plan"
  cat > "${no_plan}/spec.md" <<'EOF'
# Feature Specification: No Plan

### User Story 1 - Test (Priority: P1)

As a user, I want testing.

## Requirements

- **FR-001**: System MUST work
EOF
  run pdlc_test_strategy "$no_plan"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "No plan.md found"
}

# ──────────────────────────────────────────────────────────
# TDD recommendation
# ──────────────────────────────────────────────────────────

@test "test_strategy: recommends TDD when acceptance scenarios exist" {
  run pdlc_test_strategy "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "TDD Recommendation"
  echo "$output" | grep -q "yes"
}

@test "test_strategy: suggests adding scenarios when none exist" {
  local no_scenarios="${TEST_WORK_DIR}/no-scenarios"
  mkdir -p "$no_scenarios"
  cat > "${no_scenarios}/spec.md" <<'EOF'
# Feature Specification: No Scenarios

### User Story 1 - Test (Priority: P1)

As a user, I want testing.

## Requirements

- **FR-001**: System MUST work
EOF
  run pdlc_test_strategy "$no_scenarios"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "add acceptance scenarios first"
}

# ──────────────────────────────────────────────────────────
# PDLC_DISABLED
# ──────────────────────────────────────────────────────────

@test "test_strategy: notes informational mode when PDLC_DISABLED=1" {
  PDLC_DISABLED=1 run pdlc_test_strategy "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "informational"
}

# ──────────────────────────────────────────────────────────
# Coverage targets
# ──────────────────────────────────────────────────────────

@test "test_strategy: includes coverage targets with scenario and edge case counts" {
  run pdlc_test_strategy "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "Coverage Targets"
  echo "$output" | grep -q "2 acceptance scenarios"
  echo "$output" | grep -q "2 edge cases"
}
