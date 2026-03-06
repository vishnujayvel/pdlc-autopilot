#!/usr/bin/env bats
# tests/integration/enforce-proc1.bats — BATS tests for hooks/enforce-proc1.sh

load ../helpers/common-setup

# Helper: run enforce-proc1 with given JSON piped to stdin
run_proc1() {
  local json="$1"
  echo "$json" | bash "${HOOKS_DIR}/enforce-proc1.sh"
}

@test "allow non-Task tool (Read)" {
  result=$(run_proc1 '{"tool_name":"Read","tool_input":{"file_path":"/tmp/foo"}}')
  decision=$(echo "$result" | jq -r '.decision')
  [[ "$decision" == "allow" ]]
}

@test "allow non-Task tool (Write)" {
  result=$(run_proc1 '{"tool_name":"Write","tool_input":{"content":"hello"}}')
  decision=$(echo "$result" | jq -r '.decision')
  [[ "$decision" == "allow" ]]
}

@test "deny Task with 'generate requirements'" {
  result=$(run_proc1 '{"tool_name":"Task","tool_input":{"prompt":"Please generate requirements for the auth module"}}')
  decision=$(echo "$result" | jq -r '.decision')
  [[ "$decision" == "deny" ]]
}

@test "deny Task with 'write design.md'" {
  result=$(run_proc1 '{"tool_name":"Task","tool_input":{"prompt":"write design.md for the API layer"}}')
  decision=$(echo "$result" | jq -r '.decision')
  [[ "$decision" == "deny" ]]
}

@test "deny Task with 'generate tasks'" {
  result=$(run_proc1 '{"tool_name":"Task","tool_input":{"prompt":"generate tasks from the design doc"}}')
  decision=$(echo "$result" | jq -r '.decision')
  [[ "$decision" == "deny" ]]
}

@test "deny Task with 'create spec'" {
  result=$(run_proc1 '{"tool_name":"Task","tool_input":{"prompt":"create spec for the new feature"}}')
  decision=$(echo "$result" | jq -r '.decision')
  [[ "$decision" == "deny" ]]
}

@test "deny Task with 'write specification'" {
  result=$(run_proc1 '{"tool_name":"Task","tool_input":{"prompt":"write specification document"}}')
  decision=$(echo "$result" | jq -r '.decision')
  [[ "$decision" == "deny" ]]
}

@test "allow Task without spec-gen pattern" {
  result=$(run_proc1 '{"tool_name":"Task","tool_input":{"prompt":"Run the test suite and fix any failures"}}')
  decision=$(echo "$result" | jq -r '.decision')
  [[ "$decision" == "allow" ]]
}

@test "allow Task with unrelated prompt" {
  result=$(run_proc1 '{"tool_name":"Task","tool_input":{"prompt":"Refactor the database connection pool"}}')
  decision=$(echo "$result" | jq -r '.decision')
  [[ "$decision" == "allow" ]]
}

@test "deny reason mentions PROC-1 VIOLATION" {
  result=$(run_proc1 '{"tool_name":"Task","tool_input":{"prompt":"generate requirements for login"}}')
  reason=$(echo "$result" | jq -r '.reason')
  [[ "$reason" == *"PROC-1 VIOLATION"* ]]
}

@test "custom pattern via env var denies" {
  result=$(PDLC_PROC1_PATTERNS="custom_forbidden_pattern" bash -c 'echo '"'"'{"tool_name":"Task","tool_input":{"prompt":"do custom_forbidden_pattern now"}}'"'"' | bash "'"${HOOKS_DIR}"'/enforce-proc1.sh"')
  decision=$(echo "$result" | jq -r '.decision')
  [[ "$decision" == "deny" ]]
}

@test "custom pattern replaces defaults" {
  result=$(PDLC_PROC1_PATTERNS="custom_forbidden_pattern" bash -c 'echo '"'"'{"tool_name":"Task","tool_input":{"prompt":"generate requirements for auth"}}'"'"' | bash "'"${HOOKS_DIR}"'/enforce-proc1.sh"')
  decision=$(echo "$result" | jq -r '.decision')
  [[ "$decision" == "allow" ]]
}

@test "case insensitive match" {
  result=$(run_proc1 '{"tool_name":"Task","tool_input":{"prompt":"GENERATE REQUIREMENTS for the module"}}')
  decision=$(echo "$result" | jq -r '.decision')
  [[ "$decision" == "deny" ]]
}
