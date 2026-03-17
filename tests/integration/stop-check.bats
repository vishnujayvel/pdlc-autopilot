#!/usr/bin/env bats
# tests/integration/stop-check.bats — BATS tests for hooks/pdlc-stop-check.sh

load ../helpers/common-setup

# Helper: create an active spec dir with tasks.md in a workdir
# Usage: create_spec_dir "$workdir" "feature-name" "tasks content"
create_spec_dir() {
  local workdir="$1"
  local feature="$2"
  local tasks_content="$3"
  local spec_dir="${workdir}/.claude/specs/${feature}"
  mkdir -p "$spec_dir"
  echo '{"active_workflow": "pdlc-autopilot"}' > "${spec_dir}/spec.json"
  printf '%s\n' "$tasks_content" > "${spec_dir}/tasks.md"
}

# Helper: make all files in a spec dir appear old (stale)
# Sets modification time to N+1 days ago to ensure staleness
make_spec_stale() {
  local workdir="$1"
  local feature="$2"
  local days="${3:-6}"
  local spec_dir="${workdir}/.claude/specs/${feature}"
  # Use touch -t with a timestamp days_ago
  local past_ts
  past_ts="$(date -v-${days}d '+%Y%m%d0000' 2>/dev/null || date -d "${days} days ago" '+%Y%m%d0000' 2>/dev/null)"
  for file in "$spec_dir"/*; do
    [[ -f "$file" ]] && touch -t "$past_ts" "$file"
  done
}

# Helper: run stop-check from a given workdir, capturing stderr and exit code
run_stop_check() {
  local workdir="$1"
  shift
  # Run in subshell from workdir; capture stderr to stdout for assertion
  (cd "$workdir" && env "$@" bash "${HOOKS_DIR}/pdlc-stop-check.sh" 2>&1) || return $?
}

@test "no active spec allows exit (exit 0)" {
  local workdir="${TEST_WORK_DIR}/t1"
  mkdir -p "${workdir}/.claude/specs"
  # No spec.json with pdlc-autopilot workflow
  run_stop_check "$workdir" PDLC_COUNTER_FILE="${TEST_WORK_DIR}/counter1"
}

@test "all tasks complete allows exit (exit 0)" {
  local workdir="${TEST_WORK_DIR}/t2"
  create_spec_dir "$workdir" "done-feature" "$(cat <<'EOF'
# Tasks
- [x] Task one
- [x] Task two
- [x] Task three
EOF
)"
  run_stop_check "$workdir" PDLC_COUNTER_FILE="${TEST_WORK_DIR}/counter2"
}

@test "non-stale spec with pending tasks blocks exit (exit 1)" {
  local workdir="${TEST_WORK_DIR}/t3"
  create_spec_dir "$workdir" "active-feature" "$(cat <<'EOF'
# Tasks
- [x] Task one
- [ ] Task two
- [ ] Task three
EOF
)"
  # Files just created — not stale
  run run_stop_check "$workdir" PDLC_COUNTER_FILE="${TEST_WORK_DIR}/counter3" PDLC_STALE_DAYS=5
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"tasks still pending"* ]]
}

@test "stale spec with pending tasks warns and allows exit (exit 0)" {
  local workdir="${TEST_WORK_DIR}/t4"
  create_spec_dir "$workdir" "stale-feature" "$(cat <<'EOF'
# Tasks
- [ ] Task one
- [ ] Task two
EOF
)"
  # Make files appear 6 days old (stale with default 5-day threshold)
  make_spec_stale "$workdir" "stale-feature" 6

  output="$(run_stop_check "$workdir" PDLC_COUNTER_FILE="${TEST_WORK_DIR}/counter4" PDLC_STALE_DAYS=5)"
  [[ "$output" == *"Spec appears stale"* ]]
  [[ "$output" == *"Allowing exit"* ]]
}

@test "custom PDLC_STALE_DAYS=1 triggers staleness for 2-day-old spec" {
  local workdir="${TEST_WORK_DIR}/t5"
  create_spec_dir "$workdir" "custom-stale" "$(cat <<'EOF'
# Tasks
- [ ] Pending task
EOF
)"
  # Make files appear 2 days old
  make_spec_stale "$workdir" "custom-stale" 2

  output="$(run_stop_check "$workdir" PDLC_COUNTER_FILE="${TEST_WORK_DIR}/counter5" PDLC_STALE_DAYS=1)"
  [[ "$output" == *"Spec appears stale"* ]]
  [[ "$output" == *"1+ days"* ]]
}

@test "custom PDLC_STALE_DAYS=10 does not trigger staleness for 6-day-old spec" {
  local workdir="${TEST_WORK_DIR}/t6"
  create_spec_dir "$workdir" "not-stale-yet" "$(cat <<'EOF'
# Tasks
- [ ] Pending task
EOF
)"
  # Make files appear 6 days old — but threshold is 10
  make_spec_stale "$workdir" "not-stale-yet" 6

  run run_stop_check "$workdir" PDLC_COUNTER_FILE="${TEST_WORK_DIR}/counter6" PDLC_STALE_DAYS=10
  [[ "$status" -ne 0 ]]
  [[ "$output" == *"tasks still pending"* ]]
}

@test "safety limit still works when spec is not stale" {
  local workdir="${TEST_WORK_DIR}/t7"
  create_spec_dir "$workdir" "safety-feature" "$(cat <<'EOF'
# Tasks
- [ ] Pending task
EOF
)"
  # Pre-set counter at the limit
  echo "50" > "${TEST_WORK_DIR}/counter7"

  output="$(run_stop_check "$workdir" PDLC_COUNTER_FILE="${TEST_WORK_DIR}/counter7" PDLC_MAX_CONTINUES=50)"
  [[ "$output" == *"Safety limit reached"* ]]
}

@test "stale check runs before safety limit check" {
  local workdir="${TEST_WORK_DIR}/t8"
  create_spec_dir "$workdir" "stale-before-safety" "$(cat <<'EOF'
# Tasks
- [ ] Pending task
EOF
)"
  make_spec_stale "$workdir" "stale-before-safety" 6

  # Even with counter at 0, stale should trigger first
  echo "0" > "${TEST_WORK_DIR}/counter8"

  output="$(run_stop_check "$workdir" PDLC_COUNTER_FILE="${TEST_WORK_DIR}/counter8" PDLC_STALE_DAYS=5)"
  [[ "$output" == *"Spec appears stale"* ]]
  # Should NOT mention safety limit
  [[ "$output" != *"Safety limit"* ]]
}

@test "stale warning includes pending task count" {
  local workdir="${TEST_WORK_DIR}/t9"
  create_spec_dir "$workdir" "stale-with-count" "$(cat <<'EOF'
# Tasks
- [ ] Task A
- [ ] Task B
- [x] Task C
EOF
)"
  make_spec_stale "$workdir" "stale-with-count" 6

  output="$(run_stop_check "$workdir" PDLC_COUNTER_FILE="${TEST_WORK_DIR}/counter9" PDLC_STALE_DAYS=5)"
  [[ "$output" == *"2 tasks still pending"* ]]
}

@test "counter is reset when spec is stale" {
  local workdir="${TEST_WORK_DIR}/t10"
  create_spec_dir "$workdir" "stale-reset" "$(cat <<'EOF'
# Tasks
- [ ] Pending
EOF
)"
  make_spec_stale "$workdir" "stale-reset" 6

  # Pre-set a counter value
  echo "10" > "${TEST_WORK_DIR}/counter10"

  run_stop_check "$workdir" PDLC_COUNTER_FILE="${TEST_WORK_DIR}/counter10" PDLC_STALE_DAYS=5
  # Counter file should be removed after stale exit
  [[ ! -f "${TEST_WORK_DIR}/counter10" ]]
}

@test "PDLC_DISABLED=1 bypasses stop-check (allows exit with pending tasks)" {
  local workdir="${TEST_WORK_DIR}/t11"
  create_spec_dir "$workdir" "disabled-feature" "$(cat <<'EOF'
# Tasks
- [ ] Task one
- [ ] Task two
EOF
)"
  # Without PDLC_DISABLED this would block exit; with it, should allow
  run_stop_check "$workdir" PDLC_DISABLED=1 PDLC_COUNTER_FILE="${TEST_WORK_DIR}/counter11" PDLC_STALE_DAYS=5
}
