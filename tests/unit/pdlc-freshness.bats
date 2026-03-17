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
# pdlc_freshness_extract_date
# ──────────────────────────────────────────────────────────

@test "freshness_extract_date: extracts created date" {
  local tmpfile="${TEST_WORK_DIR}/spec.md"
  cat > "$tmpfile" <<'EOF'
# Feature Specification: Test

**Created**: 2026-03-15
**Last Updated**: 2026-03-17
**Status**: Draft
EOF
  run pdlc_freshness_extract_date "$tmpfile" "created"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "2026-03-15" ]]
}

@test "freshness_extract_date: extracts last_updated date" {
  local tmpfile="${TEST_WORK_DIR}/spec.md"
  cat > "$tmpfile" <<'EOF'
# Feature Specification: Test

**Created**: 2026-03-15
**Last Updated**: 2026-03-17
**Status**: Draft
EOF
  run pdlc_freshness_extract_date "$tmpfile" "last_updated"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "2026-03-17" ]]
}

@test "freshness_extract_date: returns empty for missing field" {
  local tmpfile="${TEST_WORK_DIR}/spec.md"
  echo "# No date fields here" > "$tmpfile"
  run pdlc_freshness_extract_date "$tmpfile" "last_updated"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "freshness_extract_date: returns empty for missing file" {
  run pdlc_freshness_extract_date "${TEST_WORK_DIR}/nonexistent.md" "created"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

# ──────────────────────────────────────────────────────────
# pdlc_freshness_artifact_age
# ──────────────────────────────────────────────────────────

@test "freshness_artifact_age: uses last_updated over created" {
  local tmpfile="${TEST_WORK_DIR}/spec.md"
  local today
  today=$(date +%Y-%m-%d)
  cat > "$tmpfile" <<EOF
# Spec
**Created**: 2026-01-01
**Last Updated**: ${today}
EOF
  run pdlc_freshness_artifact_age "$tmpfile"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "0" ]]
}

@test "freshness_artifact_age: falls back to created when no last_updated" {
  local tmpfile="${TEST_WORK_DIR}/spec.md"
  local today
  today=$(date +%Y-%m-%d)
  cat > "$tmpfile" <<EOF
# Spec
**Created**: ${today}
EOF
  run pdlc_freshness_artifact_age "$tmpfile"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "0" ]]
}

@test "freshness_artifact_age: falls back to mtime when no date fields" {
  local tmpfile="${TEST_WORK_DIR}/spec.md"
  echo "# No dates" > "$tmpfile"
  run pdlc_freshness_artifact_age "$tmpfile"
  [[ "$status" -eq 0 ]]
  # Should return 0 (just created)
  [[ "$output" == "0" ]]
}

# ──────────────────────────────────────────────────────────
# pdlc_freshness_check_drift
# ──────────────────────────────────────────────────────────

@test "freshness_drift: returns FRESH when spec date is recent" {
  local spec_dir="${TEST_WORK_DIR}/spec"
  mkdir -p "$spec_dir"
  local today
  today=$(date +%Y-%m-%d)
  cat > "$spec_dir/spec.md" <<EOF
# Spec
**Created**: ${today}
**Last Updated**: ${today}
EOF
  # Create source dir with older file
  mkdir -p "${TEST_WORK_DIR}/hooks"
  echo "# Hook" > "${TEST_WORK_DIR}/hooks/test.sh"
  touch -t 202601010000 "${TEST_WORK_DIR}/hooks/test.sh"
  PDLC_SOURCE_DIRS=("${TEST_WORK_DIR}/hooks/")
  run pdlc_freshness_check_drift "$spec_dir"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "FRESH" ]]
}

@test "freshness_drift: returns DRIFT when spec date is old" {
  local spec_dir="${TEST_WORK_DIR}/spec"
  mkdir -p "$spec_dir"
  cat > "$spec_dir/spec.md" <<'EOF'
# Spec
**Created**: 2026-01-01
**Last Updated**: 2026-01-01
EOF
  # Create source dir with newer file (just created = today)
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
# pdlc_freshness_check_session
# ──────────────────────────────────────────────────────────

@test "freshness_session: uses last_session_date field when available" {
  mkdir -p "${PDLC_STATE_DIR}"
  local today
  today=$(date +%Y-%m-%d)
  pdlc_write_handoff "phase: ACTOR
last_session_date: ${today}" ""
  PDLC_FRESHNESS_THRESHOLD_DAYS=7
  run pdlc_freshness_check_session
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "SESSION:FRESH"
}

@test "freshness_session: detects stale via last_session_date field" {
  mkdir -p "${PDLC_STATE_DIR}"
  pdlc_write_handoff "phase: ACTOR
last_session_date: 2026-01-01" ""
  PDLC_FRESHNESS_THRESHOLD_DAYS=7
  run pdlc_freshness_check_session
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "SESSION:STALE"
}

@test "freshness_session: falls back to mtime when no date field" {
  mkdir -p "${PDLC_STATE_DIR}"
  pdlc_write_handoff "phase: ACTOR" ""
  PDLC_FRESHNESS_THRESHOLD_DAYS=7
  run pdlc_freshness_check_session
  [[ "$status" -eq 0 ]]
  # Just created, so should be FRESH via mtime fallback
  echo "$output" | grep -q "SESSION:FRESH"
}

@test "freshness_session: returns NONE when HANDOFF.md missing" {
  run pdlc_freshness_check_session
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "SESSION:NONE"
}

@test "freshness_session: respects custom threshold" {
  mkdir -p "${PDLC_STATE_DIR}"
  pdlc_write_handoff "phase: ACTOR
last_session_date: 2026-03-10" ""
  PDLC_FRESHNESS_THRESHOLD_DAYS=3
  run pdlc_freshness_check_session
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "SESSION:STALE"
}

# ──────────────────────────────────────────────────────────
# pdlc_freshness_report
# ──────────────────────────────────────────────────────────

@test "freshness_report: includes artifact ages" {
  local spec_dir="${TEST_WORK_DIR}/spec"
  local today
  today=$(date +%Y-%m-%d)
  mkdir -p "$spec_dir" "${PDLC_STATE_DIR}"
  cat > "$spec_dir/spec.md" <<EOF
# Spec
**Created**: ${today}
EOF
  echo "# Plan" > "$spec_dir/plan.md"
  pdlc_write_handoff "phase: ACTOR
last_session_date: ${today}" ""
  PDLC_SOURCE_DIRS=("${TEST_WORK_DIR}/nonexistent/")
  run pdlc_freshness_report "$spec_dir"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "spec.md:"
  echo "$output" | grep -q "plan.md:"
}

@test "freshness_report: overall FRESH when all checks pass" {
  local spec_dir="${TEST_WORK_DIR}/spec"
  local today
  today=$(date +%Y-%m-%d)
  mkdir -p "$spec_dir" "${PDLC_STATE_DIR}"
  cat > "$spec_dir/spec.md" <<EOF
# Spec
**Created**: ${today}
EOF
  pdlc_write_handoff "phase: ACTOR
last_session_date: ${today}" ""
  PDLC_SOURCE_DIRS=("${TEST_WORK_DIR}/nonexistent/")
  PDLC_FRESHNESS_THRESHOLD_DAYS=30
  run pdlc_freshness_report "$spec_dir"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "Overall: FRESH"
}

@test "freshness_report: overall STALE when session is stale" {
  local spec_dir="${TEST_WORK_DIR}/spec"
  local today
  today=$(date +%Y-%m-%d)
  mkdir -p "$spec_dir" "${PDLC_STATE_DIR}"
  cat > "$spec_dir/spec.md" <<EOF
# Spec
**Created**: ${today}
EOF
  pdlc_write_handoff "phase: ACTOR
last_session_date: 2026-01-01" ""
  PDLC_SOURCE_DIRS=("${TEST_WORK_DIR}/nonexistent/")
  PDLC_FRESHNESS_THRESHOLD_DAYS=7
  run pdlc_freshness_report "$spec_dir"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "Overall: STALE"
}
