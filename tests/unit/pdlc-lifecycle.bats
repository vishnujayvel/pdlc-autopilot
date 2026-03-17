#!/usr/bin/env bats
# tests/unit/pdlc-lifecycle.bats — Unit tests for hooks/lib/pdlc-lifecycle.sh

load ../helpers/common-setup

setup() {
  TEST_WORK_DIR="$(mktemp -d)"
  source "${HOOKS_DIR}/lib/pdlc-lifecycle.sh"
  PDLC_STATE_DIR="${TEST_WORK_DIR}/.pdlc/state"
  PDLC_HANDOFF="${PDLC_STATE_DIR}/HANDOFF.md"
  PDLC_MARKER="${PDLC_STATE_DIR}/.compact_marker"
}

# ──────────────────────────────────────────────────────────
# pdlc_lifecycle_validate
# ──────────────────────────────────────────────────────────

@test "lifecycle_validate: accepts Draft" {
  run pdlc_lifecycle_validate "Draft"
  [[ "$status" -eq 0 ]]
}

@test "lifecycle_validate: accepts Specified" {
  run pdlc_lifecycle_validate "Specified"
  [[ "$status" -eq 0 ]]
}

@test "lifecycle_validate: accepts Planned" {
  run pdlc_lifecycle_validate "Planned"
  [[ "$status" -eq 0 ]]
}

@test "lifecycle_validate: accepts Tasked" {
  run pdlc_lifecycle_validate "Tasked"
  [[ "$status" -eq 0 ]]
}

@test "lifecycle_validate: accepts Implementing" {
  run pdlc_lifecycle_validate "Implementing"
  [[ "$status" -eq 0 ]]
}

@test "lifecycle_validate: accepts Complete" {
  run pdlc_lifecycle_validate "Complete"
  [[ "$status" -eq 0 ]]
}

@test "lifecycle_validate: accepts Archived" {
  run pdlc_lifecycle_validate "Archived"
  [[ "$status" -eq 0 ]]
}

@test "lifecycle_validate: rejects Bogus" {
  run pdlc_lifecycle_validate "Bogus"
  [[ "$status" -eq 1 ]]
}

@test "lifecycle_validate: rejects empty string" {
  run pdlc_lifecycle_validate ""
  [[ "$status" -eq 1 ]]
}

# ──────────────────────────────────────────────────────────
# pdlc_lifecycle_get
# ──────────────────────────────────────────────────────────

@test "lifecycle_get: returns Draft when field missing" {
  run pdlc_lifecycle_get
  [[ "$status" -eq 0 ]]
  [[ "$output" == "Draft" ]]
}

@test "lifecycle_get: returns Draft when HANDOFF.md missing" {
  run pdlc_lifecycle_get
  [[ "$status" -eq 0 ]]
  [[ "$output" == "Draft" ]]
}

@test "lifecycle_get: returns current state from HANDOFF.md" {
  mkdir -p "${PDLC_STATE_DIR}"
  cat > "${PDLC_HANDOFF}" <<'EOF'
---
phase: ACTOR
spec_lifecycle: Tasked
---
EOF
  run pdlc_lifecycle_get
  [[ "$status" -eq 0 ]]
  [[ "$output" == "Tasked" ]]
}

@test "lifecycle_get: returns Draft when field is empty" {
  mkdir -p "${PDLC_STATE_DIR}"
  cat > "${PDLC_HANDOFF}" <<'EOF'
---
phase: ACTOR
spec_lifecycle:
---
EOF
  run pdlc_lifecycle_get
  [[ "$status" -eq 0 ]]
  [[ "$output" == "Draft" ]]
}

# ──────────────────────────────────────────────────────────
# pdlc_lifecycle_is
# ──────────────────────────────────────────────────────────

@test "lifecycle_is: returns 0 for matching state" {
  mkdir -p "${PDLC_STATE_DIR}"
  cat > "${PDLC_HANDOFF}" <<'EOF'
---
spec_lifecycle: Planned
---
EOF
  run pdlc_lifecycle_is "Planned"
  [[ "$status" -eq 0 ]]
}

@test "lifecycle_is: returns 1 for non-matching state" {
  mkdir -p "${PDLC_STATE_DIR}"
  cat > "${PDLC_HANDOFF}" <<'EOF'
---
spec_lifecycle: Planned
---
EOF
  run pdlc_lifecycle_is "Tasked"
  [[ "$status" -eq 1 ]]
}

@test "lifecycle_is: Draft matches when field missing" {
  run pdlc_lifecycle_is "Draft"
  [[ "$status" -eq 0 ]]
}

# ──────────────────────────────────────────────────────────
# pdlc_lifecycle_can_advance
# ──────────────────────────────────────────────────────────

@test "lifecycle_can_advance: returns 0 for Draft" {
  run pdlc_lifecycle_can_advance
  [[ "$status" -eq 0 ]]
}

@test "lifecycle_can_advance: returns 0 for Implementing" {
  mkdir -p "${PDLC_STATE_DIR}"
  cat > "${PDLC_HANDOFF}" <<'EOF'
---
spec_lifecycle: Implementing
---
EOF
  run pdlc_lifecycle_can_advance
  [[ "$status" -eq 0 ]]
}

@test "lifecycle_can_advance: returns 1 for Archived" {
  mkdir -p "${PDLC_STATE_DIR}"
  cat > "${PDLC_HANDOFF}" <<'EOF'
---
spec_lifecycle: Archived
---
EOF
  run pdlc_lifecycle_can_advance
  [[ "$status" -eq 1 ]]
}

# ──────────────────────────────────────────────────────────
# pdlc_lifecycle_transition — valid transitions
# ──────────────────────────────────────────────────────────

@test "lifecycle_transition: Draft → Specified succeeds" {
  mkdir -p "${PDLC_STATE_DIR}"
  pdlc_write_handoff "spec_lifecycle: Draft" ""
  run pdlc_lifecycle_transition "Specified"
  [[ "$status" -eq 0 ]]
  run pdlc_get_field "spec_lifecycle"
  [[ "$output" == "Specified" ]]
}

@test "lifecycle_transition: Specified → Planned succeeds" {
  mkdir -p "${PDLC_STATE_DIR}"
  pdlc_write_handoff "spec_lifecycle: Specified" ""
  run pdlc_lifecycle_transition "Planned"
  [[ "$status" -eq 0 ]]
  run pdlc_get_field "spec_lifecycle"
  [[ "$output" == "Planned" ]]
}

@test "lifecycle_transition: Planned → Tasked succeeds" {
  mkdir -p "${PDLC_STATE_DIR}"
  pdlc_write_handoff "spec_lifecycle: Planned" ""
  run pdlc_lifecycle_transition "Tasked"
  [[ "$status" -eq 0 ]]
  run pdlc_get_field "spec_lifecycle"
  [[ "$output" == "Tasked" ]]
}

@test "lifecycle_transition: Tasked → Implementing succeeds" {
  mkdir -p "${PDLC_STATE_DIR}"
  pdlc_write_handoff "spec_lifecycle: Tasked" ""
  run pdlc_lifecycle_transition "Implementing"
  [[ "$status" -eq 0 ]]
  run pdlc_get_field "spec_lifecycle"
  [[ "$output" == "Implementing" ]]
}

@test "lifecycle_transition: Implementing → Complete succeeds" {
  mkdir -p "${PDLC_STATE_DIR}"
  pdlc_write_handoff "spec_lifecycle: Implementing" ""
  run pdlc_lifecycle_transition "Complete"
  [[ "$status" -eq 0 ]]
  run pdlc_get_field "spec_lifecycle"
  [[ "$output" == "Complete" ]]
}

@test "lifecycle_transition: Complete → Archived succeeds" {
  mkdir -p "${PDLC_STATE_DIR}"
  pdlc_write_handoff "spec_lifecycle: Complete" ""
  run pdlc_lifecycle_transition "Archived"
  [[ "$status" -eq 0 ]]
  run pdlc_get_field "spec_lifecycle"
  [[ "$output" == "Archived" ]]
}

# ──────────────────────────────────────────────────────────
# pdlc_lifecycle_transition — invalid transitions
# ──────────────────────────────────────────────────────────

@test "lifecycle_transition: Draft → Tasked fails (skip)" {
  mkdir -p "${PDLC_STATE_DIR}"
  pdlc_write_handoff "spec_lifecycle: Draft" ""
  run pdlc_lifecycle_transition "Tasked"
  [[ "$status" -eq 1 ]]
  # State unchanged
  run pdlc_get_field "spec_lifecycle"
  [[ "$output" == "Draft" ]]
}

@test "lifecycle_transition: Archived → Draft fails (terminal)" {
  mkdir -p "${PDLC_STATE_DIR}"
  pdlc_write_handoff "spec_lifecycle: Archived" ""
  run pdlc_lifecycle_transition "Draft"
  [[ "$status" -eq 1 ]]
  # State unchanged
  run pdlc_get_field "spec_lifecycle"
  [[ "$output" == "Archived" ]]
}

@test "lifecycle_transition: Complete → Planned fails (reverse)" {
  mkdir -p "${PDLC_STATE_DIR}"
  pdlc_write_handoff "spec_lifecycle: Complete" ""
  run pdlc_lifecycle_transition "Planned"
  [[ "$status" -eq 1 ]]
  # State unchanged
  run pdlc_get_field "spec_lifecycle"
  [[ "$output" == "Complete" ]]
}

@test "lifecycle_transition: rejects invalid target state" {
  mkdir -p "${PDLC_STATE_DIR}"
  pdlc_write_handoff "spec_lifecycle: Draft" ""
  run pdlc_lifecycle_transition "InvalidState"
  [[ "$status" -eq 1 ]]
}

# ──────────────────────────────────────────────────────────
# pdlc_lifecycle_infer
# ──────────────────────────────────────────────────────────

@test "lifecycle_infer: returns Draft for empty directory" {
  local tmpdir="${TEST_WORK_DIR}/empty-spec"
  mkdir -p "$tmpdir"
  run pdlc_lifecycle_infer "$tmpdir"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "Draft" ]]
}

@test "lifecycle_infer: returns Draft for spec.md with placeholders" {
  # Use a temp dir with ONLY the placeholder spec (no plan.md)
  local tmpdir="${TEST_WORK_DIR}/draft-spec"
  mkdir -p "$tmpdir"
  cp "${REPO_DIR}/tests/fixtures/spec-lifecycle/placeholders/spec.md" "$tmpdir/spec.md"
  run pdlc_lifecycle_infer "$tmpdir"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "Draft" ]]
}

@test "lifecycle_infer: returns Specified for clean spec.md without plan" {
  local tmpdir="${TEST_WORK_DIR}/specified-spec"
  mkdir -p "$tmpdir"
  # Copy clean spec but not plan or tasks
  cp "${REPO_DIR}/tests/fixtures/spec-lifecycle/clean/spec.md" "$tmpdir/spec.md"
  run pdlc_lifecycle_infer "$tmpdir"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "Specified" ]]
}

@test "lifecycle_infer: returns Planned for spec.md + plan.md" {
  local tmpdir="${TEST_WORK_DIR}/planned-spec"
  mkdir -p "$tmpdir"
  cp "${REPO_DIR}/tests/fixtures/spec-lifecycle/clean/spec.md" "$tmpdir/spec.md"
  echo "# Plan" > "$tmpdir/plan.md"
  run pdlc_lifecycle_infer "$tmpdir"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "Planned" ]]
}

@test "lifecycle_infer: returns Tasked for tasks.md with no tasks checked" {
  local tmpdir="${TEST_WORK_DIR}/tasked-spec"
  mkdir -p "$tmpdir"
  cp "${REPO_DIR}/tests/fixtures/spec-lifecycle/clean/spec.md" "$tmpdir/spec.md"
  echo "# Plan" > "$tmpdir/plan.md"
  printf '# Tasks\n\n- [ ] T001 First task\n- [ ] T002 Second task\n' > "$tmpdir/tasks.md"
  run pdlc_lifecycle_infer "$tmpdir"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "Tasked" ]]
}

@test "lifecycle_infer: returns Implementing for mixed tasks" {
  run pdlc_lifecycle_infer "${REPO_DIR}/tests/fixtures/spec-lifecycle/implementing"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "Implementing" ]]
}

@test "lifecycle_infer: returns Complete for all tasks done" {
  run pdlc_lifecycle_infer "${REPO_DIR}/tests/fixtures/spec-lifecycle/complete"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "Complete" ]]
}

@test "lifecycle_infer: returns Archived when HANDOFF.md says Archived" {
  mkdir -p "${PDLC_STATE_DIR}"
  pdlc_write_handoff "spec_lifecycle: Archived" ""
  run pdlc_lifecycle_infer "${REPO_DIR}/tests/fixtures/spec-lifecycle/complete"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "Archived" ]]
}

@test "lifecycle_infer: returns Tasked for inconsistent (tasks without plan)" {
  run pdlc_lifecycle_infer "${REPO_DIR}/tests/fixtures/spec-lifecycle/inconsistent"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "Tasked" ]]
}
