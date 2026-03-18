#!/usr/bin/env bats
# tests/unit/pdlc-session.bats — Unit tests for hooks/lib/pdlc-session.sh

load ../helpers/common-setup

setup() {
  TEST_WORK_DIR="$(mktemp -d)"
  source "${HOOKS_DIR}/lib/pdlc-state.sh"
  PDLC_STATE_DIR="${TEST_WORK_DIR}/.pdlc/state"
  PDLC_HANDOFF="${PDLC_STATE_DIR}/HANDOFF.md"
  PDLC_MARKER="${PDLC_STATE_DIR}/.compact_marker"
  source "${HOOKS_DIR}/lib/pdlc-session.sh"
}

teardown() {
  rm -rf "${TEST_WORK_DIR}"
}

# ──────────────────────────────────────────────────────────
# REQ-SP-004: pdlc_session_save
# ──────────────────────────────────────────────────────────

@test "session_save: writes checkpoint section to HANDOFF.md body" {
  pdlc_write_handoff "phase: ACTOR
batch: 1
spec_dir: .claude/specs/feat" "## Current Batch Context

Starting session."

  pdlc_session_save "3" "Implementing" \
    "implement|spawn|Heavy work" "success (3 files changed)" "accept"

  grep -q "### Session Checkpoint" "${PDLC_HANDOFF}"
}

@test "session_save: checkpoint contains iteration number" {
  pdlc_write_handoff "phase: ACTOR
batch: 1" "## Context"

  pdlc_session_save "5" "Implementing" \
    "implement|spawn|Work" "success" "accept"

  grep -q "Iteration: 5" "${PDLC_HANDOFF}"
}

@test "session_save: checkpoint contains lifecycle state" {
  pdlc_write_handoff "phase: ACTOR
batch: 1" "## Context"

  pdlc_session_save "1" "Tasked" \
    "implement|same-session|Start" "pending" "accept"

  grep -q "Lifecycle: Tasked" "${PDLC_HANDOFF}"
}

# ──────────────────────────────────────────────────────────
# REQ-SP-001: Director dispatch decisions persisted
# ──────────────────────────────────────────────────────────

@test "session_save: checkpoint contains Director decision" {
  pdlc_write_handoff "phase: ACTOR
batch: 1" "## Context"

  pdlc_session_save "2" "Implementing" \
    "implement|spawn|Heavy implementation work" "success" "accept"

  grep -q "Director: implement|spawn|Heavy implementation work" "${PDLC_HANDOFF}"
}

# ──────────────────────────────────────────────────────────
# REQ-SP-002: Quality gate results persisted
# ──────────────────────────────────────────────────────────

@test "session_save: checkpoint contains quality line with advocate/skeptic" {
  pdlc_write_handoff "phase: ACTOR
batch: 1
batch_1_advocate: PASS
batch_1_skeptic: PASS_WARN" "## Context"

  pdlc_session_save "1" "Implementing" \
    "implement|spawn|Work" "success" "accept"

  grep -q "Quality: advocate=PASS, skeptic=PASS_WARN" "${PDLC_HANDOFF}"
}

@test "session_save: quality line shows N/A when no critic results" {
  pdlc_write_handoff "phase: ACTOR
batch: 1" "## Context"

  pdlc_session_save "1" "Implementing" \
    "implement|spawn|Work" "success" "accept"

  grep -q "Quality: N/A" "${PDLC_HANDOFF}"
}

# ──────────────────────────────────────────────────────────
# REQ-SP-003: Checkpoint contains all required fields
# ──────────────────────────────────────────────────────────

@test "session_save: checkpoint contains Actor result" {
  pdlc_write_handoff "phase: ACTOR
batch: 1" "## Context"

  pdlc_session_save "1" "Implementing" \
    "implement|spawn|Work" "success (3 files changed)" "accept"

  grep -q "Actor: success (3 files changed)" "${PDLC_HANDOFF}"
}

@test "session_save: checkpoint contains Critic verdict" {
  pdlc_write_handoff "phase: ACTOR
batch: 1" "## Context"

  pdlc_session_save "1" "Implementing" \
    "implement|spawn|Work" "success" "retry"

  grep -q "Critic: retry" "${PDLC_HANDOFF}"
}

@test "session_save: checkpoint contains timestamp" {
  pdlc_write_handoff "phase: ACTOR
batch: 1" "## Context"

  pdlc_session_save "1" "Implementing" \
    "implement|spawn|Work" "success" "accept"

  grep -qE "Timestamp: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z" "${PDLC_HANDOFF}"
}

# ──────────────────────────────────────────────────────────
# REQ-SP-004: Atomic writes (no corruption)
# ──────────────────────────────────────────────────────────

@test "session_save: frontmatter preserved after save" {
  pdlc_write_handoff "phase: ACTOR
batch: 1
spec_dir: .claude/specs/feat" "## Context"

  pdlc_session_save "1" "Implementing" \
    "implement|spawn|Work" "success" "accept"

  run pdlc_get_field "phase"
  [[ "$output" == "ACTOR" ]]
  run pdlc_get_field "batch"
  [[ "$output" == "1" ]]
  run pdlc_get_field "spec_dir"
  [[ "$output" == ".claude/specs/feat" ]]
}

@test "session_save: existing body content preserved" {
  pdlc_write_handoff "phase: ACTOR
batch: 1" "## Current Batch Context

Starting session.

## Key Decisions

Used TDD approach."

  pdlc_session_save "1" "Implementing" \
    "implement|spawn|Work" "success" "accept"

  grep -q "## Current Batch Context" "${PDLC_HANDOFF}"
  grep -q "Starting session." "${PDLC_HANDOFF}"
  grep -q "## Key Decisions" "${PDLC_HANDOFF}"
  grep -q "Used TDD approach." "${PDLC_HANDOFF}"
}

@test "session_save: no .tmp file left after save" {
  pdlc_write_handoff "phase: ACTOR
batch: 1" "## Context"

  pdlc_session_save "1" "Implementing" \
    "implement|spawn|Work" "success" "accept"

  local tmp_count
  tmp_count=$(find "${PDLC_STATE_DIR}" -name "*.tmp*" 2>/dev/null | wc -l | tr -d ' ')
  [[ "$tmp_count" -eq 0 ]]
}

@test "session_save: replaces existing checkpoint on re-save" {
  pdlc_write_handoff "phase: ACTOR
batch: 1" "## Context"

  pdlc_session_save "1" "Implementing" \
    "implement|spawn|Work" "success" "accept"

  pdlc_session_save "2" "Implementing" \
    "implement|spawn|More work" "success" "accept"

  # Should have exactly one checkpoint section
  local count
  count=$(grep -c "### Session Checkpoint" "${PDLC_HANDOFF}")
  [[ "$count" -eq 1 ]]
  # Should reflect the latest iteration
  grep -q "Iteration: 2" "${PDLC_HANDOFF}"
  # Old iteration should be gone
  ! grep -q "Iteration: 1" "${PDLC_HANDOFF}"
}

@test "session_save: no-op if HANDOFF.md does not exist" {
  run pdlc_session_save "1" "Implementing" \
    "implement|spawn|Work" "success" "accept"

  [[ "$status" -eq 0 ]]
  [[ ! -f "${PDLC_HANDOFF}" ]]
}

# ──────────────────────────────────────────────────────────
# REQ-SP-005: pdlc_session_restore
# ──────────────────────────────────────────────────────────

@test "session_restore: returns checkpoint fields" {
  pdlc_write_handoff "phase: ACTOR
batch: 1" "## Context

### Session Checkpoint

- Iteration: 5
- Lifecycle: Implementing
- Director: implement|spawn|Heavy work
- Actor: success (3 files changed)
- Critic: accept
- Quality: advocate=PASS, skeptic=PASS
- Timestamp: 2026-03-17T20:00:00Z"

  run pdlc_session_restore
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "Iteration: 5"
  echo "$output" | grep -q "Lifecycle: Implementing"
  echo "$output" | grep -q "Director: implement|spawn|Heavy work"
  echo "$output" | grep -q "Actor: success (3 files changed)"
  echo "$output" | grep -q "Critic: accept"
  echo "$output" | grep -q "Quality: advocate=PASS, skeptic=PASS"
  echo "$output" | grep -q "Timestamp: 2026-03-17T20:00:00Z"
}

@test "session_restore: returns empty when no checkpoint" {
  pdlc_write_handoff "phase: ACTOR
batch: 1" "## Context

No checkpoint here."

  run pdlc_session_restore
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "session_restore: returns empty when no HANDOFF.md" {
  run pdlc_session_restore
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "session_restore: stops at next heading" {
  pdlc_write_handoff "phase: ACTOR
batch: 1" "## Context

### Session Checkpoint

- Iteration: 3
- Lifecycle: Implementing

## Key Decisions

Should not appear."

  run pdlc_session_restore
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "Iteration: 3"
  ! echo "$output" | grep -q "Should not appear"
}

# ──────────────────────────────────────────────────────────
# REQ-SP-005: pdlc_session_get_checkpoint_field
# ──────────────────────────────────────────────────────────

@test "session_get_checkpoint_field: returns specific field value" {
  pdlc_write_handoff "phase: ACTOR
batch: 1" "## Context

### Session Checkpoint

- Iteration: 7
- Lifecycle: Complete
- Director: review|same-session|Final review
- Actor: success
- Critic: accept
- Quality: N/A
- Timestamp: 2026-03-17T22:00:00Z"

  run pdlc_session_get_checkpoint_field "Iteration"
  [[ "$status" -eq 0 ]]
  [[ "$output" == "7" ]]
}

@test "session_get_checkpoint_field: returns empty for missing field" {
  pdlc_write_handoff "phase: ACTOR
batch: 1" "## Context

### Session Checkpoint

- Iteration: 1"

  run pdlc_session_get_checkpoint_field "Nonexistent"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

@test "session_get_checkpoint_field: returns empty when no checkpoint" {
  pdlc_write_handoff "phase: ACTOR
batch: 1" "## Context"

  run pdlc_session_get_checkpoint_field "Iteration"
  [[ "$status" -eq 0 ]]
  [[ -z "$output" ]]
}

# ──────────────────────────────────────────────────────────
# Round-trip: save then restore
# ──────────────────────────────────────────────────────────

@test "round-trip: save then restore returns same data" {
  pdlc_write_handoff "phase: ACTOR
batch: 1" "## Context

Starting work."

  pdlc_session_save "4" "Implementing" \
    "implement|spawn|TDD cycle" "success (2 files changed)" "accept"

  run pdlc_session_restore
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "Iteration: 4"
  echo "$output" | grep -q "Lifecycle: Implementing"
  echo "$output" | grep -q "Director: implement|spawn|TDD cycle"
  echo "$output" | grep -q "Actor: success (2 files changed)"
  echo "$output" | grep -q "Critic: accept"
}

@test "round-trip: multiple saves preserve only latest" {
  pdlc_write_handoff "phase: ACTOR
batch: 1" "## Context"

  pdlc_session_save "1" "Tasked" \
    "implement|spawn|First" "success" "accept"
  pdlc_session_save "2" "Implementing" \
    "implement|spawn|Second" "success" "accept"
  pdlc_session_save "3" "Implementing" \
    "implement|spawn|Third" "success" "retry"

  run pdlc_session_restore
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "Iteration: 3"
  echo "$output" | grep -q "Critic: retry"
  ! echo "$output" | grep -q "Iteration: 1"
  ! echo "$output" | grep -q "Iteration: 2"
}
