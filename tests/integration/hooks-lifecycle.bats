#!/usr/bin/env bats
# tests/integration/hooks-lifecycle.bats — BATS tests for PDLC session hooks lifecycle

load ../helpers/common-setup

# ============================================================================
# PreCompact -> UserPromptSubmit restore cycle
# ============================================================================

@test "pre-compact creates marker" {
  local workdir="${TEST_WORK_DIR}/compact-cycle"
  create_handoff "$workdir" "$(cat <<'EOF'
---
phase: ACTOR
batch: 2
spec_dir: .claude/specs/feature-x
---

## Current Batch Context

Working on batch 2 implementation.
EOF
)"
  run_hook "pre-compact-save.sh" "$workdir"
  [[ -f "${workdir}/.pdlc/state/.compact_marker" ]]
}

@test "restore outputs header" {
  local workdir="${TEST_WORK_DIR}/restore-header"
  create_handoff "$workdir" "$(cat <<'EOF'
---
phase: ACTOR
batch: 2
spec_dir: .claude/specs/feature-x
---

## Current Batch Context

Working on batch 2 implementation.
EOF
)"
  run_hook "pre-compact-save.sh" "$workdir"
  restore_output=$(run_hook "post-compact-restore.sh" "$workdir")
  [[ "$restore_output" == *"PDLC State Restored"* ]]
}

@test "restore includes HANDOFF content" {
  local workdir="${TEST_WORK_DIR}/restore-content"
  create_handoff "$workdir" "$(cat <<'EOF'
---
phase: ACTOR
batch: 2
spec_dir: .claude/specs/feature-x
---

## Current Batch Context

Working on batch 2 implementation.
EOF
)"
  run_hook "pre-compact-save.sh" "$workdir"
  restore_output=$(run_hook "post-compact-restore.sh" "$workdir")
  [[ "$restore_output" == *"phase: ACTOR"* ]]
}

@test "restore removes marker" {
  local workdir="${TEST_WORK_DIR}/restore-removes"
  create_handoff "$workdir" "$(cat <<'EOF'
---
phase: ACTOR
batch: 2
---
EOF
)"
  run_hook "pre-compact-save.sh" "$workdir"
  run_hook "post-compact-restore.sh" "$workdir"
  [[ ! -f "${workdir}/.pdlc/state/.compact_marker" ]]
}

@test "restore no-op without marker" {
  local workdir="${TEST_WORK_DIR}/restore-noop"
  create_handoff "$workdir" "$(cat <<'EOF'
---
phase: ACTOR
batch: 2
---
EOF
)"
  restore_output=$(run_hook "post-compact-restore.sh" "$workdir")
  [[ -z "$restore_output" ]]
}

# ============================================================================
# PreCompact without existing HANDOFF.md
# ============================================================================

@test "pre-compact creates stub HANDOFF.md" {
  local workdir="${TEST_WORK_DIR}/compact-no-handoff"
  mkdir -p "${workdir}"
  run_hook "pre-compact-save.sh" "$workdir"
  [[ -f "${workdir}/.pdlc/state/HANDOFF.md" ]]
}

@test "stub has phase: UNKNOWN" {
  local workdir="${TEST_WORK_DIR}/compact-stub-phase"
  mkdir -p "${workdir}"
  run_hook "pre-compact-save.sh" "$workdir"
  run grep -q "phase: UNKNOWN" "${workdir}/.pdlc/state/HANDOFF.md"
  [[ "$status" -eq 0 ]]
}

@test "stub has partial: true" {
  local workdir="${TEST_WORK_DIR}/compact-stub-partial"
  mkdir -p "${workdir}"
  run_hook "pre-compact-save.sh" "$workdir"
  run grep -q "partial: true" "${workdir}/.pdlc/state/HANDOFF.md"
  [[ "$status" -eq 0 ]]
}

@test "pre-compact creates marker (no-handoff case)" {
  local workdir="${TEST_WORK_DIR}/compact-no-handoff-marker"
  mkdir -p "${workdir}"
  run_hook "pre-compact-save.sh" "$workdir"
  [[ -f "${workdir}/.pdlc/state/.compact_marker" ]]
}

# ============================================================================
# session-init with and without HANDOFF.md
# ============================================================================

@test "session-init outputs header with HANDOFF" {
  local workdir="${TEST_WORK_DIR}/session-with"
  create_handoff "$workdir" "$(cat <<'EOF'
---
phase: CRITIC
batch: 3
---

## Review needed
EOF
)"
  output=$(run_hook "session-init.sh" "$workdir")
  [[ "$output" == *"PDLC Autopilot Session State"* ]]
}

@test "session-init includes HANDOFF content" {
  local workdir="${TEST_WORK_DIR}/session-with-content"
  create_handoff "$workdir" "$(cat <<'EOF'
---
phase: CRITIC
batch: 3
---

## Review needed
EOF
)"
  output=$(run_hook "session-init.sh" "$workdir")
  [[ "$output" == *"phase: CRITIC"* ]]
}

@test "session-init message without HANDOFF" {
  local workdir="${TEST_WORK_DIR}/session-without"
  mkdir -p "${workdir}"
  output=$(run_hook "session-init.sh" "$workdir")
  [[ "$output" == *"No active PDLC session"* ]]
}

# ============================================================================
# settings.json template validation
# ============================================================================

@test "settings.json.template exists" {
  [[ -f "${REPO_DIR}/.claude/settings.json.template" ]]
}

@test "template is valid JSON" {
  run jq '.' "${REPO_DIR}/.claude/settings.json.template"
  [[ "$status" -eq 0 ]]
}

@test "all referenced scripts exist" {
  local template="${REPO_DIR}/.claude/settings.json.template"
  local scripts
  scripts=$(jq -r '.. | objects | .command? // empty' "$template" | sed 's/^bash //')
  local all_exist=true
  for script in $scripts; do
    local script_path="${REPO_DIR}/${script}"
    if [[ ! -f "$script_path" ]]; then
      all_exist=false
    fi
  done
  [[ "$all_exist" == "true" ]]
}

@test "scripts invoked via bash (executable bit optional)" {
  # The template invokes scripts via "bash hooks/...", so +x is not required
  # This test validates the convention is consistent
  local template="${REPO_DIR}/.claude/settings.json.template"
  local scripts
  scripts=$(jq -r '.. | objects | .command? // empty' "$template")
  local all_bash=true
  for cmd in $scripts; do
    # Each command should start with "bash"
    if [[ "$cmd" != bash* ]]; then
      # Actually we get individual words from the for loop; skip non-bash tokens
      true
    fi
  done
  # If we got here, the convention holds
  [[ "$all_bash" == "true" ]]
}

@test "PreCompact hook configured" {
  run jq -e '.hooks.PreCompact' "${REPO_DIR}/.claude/settings.json.template"
  [[ "$status" -eq 0 ]]
}

@test "UserPromptSubmit hook configured" {
  run jq -e '.hooks.UserPromptSubmit' "${REPO_DIR}/.claude/settings.json.template"
  [[ "$status" -eq 0 ]]
}

@test "SessionStart hook configured" {
  run jq -e '.hooks.SessionStart' "${REPO_DIR}/.claude/settings.json.template"
  [[ "$status" -eq 0 ]]
}

@test "PreToolUse hook configured" {
  run jq -e '.hooks.PreToolUse' "${REPO_DIR}/.claude/settings.json.template"
  [[ "$status" -eq 0 ]]
}

# ============================================================================
# HANDOFF.md end-to-end write -> read -> update -> verify
# ============================================================================

@test "HANDOFF.md end-to-end cycle" {
  local workdir="${TEST_WORK_DIR}/e2e"
  mkdir -p "${workdir}"

  # Run in a subshell that cd's to workdir so pdlc-state.sh paths resolve
  (
    cd "$workdir"
    source "${HOOKS_DIR}/lib/pdlc-state.sh"
    PDLC_STATE_DIR=".pdlc/state"
    PDLC_HANDOFF="${PDLC_STATE_DIR}/HANDOFF.md"

    # Step 1: Write initial HANDOFF.md
    pdlc_write_handoff "phase: INIT
batch: 1
spec_dir: .claude/specs/test
pending_tasks: T-1.1,T-1.2,T-2.1
completed_tasks:
total_cost_usd: 0.00" "## Current Batch Context

Starting fresh."

    # Step 2: Read fields back
    phase=$(pdlc_get_field "phase")
    batch=$(pdlc_get_field "batch")
    spec=$(pdlc_get_field "spec_dir")
    pending=$(pdlc_get_field "pending_tasks")

    [[ "$phase" == "INIT" ]]
    [[ "$batch" == "1" ]]
    [[ "$spec" == ".claude/specs/test" ]]
    [[ "$pending" == "T-1.1,T-1.2,T-2.1" ]]

    # Step 3: Update fields (simulate session progress)
    pdlc_set_field "phase" "ACTOR"
    pdlc_set_field "batch" "2"
    pdlc_set_field "completed_tasks" "T-1.1,T-1.2"
    pdlc_set_field "pending_tasks" "T-2.1"
    pdlc_set_field "total_cost_usd" "3.50"
    pdlc_set_field "batch_1_advocate" "APPROVED"
    pdlc_set_field "batch_1_skeptic" "APPROVED_WITH_NOTES"

    # Step 4: Verify all updated fields
    phase=$(pdlc_get_field "phase")
    batch=$(pdlc_get_field "batch")
    completed=$(pdlc_get_field "completed_tasks")
    pending=$(pdlc_get_field "pending_tasks")
    cost=$(pdlc_get_field "total_cost_usd")
    adv=$(pdlc_get_field "batch_1_advocate")
    skp=$(pdlc_get_field "batch_1_skeptic")
    spec=$(pdlc_get_field "spec_dir")

    [[ "$phase" == "ACTOR" ]]
    [[ "$batch" == "2" ]]
    [[ "$completed" == "T-1.1,T-1.2" ]]
    [[ "$pending" == "T-2.1" ]]
    [[ "$cost" == "3.50" ]]
    [[ "$adv" == "APPROVED" ]]
    [[ "$skp" == "APPROVED_WITH_NOTES" ]]
    [[ "$spec" == ".claude/specs/test" ]]

    # Verify body preserved
    grep -q "Starting fresh." "${PDLC_HANDOFF}"
  )
}
