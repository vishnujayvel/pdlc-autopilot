#!/usr/bin/env bats
# tests/integration/critic-gate.bats — BATS tests for hooks/critic-gate.sh

load ../helpers/common-setup

# Helper: run critic-gate with given JSON from a specific workdir
run_critic_gate() {
  local json="$1"
  local workdir="$2"
  (cd "$workdir" && echo "$json" | bash "${HOOKS_DIR}/critic-gate.sh")
}

@test "allow non-Task tool" {
  local workdir="${TEST_WORK_DIR}/t1"
  mkdir -p "${workdir}"
  result=$(run_critic_gate '{"tool_name":"Read","tool_input":{"file_path":"/tmp/foo"}}' "$workdir")
  decision=$(echo "$result" | jq -r '.decision')
  [[ "$decision" == "allow" ]]
}

@test "allow Task without Actor markers" {
  local workdir="${TEST_WORK_DIR}/t2"
  mkdir -p "${workdir}"
  result=$(run_critic_gate '{"tool_name":"Task","tool_input":{"prompt":"Run tests and fix bugs"}}' "$workdir")
  decision=$(echo "$result" | jq -r '.decision')
  [[ "$decision" == "allow" ]]
}

@test "allow first batch Actor dispatch" {
  local workdir="${TEST_WORK_DIR}/t3"
  create_handoff "$workdir" "$(cat <<'EOF'
---
phase: ACTOR
batch: 1
---
EOF
)"
  result=$(run_critic_gate '{"tool_name":"Task","tool_input":{"prompt":"[ACTOR: Batch 1] Implement login feature"}}' "$workdir")
  decision=$(echo "$result" | jq -r '.decision')
  [[ "$decision" == "allow" ]]
}

@test "allow Actor dispatch with no HANDOFF.md" {
  local workdir="${TEST_WORK_DIR}/t4"
  mkdir -p "${workdir}"
  result=$(run_critic_gate '{"tool_name":"Task","tool_input":{"prompt":"[ACTOR: Batch 2] Do something"}}' "$workdir")
  decision=$(echo "$result" | jq -r '.decision')
  [[ "$decision" == "allow" ]]
}

@test "deny Actor batch 2 without critic results" {
  local workdir="${TEST_WORK_DIR}/t5"
  create_handoff "$workdir" "$(cat <<'EOF'
---
phase: ACTOR
batch: 2
---
EOF
)"
  result=$(run_critic_gate '{"tool_name":"Task","tool_input":{"prompt":"[ACTOR: Batch 2] Implement feature X"}}' "$workdir")
  decision=$(echo "$result" | jq -r '.decision')
  [[ "$decision" == "deny" ]]
}

@test "deny reason mentions CriticGate VIOLATION" {
  local workdir="${TEST_WORK_DIR}/t6"
  create_handoff "$workdir" "$(cat <<'EOF'
---
phase: ACTOR
batch: 2
---
EOF
)"
  result=$(run_critic_gate '{"tool_name":"Task","tool_input":{"prompt":"[ACTOR: Batch 2] Implement feature X"}}' "$workdir")
  reason=$(echo "$result" | jq -r '.reason')
  [[ "$reason" == *"CriticGate VIOLATION"* ]]
}

@test "deny when advocate is PENDING" {
  local workdir="${TEST_WORK_DIR}/t7"
  create_handoff "$workdir" "$(cat <<'EOF'
---
phase: ACTOR
batch: 2
batch_1_advocate: PENDING
batch_1_skeptic: DONE
---
EOF
)"
  result=$(run_critic_gate '{"tool_name":"Task","tool_input":{"prompt":"[ACTOR[2]] Do next batch"}}' "$workdir")
  decision=$(echo "$result" | jq -r '.decision')
  [[ "$decision" == "deny" ]]
}

@test "deny when skeptic is missing" {
  local workdir="${TEST_WORK_DIR}/t8"
  create_handoff "$workdir" "$(cat <<'EOF'
---
phase: ACTOR
batch: 2
batch_1_advocate: DONE
---
EOF
)"
  result=$(run_critic_gate '{"tool_name":"Task","tool_input":{"prompt":"[ACTOR: Batch 2] Next"}}' "$workdir")
  decision=$(echo "$result" | jq -r '.decision')
  [[ "$decision" == "deny" ]]
}

@test "allow Actor with complete critic results" {
  local workdir="${TEST_WORK_DIR}/t9"
  create_handoff "$workdir" "$(cat <<'EOF'
---
phase: ACTOR
batch: 2
batch_1_advocate: APPROVED
batch_1_skeptic: APPROVED_WITH_NOTES
---
EOF
)"
  result=$(run_critic_gate '{"tool_name":"Task","tool_input":{"prompt":"[ACTOR: Batch 2] Implement feature Y"}}' "$workdir")
  decision=$(echo "$result" | jq -r '.decision')
  [[ "$decision" == "allow" ]]
}

@test "allow when batch is non-numeric" {
  local workdir="${TEST_WORK_DIR}/t10"
  create_handoff "$workdir" "$(cat <<'EOF'
---
phase: ACTOR
batch: abc
---
EOF
)"
  result=$(run_critic_gate '{"tool_name":"Task","tool_input":{"prompt":"[ACTOR: Batch X] Something"}}' "$workdir")
  decision=$(echo "$result" | jq -r '.decision')
  [[ "$decision" == "allow" ]]
}

@test "allow [ACTOR[N]] variant with critics done" {
  local workdir="${TEST_WORK_DIR}/t11"
  create_handoff "$workdir" "$(cat <<'EOF'
---
phase: ACTOR
batch: 3
batch_2_advocate: DONE
batch_2_skeptic: DONE
---
EOF
)"
  result=$(run_critic_gate '{"tool_name":"Task","tool_input":{"prompt":"[ACTOR[3]] Next batch tasks"}}' "$workdir")
  decision=$(echo "$result" | jq -r '.decision')
  [[ "$decision" == "allow" ]]
}

@test "PDLC_DISABLED=1 bypasses critic-gate (allows unreviewed batch)" {
  local workdir="${TEST_WORK_DIR}/t12"
  create_handoff "$workdir" "$(cat <<'EOF'
---
phase: ACTOR
batch: 2
---
EOF
)"
  result=$(PDLC_DISABLED=1 run_critic_gate '{"tool_name":"Task","tool_input":{"prompt":"[ACTOR: Batch 2] Implement feature X"}}' "$workdir")
  decision=$(echo "$result" | jq -r '.decision')
  [[ "$decision" == "allow" ]]
}
