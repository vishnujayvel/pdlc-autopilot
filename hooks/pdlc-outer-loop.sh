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
#   PDLC_MAX_PARALLEL    — Max parallel sessions (default: 1). Reserved for
#                          future T-Mode parallelism (Phase 5).
#   PDLC_MAX_RETRIES     — Max retry attempts per batch after Critic rejection (default: 3)
#
# EXIT CODES
# ----------
#   0   — All batches complete (phase == DONE or lifecycle == Archived)
#   1   — Circuit breaker fired
#   2   — Configuration error
#   3   — Escalated — Director cannot resolve Critic findings, human intervention needed
#   130 — Interrupted by SIGINT/SIGTERM (state saved as partial)
#
# =============================================================================

set -euo pipefail

# Bypass for PDLC self-development (bootstrapping circularity)
if [[ "${PDLC_DISABLED:-0}" == "1" ]]; then
  echo "PDLC outer loop disabled (PDLC_DISABLED=1). Skipping."
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/pdlc-state.sh"
source "${SCRIPT_DIR}/lib/pdlc-director.sh"

# --- Configuration ---
SPEC_DIR="${PDLC_SPEC_DIR:-}"
MAX_SESSIONS="${PDLC_MAX_SESSIONS:-10}"
MAX_COST_USD="${PDLC_MAX_COST_USD:-50.00}"
MAX_NO_PROGRESS="${PDLC_MAX_NO_PROGRESS:-3}"
MAX_TURNS="${PDLC_MAX_TURNS:-30}"
SESSION_BUDGET="${PDLC_SESSION_BUDGET:-5.00}"
ALLOWED_TOOLS="${PDLC_ALLOWED_TOOLS:-Read,Write,Edit,Bash,Glob,Grep,Task,Skill,Agent}"
MAX_PARALLEL="${PDLC_MAX_PARALLEL:-1}"  # Reserved for T-Mode (Phase 5)
STATE_FILE="${PDLC_HANDOFF}"

# --- Child process tracking ---
CHILD_PID=""
INTERRUPTED=false
SESSION_OUTPUT=""

# --- Signal + EXIT cleanup ---
# Unified handler for SIGINT, SIGTERM, and EXIT.
# On signal: full cleanup (kill children, save partial state, exit 130).
# On normal EXIT: lightweight resource cleanup (temp files only, preserves exit code).
cleanup() {
  # Guard against re-entrant cleanup (EXIT fires after SIGINT/SIGTERM handler)
  if [[ "${INTERRUPTED}" == "true" ]]; then
    # Re-entrant EXIT after signal — just clean temp files
    if [[ -n "${SESSION_OUTPUT}" ]] && [[ -f "${SESSION_OUTPUT}" ]]; then
      rm -f "${SESSION_OUTPUT}"
    fi
    return 0
  fi

  # Detect if called from a signal (SIGINT/SIGTERM) vs normal EXIT
  # If CHILD_PID is set and running, we were interrupted mid-session
  local is_signal=false
  if [[ -n "${CHILD_PID}" ]] && kill -0 "${CHILD_PID}" 2>/dev/null; then
    is_signal=true
  fi

  # Always clean up temp files
  if [[ -n "${SESSION_OUTPUT}" ]] && [[ -f "${SESSION_OUTPUT}" ]]; then
    rm -f "${SESSION_OUTPUT}"
  fi

  # On normal EXIT, just clean temp files and return (preserve exit code)
  if [[ "$is_signal" == "false" ]]; then
    return 0
  fi

  # Signal path: full interruption cleanup
  INTERRUPTED=true

  echo ""
  echo "=========================================="
  echo "INTERRUPTED — cleaning up..."
  echo "=========================================="

  # Kill child claude session if still running
  echo "  Terminating claude session (PID ${CHILD_PID})..."
  kill "${CHILD_PID}" 2>/dev/null || true
  wait "${CHILD_PID}" 2>/dev/null || true

  # Save partial state to HANDOFF.md
  if [[ -f "${STATE_FILE}" ]]; then
    pdlc_set_field "partial" "true"
    echo "  State saved (partial: true) in ${STATE_FILE}"
  fi

  echo "  Total sessions: ${SESSION_COUNT:-0}"
  echo "  Total cost: \$${TOTAL_COST:-0.00}"
  echo "  Resume with: PDLC_SPEC_DIR=${SPEC_DIR} ./hooks/pdlc-outer-loop.sh"
  echo "=========================================="
  exit 130
}

trap cleanup SIGINT SIGTERM EXIT

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

if ! command -v bc &>/dev/null; then
  echo "ERROR: 'bc' not found. Required for cost tracking." >&2
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

# --- Session loop (resume from HANDOFF.md if restarting) ---
SESSION_COUNT=$(pdlc_get_field "session_count")
SESSION_COUNT="${SESSION_COUNT:-0}"
TOTAL_COST=$(pdlc_get_field "total_cost_usd")
TOTAL_COST="${TOTAL_COST:-0.00}"
NO_PROGRESS=0

echo "=========================================="
echo "PDLC Outer Loop -- ${SPEC_DIR}"
echo "Max sessions: ${MAX_SESSIONS} | Max cost: \$${MAX_COST_USD}"
echo "=========================================="

while [[ "${SESSION_COUNT}" -lt "${MAX_SESSIONS}" ]]; do
  # --- Director Step 1: Infer lifecycle state ---
  LIFECYCLE_STATE=$(pdlc_lifecycle_infer "${SPEC_DIR}")
  pdlc_set_field "spec_lifecycle" "${LIFECYCLE_STATE}"

  # Check completion (DONE phase or Archived/Complete lifecycle)
  PHASE=$(pdlc_get_field "phase")
  if [[ "${PHASE}" == "DONE" || "${LIFECYCLE_STATE}" == "Archived" ]]; then
    echo ""
    echo "=========================================="
    echo "ALL BATCHES COMPLETE"
    echo "  Lifecycle state: ${LIFECYCLE_STATE}"
    echo "  Total sessions: ${SESSION_COUNT}"
    echo "  Total cost: \$${TOTAL_COST}"
    echo "=========================================="
    exit 0
  fi

  # Check escalation
  if [[ "${PHASE}" == "ESCALATED" ]]; then
    echo ""
    echo "=========================================="
    echo "ESCALATED — Human intervention needed"
    echo "  See HANDOFF.md for details."
    echo "  Resume with: PDLC_SPEC_DIR=${SPEC_DIR} ./hooks/pdlc-outer-loop.sh"
    echo "=========================================="
    exit 3
  fi

  SESSION_COUNT=$((SESSION_COUNT + 1))
  BATCH=$(pdlc_get_field "batch")
  echo ""
  echo "--- Session ${SESSION_COUNT}/${MAX_SESSIONS} (Lifecycle: ${LIFECYCLE_STATE}, Batch: ${BATCH:-?}) ---"

  # --- Director Step 2: Decide what to do and how ---
  DECISION=$(pdlc_director_decide "${SPEC_DIR}" "${LIFECYCLE_STATE}")
  IFS=$'\x1e' read -r DIRECTOR_ACTION DIRECTOR_MODE DIRECTOR_RATIONALE ACTOR_PROMPT <<< "${DECISION}"

  echo "  Director: action=${DIRECTOR_ACTION} mode=${DIRECTOR_MODE}"
  echo "  Rationale: ${DIRECTOR_RATIONALE}"

  # Update HANDOFF.md with Director decision
  pdlc_set_field "director_action" "${DIRECTOR_ACTION}"
  pdlc_set_field "director_mode" "${DIRECTOR_MODE}"

  # --- Director Step 3: Dispatch Actor ---
  SESSION_OUTPUT=$(mktemp)

  claude -p \
    --output-format json \
    --max-turns "${MAX_TURNS}" \
    --max-budget-usd "${SESSION_BUDGET}" \
    --allowedTools "${ALLOWED_TOOLS}" \
    --append-system-prompt "You are a PDLC Actor session. Spec directory: ${SPEC_DIR}. Lifecycle state: ${LIFECYCLE_STATE}." \
    "${ACTOR_PROMPT}" \
    > "${SESSION_OUTPUT}" 2>/dev/null &
  CHILD_PID=$!
  wait "${CHILD_PID}" || true
  CHILD_PID=""
  RESULT=$(cat "${SESSION_OUTPUT}")
  rm -f "${SESSION_OUTPUT}"
  SESSION_OUTPUT=""

  # Parse cost from JSON output
  SESSION_COST=$(echo "${RESULT}" | jq -r '.usage.total_cost_usd // 0' 2>/dev/null || echo "0")
  [[ -z "${SESSION_COST}" || "${SESSION_COST}" == "null" ]] && SESSION_COST="0"
  TOTAL_COST=$(echo "${TOTAL_COST} + ${SESSION_COST}" | bc 2>/dev/null || echo "${TOTAL_COST}")

  # Update HANDOFF.md cost tracking
  pdlc_set_field "total_cost_usd" "${TOTAL_COST}"
  pdlc_set_field "session_count" "${SESSION_COUNT}"

  echo "  Cost: \$${SESSION_COST} (total: \$${TOTAL_COST})"

  # --- Director Step 4: Evaluate Critic feedback ---
  RETRY_COUNT=$(pdlc_get_field "retry_count")
  RETRY_COUNT="${RETRY_COUNT:-0}"
  CRITIC_VERDICT=$(pdlc_director_evaluate_critics "${BATCH:-1}" "${RETRY_COUNT}")
  echo "  Critic verdict: ${CRITIC_VERDICT}"

  if [[ "${CRITIC_VERDICT}" == "escalate" ]]; then
    pdlc_set_field "phase" "ESCALATED"
    echo ""
    echo "ESCALATED — Director cannot resolve Critic findings after ${RETRY_COUNT} retries."
    echo "  See HANDOFF.md for details."
    exit 3
  elif [[ "${CRITIC_VERDICT}" == "retry" ]]; then
    RETRY_COUNT=$((RETRY_COUNT + 1))
    pdlc_set_field "retry_count" "${RETRY_COUNT}"
    echo "  Retrying (attempt ${RETRY_COUNT}/${PDLC_MAX_RETRIES})"
  else
    # Accept — reset retry counter
    pdlc_set_field "retry_count" "0"
  fi

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
      git commit -m "pdlc: ${DIRECTOR_ACTION} session ${SESSION_COUNT} [${LIFECYCLE_STATE}] (\$${SESSION_COST})" 2>/dev/null || true
    fi
  fi
done

# Circuit breaker: max sessions
echo ""
echo "CIRCUIT BREAKER: Max sessions reached (${MAX_SESSIONS})"
echo "  State preserved in ${STATE_FILE}"
echo "  Resume with: PDLC_SPEC_DIR=${SPEC_DIR} ./hooks/pdlc-outer-loop.sh"
exit 1
