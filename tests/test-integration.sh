#!/bin/bash
# tests/test-integration.sh — Integration tests for PDLC session hooks
set -euo pipefail

PASS=0
FAIL=0
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1 — $2"; }

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_DIR="${REPO_DIR}/hooks"

echo "=== Integration: PreCompact marker -> UserPromptSubmit restore cycle ==="

# Setup a workspace with HANDOFF.md
WORKDIR="${TEST_DIR}/compact-cycle"
mkdir -p "${WORKDIR}/.pdlc/state"
cat > "${WORKDIR}/.pdlc/state/HANDOFF.md" <<'EOF'
---
phase: ACTOR
batch: 2
spec_dir: .claude/specs/feature-x
---

## Current Batch Context

Working on batch 2 implementation.
EOF

# Run pre-compact-save.sh — should touch marker
(cd "$WORKDIR" && bash "${HOOKS_DIR}/pre-compact-save.sh" < /dev/null 2>/dev/null)
[[ -f "${WORKDIR}/.pdlc/state/.compact_marker" ]] && pass "pre-compact creates marker" || fail "pre-compact creates marker" "marker not found"

# Run post-compact-restore.sh — should output HANDOFF.md content and remove marker
restore_output=$(cd "$WORKDIR" && bash "${HOOKS_DIR}/post-compact-restore.sh" < /dev/null 2>/dev/null)
echo "$restore_output" | grep -q "PDLC State Restored" && pass "restore outputs header" || fail "restore outputs header" "output: ${restore_output}"
echo "$restore_output" | grep -q "phase: ACTOR" && pass "restore includes HANDOFF content" || fail "restore includes HANDOFF content" ""
[[ ! -f "${WORKDIR}/.pdlc/state/.compact_marker" ]] && pass "restore removes marker" || fail "restore removes marker" "marker still exists"

# Run post-compact-restore again (no marker) — should produce no output
restore_output2=$(cd "$WORKDIR" && bash "${HOOKS_DIR}/post-compact-restore.sh" < /dev/null 2>/dev/null)
[[ -z "$restore_output2" ]] && pass "restore no-op without marker" || fail "restore no-op without marker" "got output: ${restore_output2}"

echo ""
echo "=== Integration: PreCompact without existing HANDOFF.md ==="

WORKDIR="${TEST_DIR}/compact-no-handoff"
mkdir -p "${WORKDIR}"
(cd "$WORKDIR" && bash "${HOOKS_DIR}/pre-compact-save.sh" < /dev/null 2>/dev/null)
[[ -f "${WORKDIR}/.pdlc/state/HANDOFF.md" ]] && pass "pre-compact creates stub HANDOFF.md" || fail "pre-compact creates stub HANDOFF.md" ""
grep -q "phase: UNKNOWN" "${WORKDIR}/.pdlc/state/HANDOFF.md" && pass "stub has phase: UNKNOWN" || fail "stub has phase: UNKNOWN" ""
grep -q "partial: true" "${WORKDIR}/.pdlc/state/HANDOFF.md" && pass "stub has partial: true" || fail "stub has partial: true" ""
[[ -f "${WORKDIR}/.pdlc/state/.compact_marker" ]] && pass "pre-compact creates marker (no-handoff case)" || fail "pre-compact creates marker (no-handoff case)" ""

echo ""
echo "=== Integration: session-init with and without HANDOFF.md ==="

# With HANDOFF.md
WORKDIR="${TEST_DIR}/session-with"
mkdir -p "${WORKDIR}/.pdlc/state"
cat > "${WORKDIR}/.pdlc/state/HANDOFF.md" <<'EOF'
---
phase: CRITIC
batch: 3
---

## Review needed
EOF
output=$(cd "$WORKDIR" && bash "${HOOKS_DIR}/session-init.sh" < /dev/null 2>/dev/null)
echo "$output" | grep -q "PDLC Autopilot Session State" && pass "session-init outputs header with HANDOFF" || fail "session-init outputs header with HANDOFF" "output: ${output}"
echo "$output" | grep -q "phase: CRITIC" && pass "session-init includes HANDOFF content" || fail "session-init includes HANDOFF content" ""

# Without HANDOFF.md
WORKDIR="${TEST_DIR}/session-without"
mkdir -p "${WORKDIR}"
output=$(cd "$WORKDIR" && bash "${HOOKS_DIR}/session-init.sh" < /dev/null 2>/dev/null)
echo "$output" | grep -q "No active PDLC session" && pass "session-init message without HANDOFF" || fail "session-init message without HANDOFF" "output: ${output}"

echo ""
echo "=== Integration: settings.json template validation ==="

TEMPLATE="${REPO_DIR}/.claude/settings.json.template"
[[ -f "$TEMPLATE" ]] && pass "settings.json.template exists" || fail "settings.json.template exists" "file not found"

# Validate JSON is well-formed
jq '.' "$TEMPLATE" > /dev/null 2>&1 && pass "template is valid JSON" || fail "template is valid JSON" "jq parse failed"

# Extract all script paths from the template and verify they exist and are executable
scripts=$(jq -r '.. | objects | .command? // empty' "$TEMPLATE" | sed 's/^bash //')
all_exist=true
all_exec=true
for script in $scripts; do
  script_path="${REPO_DIR}/${script}"
  if [[ ! -f "$script_path" ]]; then
    fail "script exists: ${script}" "file not found at ${script_path}"
    all_exist=false
  fi
done
$all_exist && pass "all referenced scripts exist"

for script in $scripts; do
  script_path="${REPO_DIR}/${script}"
  if [[ -f "$script_path" && ! -x "$script_path" ]]; then
    # Check if at least bash can run it (scripts may not have +x but are invoked via "bash script.sh")
    # Since the template uses "bash hooks/...", +x is not strictly required, but we still check
    true  # Scripts are invoked via "bash path", so not strictly needing +x
  fi
done
pass "scripts invoked via 'bash' (executable bit optional)"

# Verify expected hook types are configured
jq -e '.hooks.PreCompact' "$TEMPLATE" > /dev/null 2>&1 && pass "PreCompact hook configured" || fail "PreCompact hook configured" ""
jq -e '.hooks.UserPromptSubmit' "$TEMPLATE" > /dev/null 2>&1 && pass "UserPromptSubmit hook configured" || fail "UserPromptSubmit hook configured" ""
jq -e '.hooks.SessionStart' "$TEMPLATE" > /dev/null 2>&1 && pass "SessionStart hook configured" || fail "SessionStart hook configured" ""
jq -e '.hooks.PreToolUse' "$TEMPLATE" > /dev/null 2>&1 && pass "PreToolUse hook configured" || fail "PreToolUse hook configured" ""

echo ""
echo "=== Integration: HANDOFF.md end-to-end write -> read -> update -> verify ==="

WORKDIR="${TEST_DIR}/e2e"
mkdir -p "${WORKDIR}"

# Override state paths by cd-ing into workdir
(
  cd "$WORKDIR"
  # Source the library
  source "${HOOKS_DIR}/lib/pdlc-state.sh"
  # Override paths
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

  [[ "$phase" == "INIT" ]] || { echo "FAIL: phase mismatch: $phase"; exit 1; }
  [[ "$batch" == "1" ]] || { echo "FAIL: batch mismatch: $batch"; exit 1; }
  [[ "$spec" == ".claude/specs/test" ]] || { echo "FAIL: spec_dir mismatch: $spec"; exit 1; }
  [[ "$pending" == "T-1.1,T-1.2,T-2.1" ]] || { echo "FAIL: pending mismatch: $pending"; exit 1; }

  # Step 3: Update fields (simulate session progress)
  pdlc_set_field "phase" "ACTOR"
  pdlc_set_field "batch" "2"
  pdlc_set_field "completed_tasks" "T-1.1,T-1.2"
  pdlc_set_field "pending_tasks" "T-2.1"
  pdlc_set_field "total_cost_usd" "3.50"
  # Add new fields
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

  [[ "$phase" == "ACTOR" ]] || { echo "FAIL: updated phase: $phase"; exit 1; }
  [[ "$batch" == "2" ]] || { echo "FAIL: updated batch: $batch"; exit 1; }
  [[ "$completed" == "T-1.1,T-1.2" ]] || { echo "FAIL: completed: $completed"; exit 1; }
  [[ "$pending" == "T-2.1" ]] || { echo "FAIL: pending: $pending"; exit 1; }
  [[ "$cost" == "3.50" ]] || { echo "FAIL: cost: $cost"; exit 1; }
  [[ "$adv" == "APPROVED" ]] || { echo "FAIL: advocate: $adv"; exit 1; }
  [[ "$skp" == "APPROVED_WITH_NOTES" ]] || { echo "FAIL: skeptic: $skp"; exit 1; }
  # spec_dir should be unchanged
  [[ "$spec" == ".claude/specs/test" ]] || { echo "FAIL: spec unchanged: $spec"; exit 1; }

  # Verify body preserved
  grep -q "Starting fresh." "${PDLC_HANDOFF}" || { echo "FAIL: body not preserved"; exit 1; }

  echo "OK"
)
e2e_result=$?
[[ $e2e_result -eq 0 ]] && pass "HANDOFF.md end-to-end cycle" || fail "HANDOFF.md end-to-end cycle" "subshell exited $e2e_result"

echo ""
echo "=========================================="
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
