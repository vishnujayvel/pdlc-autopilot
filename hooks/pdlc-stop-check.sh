#!/bin/bash
# =============================================================================
# pdlc-stop-check.sh — PDLC Autopilot Stop Guard
# =============================================================================
#
# Prevents Claude Code from exiting when PDLC tasks are still incomplete.
# Install this as a "Stop" hook in your .claude/settings.json to keep the
# autopilot loop running until all tasks are done.
#
# HOW IT WORKS
# ─────────────
# 1. Locates the active spec directory by reading spec.json files under
#    .claude/specs/ and checking for active_workflow == "pdlc-autopilot"
# 2. Reads tasks.md from that spec directory
# 3. Counts pending tasks (lines matching "- [ ]")
# 4. If pending tasks remain AND we haven't exceeded the safety limit,
#    blocks the exit by returning non-zero
#
# INSTALLATION
# ─────────────
# Add to .claude/settings.json under "hooks.Stop":
#
#   {
#     "hooks": {
#       "Stop": [{
#         "hooks": [{
#           "type": "command",
#           "command": "bash /path/to/pdlc-stop-check.sh"
#         }]
#       }]
#     }
#   }
#
# ENVIRONMENT VARIABLES
# ─────────────────────
#   PDLC_MAX_CONTINUES  — Max times to block exit (default: 50).
#                          Safety valve to prevent infinite loops.
#   PDLC_COUNTER_FILE   — Path to the continue counter file.
#                          Default: /tmp/pdlc-stop-counter-$USER
#
# EXIT CODES
# ──────────
#   0 — Allow stop (all tasks complete, no tasks file, or safety limit hit)
#   1 — Block stop (incomplete tasks remain)
#
# =============================================================================

set -euo pipefail

# --- Configuration ---
MAX_CONTINUES="${PDLC_MAX_CONTINUES:-50}"
COUNTER_FILE="${PDLC_COUNTER_FILE:-/tmp/pdlc-stop-counter-${USER:-unknown}}"
PROJECT_DIR="${PWD}"

# --- Find active spec directory ---
find_active_spec() {
  local specs_dir="${PROJECT_DIR}/.claude/specs"

  if [[ ! -d "$specs_dir" ]]; then
    return 1
  fi

  for spec_json in "$specs_dir"/*/spec.json; do
    [[ -f "$spec_json" ]] || continue

    # Check if this spec has pdlc-autopilot as active workflow
    if grep -q '"active_workflow"' "$spec_json" 2>/dev/null &&
       grep -q '"pdlc-autopilot"' "$spec_json" 2>/dev/null; then
      dirname "$spec_json"
      return 0
    fi
  done

  return 1
}

# --- Count pending tasks ---
count_pending_tasks() {
  local tasks_file="$1"

  if [[ ! -f "$tasks_file" ]]; then
    echo "0"
    return
  fi

  # Count unchecked markdown checkboxes: "- [ ]"
  grep -c '^\s*- \[ \]' "$tasks_file" 2>/dev/null || echo "0"
}

# --- Safety counter ---
read_counter() {
  if [[ -f "$COUNTER_FILE" ]]; then
    cat "$COUNTER_FILE" 2>/dev/null || echo "0"
  else
    echo "0"
  fi
}

increment_counter() {
  local current
  current="$(read_counter)"
  echo $(( current + 1 )) > "$COUNTER_FILE"
}

reset_counter() {
  rm -f "$COUNTER_FILE" 2>/dev/null
}

# --- Main logic ---
main() {
  # Find the active PDLC spec
  local spec_dir
  spec_dir="$(find_active_spec)" || {
    # No active PDLC workflow — allow stop
    reset_counter
    exit 0
  }

  local tasks_file="${spec_dir}/tasks.md"
  local pending
  pending="$(count_pending_tasks "$tasks_file")"

  # All tasks complete — allow stop
  if [[ "$pending" -eq 0 ]]; then
    reset_counter
    exit 0
  fi

  # Check safety limit
  local counter
  counter="$(read_counter)"

  if [[ "$counter" -ge "$MAX_CONTINUES" ]]; then
    echo "PDLC Stop Guard: Safety limit reached (${MAX_CONTINUES} continues)." >&2
    echo "  ${pending} tasks still pending. Allowing exit to prevent infinite loop." >&2
    reset_counter
    exit 0
  fi

  # Block exit — tasks remain
  increment_counter
  echo "PDLC Stop Guard: ${pending} tasks still pending in ${tasks_file}" >&2
  echo "  Continue #$(( counter + 1 ))/${MAX_CONTINUES}. Complete remaining tasks before stopping." >&2
  exit 1
}

main "$@"
