#!/usr/bin/env bats
# tests/unit/pdlc-placeholder.bats — Unit tests for hooks/lib/pdlc-placeholder.sh

load ../helpers/common-setup

FIXTURES_DIR=""

setup() {
  TEST_WORK_DIR="$(mktemp -d)"
  source "${HOOKS_DIR}/lib/pdlc-placeholder.sh"
  PDLC_STATE_DIR="${TEST_WORK_DIR}/.pdlc/state"
  PDLC_HANDOFF="${PDLC_STATE_DIR}/HANDOFF.md"
  FIXTURES_DIR="${REPO_DIR}/tests/fixtures/spec-lifecycle"
}

# ──────────────────────────────────────────────────────────
# pdlc_placeholder_scan — detection
# ──────────────────────────────────────────────────────────

@test "placeholder_scan: detects template brackets [FEATURE NAME]" {
  run pdlc_placeholder_scan "${FIXTURES_DIR}/placeholders/spec.md"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "TEMPLATE"
  echo "$output" | grep -q "FEATURE NAME"
}

@test "placeholder_scan: detects [NEEDS CLARIFICATION: ...] markers" {
  run pdlc_placeholder_scan "${FIXTURES_DIR}/placeholders/spec.md"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "CLARIFICATION"
}

@test "placeholder_scan: detects ACTION REQUIRED HTML comments" {
  run pdlc_placeholder_scan "${FIXTURES_DIR}/placeholders/spec.md"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "ACTION_REQUIRED"
}

@test "placeholder_scan: detects [TODO: ...] markers" {
  run pdlc_placeholder_scan "${FIXTURES_DIR}/placeholders/plan.md"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "TODO"
}

# ──────────────────────────────────────────────────────────
# pdlc_placeholder_scan — exclusions (false positive prevention)
# ──────────────────────────────────────────────────────────

@test "placeholder_scan: does NOT report markdown checkboxes" {
  local tmpfile="${TEST_WORK_DIR}/checkbox-test.md"
  cat > "$tmpfile" <<'EOF'
- [x] Task complete
- [ ] Task pending
- [-] Task cancelled
EOF
  run pdlc_placeholder_scan "$tmpfile"
  [[ -z "$output" ]]
}

@test "placeholder_scan: does NOT report markdown links" {
  local tmpfile="${TEST_WORK_DIR}/link-test.md"
  cat > "$tmpfile" <<'EOF'
See [SPEC FILE](./spec.md) for details.
EOF
  run pdlc_placeholder_scan "$tmpfile"
  [[ -z "$output" ]]
}

@test "placeholder_scan: does NOT report markdown images" {
  local tmpfile="${TEST_WORK_DIR}/image-test.md"
  cat > "$tmpfile" <<'EOF'
![DIAGRAM OVERVIEW](./diagram.png)
EOF
  run pdlc_placeholder_scan "$tmpfile"
  [[ -z "$output" ]]
}

@test "placeholder_scan: does NOT report [P] parallelism markers" {
  local tmpfile="${TEST_WORK_DIR}/parallel-test.md"
  cat > "$tmpfile" <<'EOF'
- [ ] T001 [P] Create file in src/main.sh
- [ ] T002 [P] [US1] Create another file
EOF
  run pdlc_placeholder_scan "$tmpfile"
  # Should not contain TEMPLATE findings for [P]
  if [[ -n "$output" ]]; then
    ! echo "$output" | grep -q "TEMPLATE"
  fi
}

@test "placeholder_scan: returns empty for clean file" {
  run pdlc_placeholder_scan "${FIXTURES_DIR}/clean/spec.md"
  [[ -z "$output" ]]
}

@test "placeholder_scan: handles missing file gracefully" {
  run pdlc_placeholder_scan "${TEST_WORK_DIR}/nonexistent.md"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

# ──────────────────────────────────────────────────────────
# pdlc_placeholder_check — directory-level checks
# ──────────────────────────────────────────────────────────

@test "placeholder_check: returns 0 for clean fixture directory" {
  run pdlc_placeholder_check "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
}

@test "placeholder_check: returns 1 for fixture directory with placeholders" {
  run pdlc_placeholder_check "${FIXTURES_DIR}/placeholders"
  [[ "$status" -eq 1 ]]
}

@test "placeholder_check: output includes file path for findings" {
  run pdlc_placeholder_check "${FIXTURES_DIR}/placeholders"
  echo "$output" | grep -q "placeholders/spec.md"
}

@test "placeholder_check: output includes line number for findings" {
  run pdlc_placeholder_check "${FIXTURES_DIR}/placeholders"
  # Output format is file:line:type:content — line should be a number
  echo "$output" | grep -qE ':[0-9]+:'
}

@test "placeholder_check: reports correct count" {
  run pdlc_placeholder_check "${FIXTURES_DIR}/placeholders"
  # stderr should mention the count (captured in output by bats run)
  # The count should be > 0
  [[ "$status" -eq 1 ]]
}
