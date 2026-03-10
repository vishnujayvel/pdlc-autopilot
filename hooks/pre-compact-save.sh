#!/bin/bash
# =============================================================================
# pre-compact-save.sh — PDLC PreCompact State Preservation Hook
# =============================================================================
#
# Preserves PDLC state before Claude Code compacts the conversation context.
# Touches a .compact_marker so the post-compact-restore hook knows to inject
# the saved state back into the next prompt.
#
# HOW IT WORKS
# ─────────────
# 1. If HANDOFF.md already exists, it is assumed current — just touch the
#    .compact_marker so the restore hook fires after compaction.
# 2. If HANDOFF.md does NOT exist, create a minimal stub with phase: UNKNOWN
#    and partial: true, then touch the marker.
# 3. Must complete in under 10 seconds.
#
# INSTALLATION
# ─────────────
# Add to .claude/settings.json under "hooks.PreCompact":
#
#   {
#     "hooks": {
#       "PreCompact": [{
#         "hooks": [{
#           "type": "command",
#           "command": "bash /path/to/pre-compact-save.sh"
#         }]
#       }]
#     }
#   }
#
# NOTE
# ─────
# stdout is IGNORED by PreCompact hooks — only side effects (file writes)
# matter. All diagnostic output goes to stderr.
#
# EXIT CODES
# ──────────
#   0 — Always (hook must never block compaction)
#
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/pdlc-state.sh"

pdlc_ensure_state_dir

if [[ ! -f "${PDLC_HANDOFF}" ]]; then
  # No state file — create minimal stub
  pdlc_write_handoff "phase: UNKNOWN
partial: true" "## Compaction Recovery

State was not available before compaction. Read progress.md in the spec directory for context."
fi

# Mark for post-compact restore (whether HANDOFF.md existed or was just created)
pdlc_touch_marker

exit 0
