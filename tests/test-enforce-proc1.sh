#!/bin/bash
# tests/test-enforce-proc1.sh — Unit tests for hooks/enforce-proc1.sh
set -euo pipefail

PASS=0
FAIL=0
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1 — $2"; }

HOOKS_DIR="$(cd "$(dirname "$0")/../hooks" && pwd)"
ENFORCE_PROC1="${HOOKS_DIR}/enforce-proc1.sh"

echo "=== enforce-proc1.sh ==="

# Test: Allow non-Task tools (e.g., Read)
result=$(echo '{"tool_name":"Read","tool_input":{"file_path":"/tmp/foo"}}' | bash "${ENFORCE_PROC1}")
decision=$(echo "$result" | jq -r '.decision')
[[ "$decision" == "allow" ]] && pass "allow non-Task tool (Read)" || fail "allow non-Task tool (Read)" "got '${decision}'"

# Test: Allow non-Task tools (e.g., Write)
result=$(echo '{"tool_name":"Write","tool_input":{"content":"hello"}}' | bash "${ENFORCE_PROC1}")
decision=$(echo "$result" | jq -r '.decision')
[[ "$decision" == "allow" ]] && pass "allow non-Task tool (Write)" || fail "allow non-Task tool (Write)" "got '${decision}'"

# Test: Deny Task tool with "generate requirements"
result=$(echo '{"tool_name":"Task","tool_input":{"prompt":"Please generate requirements for the auth module"}}' | bash "${ENFORCE_PROC1}")
decision=$(echo "$result" | jq -r '.decision')
[[ "$decision" == "deny" ]] && pass "deny Task with 'generate requirements'" || fail "deny Task with 'generate requirements'" "got '${decision}'"

# Test: Deny Task tool with "write design.md"
result=$(echo '{"tool_name":"Task","tool_input":{"prompt":"write design.md for the API layer"}}' | bash "${ENFORCE_PROC1}")
decision=$(echo "$result" | jq -r '.decision')
[[ "$decision" == "deny" ]] && pass "deny Task with 'write design.md'" || fail "deny Task with 'write design.md'" "got '${decision}'"

# Test: Deny Task tool with "generate tasks"
result=$(echo '{"tool_name":"Task","tool_input":{"prompt":"generate tasks from the design doc"}}' | bash "${ENFORCE_PROC1}")
decision=$(echo "$result" | jq -r '.decision')
[[ "$decision" == "deny" ]] && pass "deny Task with 'generate tasks'" || fail "deny Task with 'generate tasks'" "got '${decision}'"

# Test: Deny Task tool with "create spec"
result=$(echo '{"tool_name":"Task","tool_input":{"prompt":"create spec for the new feature"}}' | bash "${ENFORCE_PROC1}")
decision=$(echo "$result" | jq -r '.decision')
[[ "$decision" == "deny" ]] && pass "deny Task with 'create spec'" || fail "deny Task with 'create spec'" "got '${decision}'"

# Test: Deny Task tool with "write specification"
result=$(echo '{"tool_name":"Task","tool_input":{"prompt":"write specification document"}}' | bash "${ENFORCE_PROC1}")
decision=$(echo "$result" | jq -r '.decision')
[[ "$decision" == "deny" ]] && pass "deny Task with 'write specification'" || fail "deny Task with 'write specification'" "got '${decision}'"

# Test: Allow Task tool without spec-gen patterns
result=$(echo '{"tool_name":"Task","tool_input":{"prompt":"Run the test suite and fix any failures"}}' | bash "${ENFORCE_PROC1}")
decision=$(echo "$result" | jq -r '.decision')
[[ "$decision" == "allow" ]] && pass "allow Task without spec-gen pattern" || fail "allow Task without spec-gen pattern" "got '${decision}'"

# Test: Allow Task tool with unrelated content
result=$(echo '{"tool_name":"Task","tool_input":{"prompt":"Refactor the database connection pool"}}' | bash "${ENFORCE_PROC1}")
decision=$(echo "$result" | jq -r '.decision')
[[ "$decision" == "allow" ]] && pass "allow Task with unrelated prompt" || fail "allow Task with unrelated prompt" "got '${decision}'"

# Test: Deny reason contains PROC-1 VIOLATION
result=$(echo '{"tool_name":"Task","tool_input":{"prompt":"generate requirements for login"}}' | bash "${ENFORCE_PROC1}")
reason=$(echo "$result" | jq -r '.reason')
echo "$reason" | grep -q "PROC-1 VIOLATION" && pass "deny reason mentions PROC-1" || fail "deny reason mentions PROC-1" "reason: ${reason}"

# Test: Custom patterns via PDLC_PROC1_PATTERNS env var
result=$(PDLC_PROC1_PATTERNS="custom_forbidden_pattern" bash -c "echo '{\"tool_name\":\"Task\",\"tool_input\":{\"prompt\":\"do custom_forbidden_pattern now\"}}' | bash '${ENFORCE_PROC1}'")
decision=$(echo "$result" | jq -r '.decision')
[[ "$decision" == "deny" ]] && pass "custom pattern via env var denies" || fail "custom pattern via env var denies" "got '${decision}'"

# Test: Custom pattern does not match default patterns
result=$(PDLC_PROC1_PATTERNS="custom_forbidden_pattern" bash -c "echo '{\"tool_name\":\"Task\",\"tool_input\":{\"prompt\":\"generate requirements for auth\"}}' | bash '${ENFORCE_PROC1}'")
decision=$(echo "$result" | jq -r '.decision')
[[ "$decision" == "allow" ]] && pass "custom pattern replaces defaults" || fail "custom pattern replaces defaults" "got '${decision}'"

# Test: Case insensitivity — "GENERATE REQUIREMENTS" should also deny
result=$(echo '{"tool_name":"Task","tool_input":{"prompt":"GENERATE REQUIREMENTS for the module"}}' | bash "${ENFORCE_PROC1}")
decision=$(echo "$result" | jq -r '.decision')
[[ "$decision" == "deny" ]] && pass "case insensitive match" || fail "case insensitive match" "got '${decision}'"

echo ""
echo "=========================================="
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
