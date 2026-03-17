#!/usr/bin/env bats
# tests/unit/pdlc-freshness.bats — Unit tests for hooks/lib/pdlc-freshness.sh

load ../helpers/common-setup

setup() {
  TEST_WORK_DIR="$(mktemp -d)"
  source "${HOOKS_DIR}/lib/pdlc-freshness.sh"
  PDLC_STATE_DIR="${TEST_WORK_DIR}/.pdlc/state"
  PDLC_HANDOFF="${PDLC_STATE_DIR}/HANDOFF.md"
}

# ──────────────────────────────────────────────────────────
# US1: pdlc_freshness_check_drift
# ──────────────────────────────────────────────────────────

@test "freshness_drift: returns FRESH when spec is newer than sources" {
  local spec_dir="${TEST_WORK_DIR}/spec"
  mkdir -p "$spec_dir"
  # Create spec artifact with current time
  echo "# Spec" > "$spec_dir/spec.md"
  # Create source dir with older file
  mkdir -p "${TEST_WORK_DIR}/hooks"
  echo "# Hook" > "${TEST_WORK_DIR}/hooks/test.sh"
  touch -t 202601010000 "${TEST_WORK_DIR}/hooks/test.sh"
  # Override source dirs to test dir
  PDLC_SOURCE_DIRS=("${TEST_WORK_DIR}/hooks/")
  run pdlc_freshness_check_drift "$spec_dir"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "FRESH" ]]
}

@test "freshness_drift: returns DRIFT when source is newer than spec" {
  local spec_dir="${TEST_WORK_DIR}/spec"
  mkdir -p "$spec_dir"
  # Create old spec artifact
  echo "# Spec" > "$spec_dir/spec.md"
  touch -t 202601010000 "$spec_dir/spec.md"
  # Create source dir with newer file
  mkdir -p "${TEST_WORK_DIR}/hooks"
  echo "# Hook" > "${TEST_WORK_DIR}/hooks/test.sh"
  PDLC_SOURCE_DIRS=("${TEST_WORK_DIR}/hooks/")
  run pdlc_freshness_check_drift "$spec_dir"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "DRIFT"
}

@test "freshness_drift: returns FRESH when no source dirs exist" {
  local spec_dir="${TEST_WORK_DIR}/spec"
  mkdir -p "$spec_dir"
  echo "# Spec" > "$spec_dir/spec.md"
  PDLC_SOURCE_DIRS=("${TEST_WORK_DIR}/nonexistent/")
  run pdlc_freshness_check_drift "$spec_dir"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "FRESH" ]]
}

@test "freshness_drift: handles missing spec directory" {
  run pdlc_freshness_check_drift "${TEST_WORK_DIR}/nonexistent"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "INFO"
}

# ──────────────────────────────────────────────────────────
# US2: pdlc_freshness_check_session
# ──────────────────────────────────────────────────────────

@test "freshness_session: returns FRESH for recent HANDOFF.md" {
  mkdir -p "${PDLC_STATE_DIR}"
  echo "---" > "${PDLC_HANDOFF}"
  echo "phase: ACTOR" >> "${PDLC_HANDOFF}"
  echo "---" >> "${PDLC_HANDOFF}"
  PDLC_FRESHNESS_THRESHOLD_DAYS=7
  run pdlc_freshness_check_session
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "SESSION:FRESH"
}

@test "freshness_session: returns STALE for old HANDOFF.md" {
  mkdir -p "${PDLC_STATE_DIR}"
  echo "---" > "${PDLC_HANDOFF}"
  echo "phase: ACTOR" >> "${PDLC_HANDOFF}"
  echo "---" >> "${PDLC_HANDOFF}"
  # Set mtime to 30 days ago
  touch -t 202602150000 "${PDLC_HANDOFF}"
  PDLC_FRESHNESS_THRESHOLD_DAYS=7
  run pdlc_freshness_check_session
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "SESSION:STALE"
}

@test "freshness_session: returns NONE when HANDOFF.md missing" {
  run pdlc_freshness_check_session
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "SESSION:NONE"
}

@test "freshness_session: respects custom threshold" {
  mkdir -p "${PDLC_STATE_DIR}"
  echo "---" > "${PDLC_HANDOFF}"
  echo "phase: ACTOR" >> "${PDLC_HANDOFF}"
  echo "---" >> "${PDLC_HANDOFF}"
  # Set mtime to 2 days ago
  local two_days_ago
  two_days_ago=$(date -v-2d +%Y%m%d0000 2>/dev/null || date -d "2 days ago" +%Y%m%d0000 2>/dev/null)
  if [[ -n "$two_days_ago" ]]; then
    touch -t "$two_days_ago" "${PDLC_HANDOFF}"
  fi
  PDLC_FRESHNESS_THRESHOLD_DAYS=1
  run pdlc_freshness_check_session
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "SESSION:STALE"
}

# ──────────────────────────────────────────────────────────
# US3: pdlc_freshness_report
# ──────────────────────────────────────────────────────────

@test "freshness_report: includes artifact ages" {
  local spec_dir="${TEST_WORK_DIR}/spec"
  mkdir -p "$spec_dir" "${PDLC_STATE_DIR}"
  echo "# Spec" > "$spec_dir/spec.md"
  echo "# Plan" > "$spec_dir/plan.md"
  pdlc_write_handoff "phase: ACTOR" ""
  PDLC_SOURCE_DIRS=("${TEST_WORK_DIR}/nonexistent/")
  run pdlc_freshness_report "$spec_dir"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "spec.md:"
  echo "$output" | grep -q "plan.md:"
}

@test "freshness_report: overall FRESH when all checks pass" {
  local spec_dir="${TEST_WORK_DIR}/spec"
  mkdir -p "$spec_dir" "${PDLC_STATE_DIR}"
  echo "# Spec" > "$spec_dir/spec.md"
  pdlc_write_handoff "phase: ACTOR" ""
  PDLC_SOURCE_DIRS=("${TEST_WORK_DIR}/nonexistent/")
  PDLC_FRESHNESS_THRESHOLD_DAYS=30
  run pdlc_freshness_report "$spec_dir"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "Overall: FRESH"
}

@test "freshness_report: overall STALE when session is stale" {
  local spec_dir="${TEST_WORK_DIR}/spec"
  mkdir -p "$spec_dir" "${PDLC_STATE_DIR}"
  echo "# Spec" > "$spec_dir/spec.md"
  pdlc_write_handoff "phase: ACTOR" ""
  touch -t 202601010000 "${PDLC_HANDOFF}"
  PDLC_SOURCE_DIRS=("${TEST_WORK_DIR}/nonexistent/")
  PDLC_FRESHNESS_THRESHOLD_DAYS=7
  run pdlc_freshness_report "$spec_dir"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "Overall: STALE"
}
