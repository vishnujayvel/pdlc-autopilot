#!/bin/bash
# =============================================================================
# spec-gate.sh — SpecGate: Block Spec Generation via Task Tool
# =============================================================================
#
# Prevents spec artifacts (requirements.md, design.md, tasks.md) from being
# generated through general-purpose Task subagents. Only Kiro skills
# (kiro:spec-requirements, kiro:spec-design, kiro:spec-tasks) should produce
# spec artifacts.
#
# HOW IT WORKS
# -------------
# 1. Reads the hook JSON payload from stdin
# 2. Checks if the tool being invoked is "Task"
# 3. Scans the prompt for patterns that indicate spec-generation intent
# 4. If a match is found, denies the call with an error-recovery message
#    directing the user to use the Skill tool with Kiro skills instead
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
#           "command": "bash /path/to/spec-gate.sh"
#         }]
#       }]
#     }
#   }
#
# ENVIRONMENT VARIABLES
# ---------------------
#   PDLC_SPECGATE_PATTERNS — Pipe-separated regex patterns to match against the
#                          Task prompt (case-insensitive). Override to customize
#                          which phrases trigger the guard.
#                          Default: generate requirements|write requirements\.md|
#                          generate design|write design\.md|generate tasks|
#                          write tasks\.md|create spec|write specification
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

# Only check Task tool calls
if [[ "${TOOL_NAME}" != "Task" ]]; then
  echo '{"decision": "allow"}'
  exit 0
fi

PROMPT=$(pdlc_read_json_field "tool_input.prompt" <<< "$STDIN_JSON")

# Configurable patterns — check env var or default list
PATTERNS="${PDLC_SPECGATE_PATTERNS:-generate requirements|write requirements\.md|generate design|write design\.md|generate tasks|write tasks\.md|create spec|write specification|produce.*requirements|draft.*design|author.*spec|build.*requirements|create.*requirements|output.*design|assemble.*tasks|spec.*artifact}"

if echo "${PROMPT}" | grep -qiE "${PATTERNS}"; then
  # DENY with error-recovery XML framing
  REASON="<error-recovery>SpecGate VIOLATION: Spec artifacts (requirements.md, design.md, tasks.md) MUST be generated using the Skill tool with Kiro skills (kiro:spec-requirements, kiro:spec-design, kiro:spec-tasks). Do NOT use the Task tool to write spec artifacts. Use the Skill tool instead.</error-recovery>"
  echo "{\"decision\": \"deny\", \"reason\": $(echo "$REASON" | jq -Rs .)}"
  exit 0
fi

echo '{"decision": "allow"}'
exit 0
