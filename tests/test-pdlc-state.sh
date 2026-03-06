#!/bin/bash
# tests/test-pdlc-state.sh — Unit tests for hooks/lib/pdlc-state.sh
set -euo pipefail

PASS=0
FAIL=0
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1 — $2"; }

# Source the library under test — override state paths to use temp dir
SCRIPT_DIR="$(cd "$(dirname "$0")/../hooks" && pwd)"
source "${SCRIPT_DIR}/lib/pdlc-state.sh"

# Override state paths to temp dir for isolation
setup() {
  rm -rf "${TEST_DIR}/.pdlc"
  PDLC_STATE_DIR="${TEST_DIR}/.pdlc/state"
  PDLC_HANDOFF="${PDLC_STATE_DIR}/HANDOFF.md"
  PDLC_MARKER="${PDLC_STATE_DIR}/.compact_marker"
}

echo "=== pdlc_get_field ==="

# Test: valid field extraction
setup
mkdir -p "${PDLC_STATE_DIR}"
cat > "${PDLC_HANDOFF}" <<'EOF'
---
phase: ACTOR
batch: 3
spec_dir: .claude/specs/my-feature
---

## Body content
EOF
result=$(pdlc_get_field "phase")
[[ "$result" == "ACTOR" ]] && pass "extract 'phase' field" || fail "extract 'phase' field" "got '${result}'"

result=$(pdlc_get_field "batch")
[[ "$result" == "3" ]] && pass "extract 'batch' field" || fail "extract 'batch' field" "got '${result}'"

result=$(pdlc_get_field "spec_dir")
[[ "$result" == ".claude/specs/my-feature" ]] && pass "extract 'spec_dir' field" || fail "extract 'spec_dir' field" "got '${result}'"

# Test: missing field returns empty
result=$(pdlc_get_field "nonexistent")
[[ -z "$result" ]] && pass "missing field returns empty" || fail "missing field returns empty" "got '${result}'"

# Test: empty frontmatter
setup
mkdir -p "${PDLC_STATE_DIR}"
cat > "${PDLC_HANDOFF}" <<'EOF'
---
---

Some body
EOF
result=$(pdlc_get_field "phase")
[[ -z "$result" ]] && pass "empty frontmatter returns empty" || fail "empty frontmatter returns empty" "got '${result}'"

# Test: no frontmatter at all
setup
mkdir -p "${PDLC_STATE_DIR}"
cat > "${PDLC_HANDOFF}" <<'EOF'
Just plain text, no frontmatter.
EOF
result=$(pdlc_get_field "phase")
[[ -z "$result" ]] && pass "no frontmatter returns empty" || fail "no frontmatter returns empty" "got '${result}'"

# Test: file does not exist
setup
result=$(pdlc_get_field "phase")
[[ -z "$result" ]] && pass "nonexistent file returns empty" || fail "nonexistent file returns empty" "got '${result}'"

# Test: field name substring should not match (e.g., "batch" should not match "batch_1_advocate")
setup
mkdir -p "${PDLC_STATE_DIR}"
cat > "${PDLC_HANDOFF}" <<'EOF'
---
batch: 2
batch_1_advocate: DONE
---
EOF
result=$(pdlc_get_field "batch")
[[ "$result" == "2" ]] && pass "exact field match (no substring bleed)" || fail "exact field match (no substring bleed)" "got '${result}'"

echo ""
echo "=== pdlc_write_handoff ==="

# Test: atomic write with frontmatter + body
setup
pdlc_write_handoff "phase: ACTOR
batch: 1" "## My Body

Content here."
[[ -f "${PDLC_HANDOFF}" ]] && pass "file created" || fail "file created" "file not found"
# Check content
head -1 "${PDLC_HANDOFF}" | grep -q '^---' && pass "starts with ---" || fail "starts with ---" "$(head -1 "${PDLC_HANDOFF}")"
grep -q "phase: ACTOR" "${PDLC_HANDOFF}" && pass "contains phase field" || fail "contains phase field" ""
grep -q "## My Body" "${PDLC_HANDOFF}" && pass "contains body" || fail "contains body" ""

# Test: temp file cleanup (no .tmp left behind)
[[ ! -f "${PDLC_HANDOFF}.tmp" ]] && pass "no .tmp file left" || fail "no .tmp file left" "tmp file exists"

# Test: write without body
setup
pdlc_write_handoff "phase: DONE" ""
content=$(cat "${PDLC_HANDOFF}")
# Should have frontmatter but no body section
line_count=$(wc -l < "${PDLC_HANDOFF}" | tr -d ' ')
[[ "$line_count" -eq 3 ]] && pass "write without body has 3 lines" || fail "write without body has 3 lines" "got ${line_count} lines"

echo ""
echo "=== pdlc_set_field ==="

# Test: update existing field
setup
pdlc_write_handoff "phase: ACTOR
batch: 1" "Body text"
pdlc_set_field "phase" "CRITIC"
result=$(pdlc_get_field "phase")
[[ "$result" == "CRITIC" ]] && pass "update existing field" || fail "update existing field" "got '${result}'"
# Verify batch unchanged
result=$(pdlc_get_field "batch")
[[ "$result" == "1" ]] && pass "other fields preserved" || fail "other fields preserved" "got '${result}'"
# Verify body preserved
grep -q "Body text" "${PDLC_HANDOFF}" && pass "body preserved after set_field" || fail "body preserved after set_field" ""

# Test: add new field
setup
pdlc_write_handoff "phase: ACTOR" "Body"
pdlc_set_field "batch" "5"
result=$(pdlc_get_field "batch")
[[ "$result" == "5" ]] && pass "add new field" || fail "add new field" "got '${result}'"
# Verify original field still there
result=$(pdlc_get_field "phase")
[[ "$result" == "ACTOR" ]] && pass "original field preserved after add" || fail "original field preserved after add" "got '${result}'"

# Test: handle no-frontmatter file
setup
mkdir -p "${PDLC_STATE_DIR}"
echo "Just plain text" > "${PDLC_HANDOFF}"
pdlc_set_field "phase" "INIT"
result=$(pdlc_get_field "phase")
[[ "$result" == "INIT" ]] && pass "set_field on no-frontmatter file" || fail "set_field on no-frontmatter file" "got '${result}'"
# Old content should be preserved as body
grep -q "Just plain text" "${PDLC_HANDOFF}" && pass "old content preserved as body" || fail "old content preserved as body" ""

# Test: handle nonexistent file
setup
pdlc_set_field "phase" "NEW"
result=$(pdlc_get_field "phase")
[[ "$result" == "NEW" ]] && pass "set_field creates file if missing" || fail "set_field creates file if missing" "got '${result}'"

# Test: no .tmp left after set_field
[[ ! -f "${PDLC_HANDOFF}.tmp" ]] && pass "no .tmp after set_field" || fail "no .tmp after set_field" ""

echo ""
echo "=== pdlc_read_json_field ==="

# Test: valid JSON parsing
result=$(echo '{"tool_name":"Task","tool_input":{"prompt":"hello world"}}' | pdlc_read_json_field "tool_name")
[[ "$result" == "Task" ]] && pass "read top-level JSON field" || fail "read top-level JSON field" "got '${result}'"

result=$(echo '{"tool_name":"Task","tool_input":{"prompt":"hello world"}}' | pdlc_read_json_field "tool_input.prompt")
[[ "$result" == "hello world" ]] && pass "read nested JSON field" || fail "read nested JSON field" "got '${result}'"

# Test: missing field returns empty
result=$(echo '{"tool_name":"Task"}' | pdlc_read_json_field "nonexistent")
[[ -z "$result" ]] && pass "missing JSON field returns empty" || fail "missing JSON field returns empty" "got '${result}'"

# Test: invalid JSON — jq returns error, we get empty
result=$(echo 'not json' | pdlc_read_json_field "tool_name" 2>/dev/null || echo "")
[[ -z "$result" ]] && pass "invalid JSON returns empty" || fail "invalid JSON returns empty" "got '${result}'"

echo ""
echo "=== Marker file operations ==="

# Test: touch marker
setup
pdlc_ensure_state_dir
pdlc_touch_marker
[[ -f "${PDLC_MARKER}" ]] && pass "touch_marker creates file" || fail "touch_marker creates file" ""

# Test: marker_exists returns 0 when exists
pdlc_marker_exists && pass "marker_exists returns 0 when file exists" || fail "marker_exists returns 0 when file exists" ""

# Test: delete marker
pdlc_delete_marker
[[ ! -f "${PDLC_MARKER}" ]] && pass "delete_marker removes file" || fail "delete_marker removes file" ""

# Test: marker_exists returns 1 when missing
pdlc_marker_exists && fail "marker_exists should return 1 when missing" "" || pass "marker_exists returns 1 when file missing"

# Test: delete on already-absent marker (should not error)
pdlc_delete_marker && pass "delete absent marker no error" || fail "delete absent marker no error" "got exit code $?"

echo ""
echo "=========================================="
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
