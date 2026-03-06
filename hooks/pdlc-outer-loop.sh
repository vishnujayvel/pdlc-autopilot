#!/bin/bash
# =============================================================================
# pdlc-outer-loop.sh — PDLC Autopilot Outer Loop Orchestrator
# =============================================================================
#
# Launches fresh Claude Code sessions per batch, cycling until all tasks are
# complete or a circuit breaker fires. Each session reads its marching orders
# from .pdlc/state/HANDOFF.md and updates it on completion.
#
# USAGE
# -----
#   PDLC_SPEC_DIR=.claude/specs/my-feature ./hooks/pdlc-outer-loop.sh
#
# HOW IT WORKS
# ------------
# 1. Reads HANDOFF.md to determine current phase
# 2. If phase == DONE, exits with final report
# 3. Launches `claude -p` with --output-format json, --max-turns, --max-budget-usd
# 4. After session: parses cost from JSON output, checks git diff for changes
# 5. If changes: auto-commits with batch info
# 6. Checks circuit breakers (max sessions, max cost, no-progress)
# 7. Loops back to step 1
#
# ENVIRONMENT VARIABLES
# ---------------------
#   PDLC_SPEC_DIR        — REQUIRED. Path to spec directory.
#   PDLC_MAX_SESSIONS    — Max sessions before stopping (default: 10)
#   PDLC_MAX_COST_USD    — Max aggregate cost in USD (default: 50.00)
#   PDLC_MAX_NO_PROGRESS — Max consecutive no-change sessions (default: 3)
#   PDLC_MAX_TURNS       — Per-session max turns (default: 30)
#   PDLC_SESSION_BUDGET  — Per-session max cost in USD (default: 5.00)
#   PDLC_ALLOWED_TOOLS   — Comma-separated tool whitelist
#   PDLC_STATE_FILE      — Path to HANDOFF.md (default: .pdlc/state/HANDOFF.md)
#
# EXIT CODES
# ----------
#   0 — All batches complete (phase == DONE)
#   1 — Circuit breaker fired
#   2 — Configuration error
#
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/pdlc-state.sh"

# --- Configuration ---
SPEC_DIR="${PDLC_SPEC_DIR:-}"
MAX_SESSIONS="${PDLC_MAX_SESSIONS:-10}"
MAX_COST_USD="${PDLC_MAX_COST_USD:-50.00}"
MAX_NO_PROGRESS="${PDLC_MAX_NO_PROGRESS:-3}"
MAX_TURNS="${PDLC_MAX_TURNS:-30}"
SESSION_BUDGET="${PDLC_SESSION_BUDGET:-5.00}"
ALLOWED_TOOLS="${PDLC_ALLOWED_TOOLS:-Read,Write,Edit,Bash,Glob,Grep,Task,Skill,Agent}"
# Note: STATE_FILE always uses PDLC_HANDOFF from the library
# The PDLC_STATE_FILE env var is reserved for future SDK migration
STATE_FILE="${PDLC_HANDOFF}"

# --- Validation ---
if [[ -z "${SPEC_DIR}" ]]; then
  echo "ERROR: PDLC_SPEC_DIR is required. Set it to the spec directory path." >&2
  echo "  Example: PDLC_SPEC_DIR=.claude/specs/my-feature ./hooks/pdlc-outer-loop.sh" >&2
  exit 2
fi

if ! command -v claude &>/dev/null; then
  echo "ERROR: 'claude' CLI not found in PATH." >&2
  exit 2
fi

if ! command -v jq &>/dev/null; then
  echo "ERROR: 'jq' not found. Install it: brew install jq" >&2
  exit 2
fi

# Check if git is available (warn but don't fail)
GIT_AVAILABLE=true
if ! git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
  echo "WARNING: Not a git repository. Auto-commit disabled." >&2
  GIT_AVAILABLE=false
fi

# --- Initialize HANDOFF.md if missing ---
pdlc_ensure_state_dir
if [[ ! -f "${STATE_FILE}" ]]; then
  echo "Initializing HANDOFF.md for spec: ${SPEC_DIR}"
  # Read tasks.md to get initial pending tasks list
  TASKS_FILE="${SPEC_DIR}/tasks.md"
  PENDING_TASKS=""
  if [[ -f "${TASKS_FILE}" ]]; then
    # Extract task numbers from "- [ ] N.N" lines
    PENDING_TASKS=$(grep -oE '^\- \[ \] [0-9]+\.[0-9]+' "${TASKS_FILE}" | sed 's/- \[ \] /T-/' | tr '\n' ',' | sed 's/,$//' || true)
  fi

  pdlc_write_handoff "phase: INIT
batch: 1
spec_dir: ${SPEC_DIR}
pending_tasks: ${PENDING_TASKS}
completed_tasks:
total_cost_usd: 0.00
session_count: 0
partial: false" "## Current Batch Context

Starting PDLC session for ${SPEC_DIR}.

## Key Decisions

None yet.

## Blocking Issues

None."
fi

# --- Session loop ---
SESSION_COUNT=0
TOTAL_COST=0.00
NO_PROGRESS=0

echo "=========================================="
echo "PDLC Outer Loop -- ${SPEC_DIR}"
echo "Max sessions: ${MAX_SESSIONS} | Max cost: \$${MAX_COST_USD}"
echo "=========================================="

while [[ "${SESSION_COUNT}" -lt "${MAX_SESSIONS}" ]]; do
  # Check completion
  PHASE=$(pdlc_get_field "phase")
  if [[ "${PHASE}" == "DONE" ]]; then
    echo ""
    echo "=========================================="
    echo "ALL BATCHES COMPLETE"
    echo "  Total sessions: ${SESSION_COUNT}"
    echo "  Total cost: \$${TOTAL_COST}"
    echo "=========================================="
    exit 0
  fi

  SESSION_COUNT=$((SESSION_COUNT + 1))
  BATCH=$(pdlc_get_field "batch")
  echo ""
  echo "--- Session ${SESSION_COUNT}/${MAX_SESSIONS} (Batch ${BATCH:-?}, Phase: ${PHASE:-INIT}) ---"

  # Launch fresh session
  RESULT=$(claude -p \
    --output-format json \
    --max-turns "${MAX_TURNS}" \
    --max-budget-usd "${SESSION_BUDGET}" \
    --allowedTools "${ALLOWED_TOOLS}" \
    --append-system-prompt "You are a PDLC Autopilot session. Read .pdlc/state/HANDOFF.md for your current task. Update it when done. Spec directory: ${SPEC_DIR}" \
    "You are a PDLC Autopilot session. Read HANDOFF.md and execute the next batch." 2>/dev/null) || true

  # Parse cost from JSON output
  SESSION_COST=$(echo "${RESULT}" | jq -r '.usage.total_cost_usd // 0' 2>/dev/null || echo "0")
  [[ -z "${SESSION_COST}" || "${SESSION_COST}" == "null" ]] && SESSION_COST="0"
  TOTAL_COST=$(echo "${TOTAL_COST} + ${SESSION_COST}" | bc 2>/dev/null || echo "${TOTAL_COST}")

  # Update HANDOFF.md cost tracking
  pdlc_set_field "total_cost_usd" "${TOTAL_COST}"
  pdlc_set_field "session_count" "${SESSION_COUNT}"

  echo "  Cost: \$${SESSION_COST} (total: \$${TOTAL_COST})"

  # --- Circuit breaker: max cost ---
  if (( $(echo "${TOTAL_COST} > ${MAX_COST_USD}" | bc -l 2>/dev/null || echo 0) )); then
    echo ""
    echo "CIRCUIT BREAKER: Cost limit reached (\$${TOTAL_COST})"
    echo "  State preserved in ${STATE_FILE}"
    echo "  Resume with: PDLC_SPEC_DIR=${SPEC_DIR} ./hooks/pdlc-outer-loop.sh"
    exit 1
  fi

  # --- Progress detection ---
  if [[ "${GIT_AVAILABLE}" == "true" ]]; then
    CHANGES=$(git diff --stat HEAD 2>/dev/null || echo "")
    if [[ -z "${CHANGES}" ]]; then
      NO_PROGRESS=$((NO_PROGRESS + 1))
      echo "  No file changes (${NO_PROGRESS}/${MAX_NO_PROGRESS})"

      # Circuit breaker: no progress
      if [[ "${NO_PROGRESS}" -ge "${MAX_NO_PROGRESS}" ]]; then
        echo ""
        echo "CIRCUIT BREAKER: No progress for ${MAX_NO_PROGRESS} consecutive sessions"
        echo "  State preserved in ${STATE_FILE}"
        echo "  Resume with: PDLC_SPEC_DIR=${SPEC_DIR} ./hooks/pdlc-outer-loop.sh"
        exit 1
      fi
    else
      NO_PROGRESS=0
      echo "  Changes detected, committing..."
      # Commit specific tracked files (not git add .) — per-directory to avoid atomic failure
      for dir in hooks/ .pdlc/ "${SPEC_DIR}/" src/ tests/; do
        [[ -d "$dir" ]] && git add -A -- "$dir" 2>/dev/null || true
      done
      git commit -m "pdlc: batch ${BATCH:-?} session ${SESSION_COUNT} (\$${SESSION_COST})" 2>/dev/null || true
    fi
  fi
done

# Circuit breaker: max sessions
echo ""
echo "CIRCUIT BREAKER: Max sessions reached (${MAX_SESSIONS})"
echo "  State preserved in ${STATE_FILE}"
echo "  Resume with: PDLC_SPEC_DIR=${SPEC_DIR} ./hooks/pdlc-outer-loop.sh"
exit 1
