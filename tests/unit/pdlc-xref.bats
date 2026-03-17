#!/usr/bin/env bats
# tests/unit/pdlc-xref.bats — Unit tests for hooks/lib/pdlc-xref.sh

load ../helpers/common-setup

FIXTURES_DIR=""

setup() {
  TEST_WORK_DIR="$(mktemp -d)"
  source "${HOOKS_DIR}/lib/pdlc-xref.sh"
  PDLC_STATE_DIR="${TEST_WORK_DIR}/.pdlc/state"
  PDLC_HANDOFF="${PDLC_STATE_DIR}/HANDOFF.md"
  FIXTURES_DIR="${REPO_DIR}/tests/fixtures/spec-lifecycle"
}

# ──────────────────────────────────────────────────────────
# pdlc_xref_extract_fr_ids
# ──────────────────────────────────────────────────────────

@test "xref_extract_fr_ids: extracts FR-001 through FR-005 from xref-gaps spec" {
  run pdlc_xref_extract_fr_ids "${FIXTURES_DIR}/xref-gaps/spec.md"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "FR-001"
  echo "$output" | grep -q "FR-002"
  echo "$output" | grep -q "FR-003"
  echo "$output" | grep -q "FR-004"
  echo "$output" | grep -q "FR-005"
}

@test "xref_extract_fr_ids: extracts FR-001 through FR-003 from clean spec" {
  run pdlc_xref_extract_fr_ids "${FIXTURES_DIR}/clean/spec.md"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "FR-001"
  echo "$output" | grep -q "FR-002"
  echo "$output" | grep -q "FR-003"
  # Should NOT have FR-004 or FR-005
  ! echo "$output" | grep -q "FR-004"
}

@test "xref_extract_fr_ids: returns sorted unique list" {
  run pdlc_xref_extract_fr_ids "${FIXTURES_DIR}/xref-gaps/spec.md"
  [[ "$status" -eq 0 ]]
  local count
  count=$(echo "$output" | wc -l | tr -d ' ')
  [[ "$count" -eq 5 ]]
}

@test "xref_extract_fr_ids: handles missing file" {
  run pdlc_xref_extract_fr_ids "${TEST_WORK_DIR}/nonexistent.md"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

# ──────────────────────────────────────────────────────────
# pdlc_xref_extract_us_ids
# ──────────────────────────────────────────────────────────

@test "xref_extract_us_ids: extracts US-001 through US-003 from xref-gaps spec" {
  run pdlc_xref_extract_us_ids "${FIXTURES_DIR}/xref-gaps/spec.md"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "US-001"
  echo "$output" | grep -q "US-002"
  echo "$output" | grep -q "US-003"
}

@test "xref_extract_us_ids: handles missing file" {
  run pdlc_xref_extract_us_ids "${TEST_WORK_DIR}/nonexistent.md"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

# ──────────────────────────────────────────────────────────
# pdlc_xref_check
# ──────────────────────────────────────────────────────────

@test "xref_check: returns 0 for clean fixture (all refs resolve)" {
  run pdlc_xref_check "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
}

@test "xref_check: returns 1 for xref-gaps fixture (gaps exist)" {
  run pdlc_xref_check "${FIXTURES_DIR}/xref-gaps"
  [[ "$status" -eq 1 ]]
}

@test "xref_check: reports FR-004 as unreferenced" {
  run pdlc_xref_check "${FIXTURES_DIR}/xref-gaps"
  echo "$output" | grep -q "UNREFERENCED:FR-004"
}

@test "xref_check: reports FR-005 as unreferenced" {
  run pdlc_xref_check "${FIXTURES_DIR}/xref-gaps"
  echo "$output" | grep -q "UNREFERENCED:FR-005"
}

@test "xref_check: reports US-004 as orphaned reference" {
  run pdlc_xref_check "${FIXTURES_DIR}/xref-gaps"
  echo "$output" | grep -q "ORPHANED:US-004"
}

@test "xref_check: skips gracefully when tasks.md missing" {
  local tmpdir="${TEST_WORK_DIR}/no-tasks"
  mkdir -p "$tmpdir"
  cp "${FIXTURES_DIR}/clean/spec.md" "$tmpdir/spec.md"
  # No tasks.md — should return 0
  run pdlc_xref_check "$tmpdir"
  [[ "$status" -eq 0 ]]
}

@test "xref_check: skips gracefully when spec.md missing" {
  local tmpdir="${TEST_WORK_DIR}/no-spec"
  mkdir -p "$tmpdir"
  echo "# Tasks" > "$tmpdir/tasks.md"
  # No spec.md — should return 0
  run pdlc_xref_check "$tmpdir"
  [[ "$status" -eq 0 ]]
}
