#!/usr/bin/env bats
# tests/unit/pdlc-lint.bats — Unit tests for hooks/lib/pdlc-lint.sh

load ../helpers/common-setup

FIXTURES_DIR=""

setup() {
  TEST_WORK_DIR="$(mktemp -d)"
  source "${HOOKS_DIR}/lib/pdlc-lint.sh"
  PDLC_STATE_DIR="${TEST_WORK_DIR}/.pdlc/state"
  PDLC_HANDOFF="${PDLC_STATE_DIR}/HANDOFF.md"
  FIXTURES_DIR="${REPO_DIR}/tests/fixtures/spec-lifecycle"
}

teardown() {
  rm -rf "${TEST_WORK_DIR}"
}

# ──────────────────────────────────────────────────────────
# pdlc_lint_available
# ──────────────────────────────────────────────────────────

@test "lint_available: detects installed tool or returns 1" {
  # This test adapts to whether any lint tool is installed
  if pdlc_lint_available; then
    [[ -n "$PDLC_LINT_CMD" ]]
  else
    [[ -z "$PDLC_LINT_CMD" ]]
  fi
}

@test "lint_available: returns 1 with empty PATH" {
  PATH="" run pdlc_lint_available
  [[ "$status" -eq 1 ]]
}

# ──────────────────────────────────────────────────────────
# pdlc_lint_check
# ──────────────────────────────────────────────────────────

@test "lint_check: handles missing spec directory" {
  run pdlc_lint_check "${TEST_WORK_DIR}/nonexistent"
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -q "INFO"
}

@test "lint_check: handles empty spec directory" {
  local spec_dir="${TEST_WORK_DIR}/empty-spec"
  mkdir -p "$spec_dir"
  run pdlc_lint_check "$spec_dir"
  [[ "$status" -eq 0 ]]
  # No lint tool installed → warns; or no artifacts → INFO
  [[ -z "$output" ]] || echo "$output" | grep -qE "INFO|WARN"
}

@test "lint_check: degrades gracefully when no tool installed" {
  # Override PATH to guarantee no lint tool is found
  PATH="/nonexistent" run pdlc_lint_check "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
}

@test "lint_check: returns clean for well-formed fixture" {
  if ! pdlc_lint_available; then
    skip "No lint tool installed"
  fi
  run pdlc_lint_check "${FIXTURES_DIR}/clean"
  [[ "$status" -eq 0 ]]
}

@test "lint_check: reports violations for malformed fixture" {
  if ! pdlc_lint_available; then
    skip "No lint tool installed"
  fi
  # Create a malformed spec
  local spec_dir="${TEST_WORK_DIR}/malformed"
  mkdir -p "$spec_dir"
  cat > "$spec_dir/spec.md" <<'EOF'
# Title

### Skipped H2 (heading level skip)

Some text

```
unclosed code fence
EOF
  run pdlc_lint_check "$spec_dir"
  [[ "$status" -eq 0 ]]
  # Should have output (violations found) if tool is installed
  [[ -n "$output" ]]
}
