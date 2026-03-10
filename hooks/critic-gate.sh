#!/bin/bash
# =============================================================================
# critic-gate.sh — CriticGate: Block Actor Dispatch Without Critic Review
# =============================================================================
#
# Prevents dispatching a new Actor batch if the prior batch has not been
# reviewed by both ADVOCATE and SKEPTIC critics. This enforces the
# Actor -> Critic -> Actor cadence required by the PDLC process.
#
# HOW IT WORKS
# -------------
# 1. Reads the hook JSON payload from stdin
# 2. Checks if the tool being invoked is "Task"
# 3. Checks if the prompt contains an Actor dispatch marker ([ACTOR: or [ACTOR[)
# 4. Reads the current batch number from HANDOFF.md
# 5. If batch > 1, checks that the prior batch has non-PENDING advocate and
#    skeptic fields (batch_N_advocate, batch_N_skeptic)
# 6. If either is missing or PENDING, denies the call with an error-recovery
#    message directing the user to dispatch critics first
#
# INSTALLATION
# -------------
# Add to .claude/settings.json under "hooks.PreToolUse":
#
#   {
#     "hooks": {
#       "PreToolUse": [{
#         "hooks": [{
#           "type": "command",
#           "command": "bash /path/to/critic-gate.sh"
#         }]
#       }]
#     }
#   }
#
# ENVIRONMENT VARIABLES
# ---------------------
#   None. State is read from .pdlc/state/HANDOFF.md via pdlc-state.sh.
#
# EXIT CODES
# ----------
#   0 — Always. Hook errors must not block Claude.
#
# =============================================================================

set -euo pipefail

# Safety: always allow on error (hook must never block Claude)
trap 'echo "{\"decision\": \"allow\"}"; exit 0' ERR

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/pdlc-state.sh"

# Read stdin JSON
STDIN_JSON=$(cat)
TOOL_NAME=$(pdlc_read_json_field "tool_name" <<< "$STDIN_JSON")

if [[ "${TOOL_NAME}" != "Task" ]]; then
  echo '{"decision": "allow"}'
  exit 0
fi

PROMPT=$(pdlc_read_json_field "tool_input.prompt" <<< "$STDIN_JSON")

# Check for Actor dispatch markers
if ! echo "${PROMPT}" | grep -qiE '\[ACTOR[:\[]'; then
  echo '{"decision": "allow"}'
  exit 0
fi

# Actor dispatch detected — check if prior batch has critic results
# Read HANDOFF.md frontmatter ONCE (avoid 3 separate file reads)
if [[ ! -f "${PDLC_HANDOFF}" ]]; then
  echo '{"decision": "allow"}'
  exit 0
fi
FRONTMATTER=$(awk '
  BEGIN { in_fm=0; count=0 }
  /^---[[:space:]]*$/ { count++; if (count==1) { in_fm=1; next } else { exit } }
  in_fm { print }
' "${PDLC_HANDOFF}")

if [[ -z "${FRONTMATTER}" ]]; then
  echo '{"decision": "allow"}'
  exit 0
fi

# Extract batch from frontmatter
CURRENT_BATCH=$(echo "${FRONTMATTER}" | awk -F': ' '$1 == "batch" { print $2; exit }')

# If no batch field, allow (can't enforce without state)
if [[ -z "${CURRENT_BATCH}" ]]; then
  echo '{"decision": "allow"}'
  exit 0
fi

# Validate batch is a positive integer
if ! [[ "${CURRENT_BATCH}" =~ ^[0-9]+$ ]]; then
  echo '{"decision": "allow"}'
  exit 0
fi

# First batch — no prior to check
if [[ "${CURRENT_BATCH}" -le 1 ]]; then
  echo '{"decision": "allow"}'
  exit 0
fi

# Check prior batch critic status from already-read frontmatter
PRIOR_BATCH=$((CURRENT_BATCH - 1))
ADVOCATE=$(echo "${FRONTMATTER}" | awk -F': ' -v key="batch_${PRIOR_BATCH}_advocate" '$1 == key { print substr($0, length(key)+3); exit }')
SKEPTIC=$(echo "${FRONTMATTER}" | awk -F': ' -v key="batch_${PRIOR_BATCH}_skeptic" '$1 == key { print substr($0, length(key)+3); exit }')

# Both must be non-empty and not PENDING
if [[ -n "${ADVOCATE}" && "${ADVOCATE}" != "PENDING" && -n "${SKEPTIC}" && "${SKEPTIC}" != "PENDING" ]]; then
  echo '{"decision": "allow"}'
  exit 0
fi

# DENY with error-recovery XML framing
REASON="<error-recovery>CriticGate VIOLATION: Batch ${PRIOR_BATCH} has not been reviewed by both Critics (ADVOCATE=${ADVOCATE:-MISSING}, SKEPTIC=${SKEPTIC:-MISSING}). You MUST dispatch Critic ADVOCATE and Critic SKEPTIC subagents for Batch ${PRIOR_BATCH} before dispatching a new Actor for Batch ${CURRENT_BATCH}.</error-recovery>"
echo "{\"decision\": \"deny\", \"reason\": $(echo "$REASON" | jq -Rs .)}"
exit 0
