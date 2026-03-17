#!/bin/bash
# =============================================================================
# session-init.sh — PDLC Autopilot Session Start Hook
# =============================================================================
#
# Loads PDLC state on fresh session starts by reading HANDOFF.md and injecting
# its contents into the session context via stdout.
#
# HOW IT WORKS
# ─────────────
# 1. Sources the shared PDLC state library
# 2. Checks if HANDOFF.md exists in the PDLC state directory
# 3. If YES: outputs its contents to stdout (injected into session context)
# 4. If NO: outputs a brief "no active session" message
#
# INSTALLATION
# ─────────────
# Add to .claude/settings.json under "hooks.SessionStart":
#
#   {
#     "hooks": {
#       "SessionStart": [{
#         "matcher": "startup",
#         "hooks": [{
#           "type": "command",
#           "command": "bash /path/to/session-init.sh"
#         }]
#       }]
#     }
#   }
#
# EXIT CODES
# ──────────
#   0 — Always. This hook must never block session startup.
#
# =============================================================================

set -euo pipefail

# Safety: always exit 0 (hook must never block session startup)
trap 'exit 0' ERR

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/pdlc-state.sh"

if [[ -f "${PDLC_HANDOFF}" ]]; then
  echo "## PDLC Autopilot Session State"
  echo ""
  cat "${PDLC_HANDOFF}"
else
  echo "No active PDLC session. Run pdlc-outer-loop.sh to start."
fi

exit 0
