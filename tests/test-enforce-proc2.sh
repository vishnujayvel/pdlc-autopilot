#!/bin/bash
# tests/test-enforce-proc2.sh — Unit tests for hooks/enforce-proc2.sh
set -euo pipefail

PASS=0
FAIL=0
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1 — $2"; }

HOOKS_DIR="$(cd "$(dirname "$0")/../hooks" && pwd)"
ENFORCE_PROC2="${HOOKS_DIR}/enforce-proc2.sh"

# Helper: run enforce-proc2 with given JSON input while using a temp state dir
# We need to override the state dir by cd-ing to a temp workspace
run_proc2() {
  local json="$1"
  local workdir="$2"
  # Run from the workdir so .pdlc/state/HANDOFF.md resolves relative to it
  (cd "$workdir" && echo "$json" | bash "${ENFORCE_PROC2}")
}

echo "=== enforce-proc2.sh ==="

# Test: Allow non-Task tools
WORKDIR="${TEST_DIR}/t1"
mkdir -p "${WORKDIR}"
result=$(run_proc2 '{"tool_name":"Read","tool_input":{"file_path":"/tmp/foo"}}' "$WORKDIR")
decision=$(echo "$result" | jq -r '.decision')
[[ "$decision" == "allow" ]] && pass "allow non-Task tool" || fail "allow non-Task tool" "got '${decision}'"

# Test: Allow Task without Actor markers
WORKDIR="${TEST_DIR}/t2"
mkdir -p "${WORKDIR}"
result=$(run_proc2 '{"tool_name":"Task","tool_input":{"prompt":"Run tests and fix bugs"}}' "$WORKDIR")
decision=$(echo "$result" | jq -r '.decision')
[[ "$decision" == "allow" ]] && pass "allow Task without Actor markers" || fail "allow Task without Actor markers" "got '${decision}'"

# Test: Allow first batch (batch 1) Actor dispatch
WORKDIR="${TEST_DIR}/t3"
mkdir -p "${WORKDIR}/.pdlc/state"
cat > "${WORKDIR}/.pdlc/state/HANDOFF.md" <<'EOF'
---
phase: ACTOR
batch: 1
---
EOF
result=$(run_proc2 '{"tool_name":"Task","tool_input":{"prompt":"[ACTOR: Batch 1] Implement login feature"}}' "$WORKDIR")
decision=$(echo "$result" | jq -r '.decision')
[[ "$decision" == "allow" ]] && pass "allow first batch Actor dispatch" || fail "allow first batch Actor dispatch" "got '${decision}'"

# Test: Allow Actor dispatch when no HANDOFF.md exists (can't enforce without state)
WORKDIR="${TEST_DIR}/t4"
mkdir -p "${WORKDIR}"
result=$(run_proc2 '{"tool_name":"Task","tool_input":{"prompt":"[ACTOR: Batch 2] Do something"}}' "$WORKDIR")
decision=$(echo "$result" | jq -r '.decision')
[[ "$decision" == "allow" ]] && pass "allow Actor dispatch with no HANDOFF.md" || fail "allow Actor dispatch with no HANDOFF.md" "got '${decision}'"

# Test: Deny Actor dispatch when prior batch has no critic results
WORKDIR="${TEST_DIR}/t5"
mkdir -p "${WORKDIR}/.pdlc/state"
cat > "${WORKDIR}/.pdlc/state/HANDOFF.md" <<'EOF'
---
phase: ACTOR
batch: 2
---
EOF
result=$(run_proc2 '{"tool_name":"Task","tool_input":{"prompt":"[ACTOR: Batch 2] Implement feature X"}}' "$WORKDIR")
decision=$(echo "$result" | jq -r '.decision')
[[ "$decision" == "deny" ]] && pass "deny Actor batch 2 without critic results" || fail "deny Actor batch 2 without critic results" "got '${decision}'"

# Test: Deny reason mentions PROC-2 VIOLATION
reason=$(echo "$result" | jq -r '.reason')
echo "$reason" | grep -q "PROC-2 VIOLATION" && pass "deny reason mentions PROC-2" || fail "deny reason mentions PROC-2" "reason: ${reason}"

# Test: Deny when advocate is PENDING
WORKDIR="${TEST_DIR}/t6"
mkdir -p "${WORKDIR}/.pdlc/state"
cat > "${WORKDIR}/.pdlc/state/HANDOFF.md" <<'EOF'
---
phase: ACTOR
batch: 2
batch_1_advocate: PENDING
batch_1_skeptic: DONE
---
EOF
result=$(run_proc2 '{"tool_name":"Task","tool_input":{"prompt":"[ACTOR[2]] Do next batch"}}' "$WORKDIR")
decision=$(echo "$result" | jq -r '.decision')
[[ "$decision" == "deny" ]] && pass "deny when advocate is PENDING" || fail "deny when advocate is PENDING" "got '${decision}'"

# Test: Deny when skeptic is missing
WORKDIR="${TEST_DIR}/t7"
mkdir -p "${WORKDIR}/.pdlc/state"
cat > "${WORKDIR}/.pdlc/state/HANDOFF.md" <<'EOF'
---
phase: ACTOR
batch: 2
batch_1_advocate: DONE
---
EOF
result=$(run_proc2 '{"tool_name":"Task","tool_input":{"prompt":"[ACTOR: Batch 2] Next"}}' "$WORKDIR")
decision=$(echo "$result" | jq -r '.decision')
[[ "$decision" == "deny" ]] && pass "deny when skeptic is missing" || fail "deny when skeptic is missing" "got '${decision}'"

# Test: Allow Actor dispatch when prior batch has critic results
WORKDIR="${TEST_DIR}/t8"
mkdir -p "${WORKDIR}/.pdlc/state"
cat > "${WORKDIR}/.pdlc/state/HANDOFF.md" <<'EOF'
---
phase: ACTOR
batch: 2
batch_1_advocate: APPROVED
batch_1_skeptic: APPROVED_WITH_NOTES
---
EOF
result=$(run_proc2 '{"tool_name":"Task","tool_input":{"prompt":"[ACTOR: Batch 2] Implement feature Y"}}' "$WORKDIR")
decision=$(echo "$result" | jq -r '.decision')
[[ "$decision" == "allow" ]] && pass "allow Actor with complete critic results" || fail "allow Actor with complete critic results" "got '${decision}'"

# Test: Allow when batch field is not a number (can't enforce)
WORKDIR="${TEST_DIR}/t9"
mkdir -p "${WORKDIR}/.pdlc/state"
cat > "${WORKDIR}/.pdlc/state/HANDOFF.md" <<'EOF'
---
phase: ACTOR
batch: abc
---
EOF
result=$(run_proc2 '{"tool_name":"Task","tool_input":{"prompt":"[ACTOR: Batch X] Something"}}' "$WORKDIR")
decision=$(echo "$result" | jq -r '.decision')
[[ "$decision" == "allow" ]] && pass "allow when batch is non-numeric" || fail "allow when batch is non-numeric" "got '${decision}'"

# Test: Actor marker variant [ACTOR[ (bracket style)
WORKDIR="${TEST_DIR}/t10"
mkdir -p "${WORKDIR}/.pdlc/state"
cat > "${WORKDIR}/.pdlc/state/HANDOFF.md" <<'EOF'
---
phase: ACTOR
batch: 3
batch_2_advocate: DONE
batch_2_skeptic: DONE
---
EOF
result=$(run_proc2 '{"tool_name":"Task","tool_input":{"prompt":"[ACTOR[3]] Next batch tasks"}}' "$WORKDIR")
decision=$(echo "$result" | jq -r '.decision')
[[ "$decision" == "allow" ]] && pass "allow [ACTOR[N]] variant with critics done" || fail "allow [ACTOR[N]] variant with critics done" "got '${decision}'"

echo ""
echo "=========================================="
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
