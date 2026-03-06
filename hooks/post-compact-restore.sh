#!/bin/bash
# =============================================================================
# post-compact-restore.sh — PDLC UserPromptSubmit State Restore Hook
# =============================================================================
#
# Detects whether a compaction just occurred (via .compact_marker) and, if so,
# injects the saved HANDOFF.md contents as additional context for the next
# Claude Code prompt.
#
# HOW IT WORKS
# ─────────────
# 1. Check if .compact_marker exists.
# 2. If YES: read HANDOFF.md, output to stdout (injected as additionalContext
#    by the UserPromptSubmit hook system), then delete the marker.
# 3. If NO: exit immediately with no output (no-op — this hook fires on
#    EVERY user prompt submission, so the fast path must be near-instant).
# 4. Must complete in under 10 seconds.
#
# INSTALLATION
# ─────────────
# Add to .claude/settings.json under "hooks.UserPromptSubmit":
#
#   {
#     "hooks": {
#       "UserPromptSubmit": [{
#         "hooks": [{
#           "type": "command",
#           "command": "bash /path/to/post-compact-restore.sh"
#         }]
#       }]
#     }
#   }
#
# NOTE
# ─────
# stdout IS used — it is injected as additional context into the prompt.
# The fast path (no marker) produces no output and exits immediately.
#
# EXIT CODES
# ──────────
#   0 — Always (hook must never block prompt submission)
#
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/pdlc-state.sh"

# Fast path: no marker = no compaction happened
if ! pdlc_marker_exists; then
  exit 0
fi

# Compaction recovery: inject HANDOFF.md state
if [[ -f "${PDLC_HANDOFF}" ]]; then
  echo "## PDLC State Restored After Compaction"
  echo ""
  cat "${PDLC_HANDOFF}"
fi

# Clean up marker
pdlc_delete_marker

exit 0
