#!/bin/bash
# hooks/lib/pdlc-freshness.sh — Context freshness checks
#
# Read-only Observer: detects stale spec artifacts, expired session state,
# and spec-code drift. Never blocks, never writes state.
#
# Sourced by other scripts: source "$(dirname "$0")/lib/pdlc-freshness.sh"
# Depends on: pdlc-state.sh (pdlc_get_mtime, pdlc_get_field)

set -euo pipefail

# Source state library if not already loaded
if ! declare -f pdlc_get_mtime &>/dev/null; then
  source "$(dirname "${BASH_SOURCE[0]}")/pdlc-state.sh"
fi

# Default freshness threshold in days
PDLC_FRESHNESS_THRESHOLD_DAYS="${PDLC_FRESHNESS_THRESHOLD_DAYS:-7}"

# Source directories to compare against for drift detection
PDLC_SOURCE_DIRS=(hooks/ src/ tests/)

# Check spec-code drift: are spec artifacts older than source files?
# Usage: pdlc_freshness_check_drift <spec_dir>
# Output: "DRIFT:artifact:delta_days" lines or "FRESH" if no drift
# Returns: 0 always (Observer — never fails)
pdlc_freshness_check_drift() {
  local spec_dir="$1"

  if [[ ! -d "$spec_dir" ]]; then
    echo "INFO:No spec directory found"
    return 0
  fi

  # Find newest spec artifact mtime
  local spec_newest=0
  local artifact
  for artifact in spec.md plan.md tasks.md; do
    local filepath="${spec_dir}/${artifact}"
    if [[ -f "$filepath" ]]; then
      local mtime
      mtime=$(pdlc_get_mtime "$filepath")
      if [[ -n "$mtime" ]] && [[ "$mtime" -gt "$spec_newest" ]]; then
        spec_newest="$mtime"
      fi
    fi
  done

  if [[ "$spec_newest" -eq 0 ]]; then
    echo "INFO:No spec artifacts found"
    return 0
  fi

  # Find newest source file mtime across source directories
  local source_newest=0
  local src_dir
  for src_dir in "${PDLC_SOURCE_DIRS[@]}"; do
    if [[ -d "$src_dir" ]]; then
      local file
      for file in "$src_dir"*; do
        [[ -f "$file" ]] || continue
        local mtime
        mtime=$(pdlc_get_mtime "$file")
        if [[ -n "$mtime" ]] && [[ "$mtime" -gt "$source_newest" ]]; then
          source_newest="$mtime"
        fi
      done
    fi
  done

  if [[ "$source_newest" -eq 0 ]]; then
    echo "FRESH"
    return 0
  fi

  # Compare: if source is newer than spec, there's drift
  if [[ "$source_newest" -gt "$spec_newest" ]]; then
    local delta_seconds=$((source_newest - spec_newest))
    local delta_days=$((delta_seconds / 86400))
    echo "DRIFT:spec_artifacts:${delta_days}_days_behind"
  else
    echo "FRESH"
  fi

  return 0
}

# Check session staleness: is HANDOFF.md older than threshold?
# Usage: pdlc_freshness_check_session
# Output: "SESSION:FRESH:age_days" or "SESSION:STALE:age_days:threshold"
# Returns: 0 always (Observer — never fails)
pdlc_freshness_check_session() {
  local threshold="${PDLC_FRESHNESS_THRESHOLD_DAYS}"

  if [[ ! -f "${PDLC_HANDOFF}" ]]; then
    echo "SESSION:NONE:no_handoff"
    return 0
  fi

  local mtime
  mtime=$(pdlc_get_mtime "${PDLC_HANDOFF}")
  if [[ -z "$mtime" ]]; then
    echo "SESSION:NONE:cannot_read_mtime"
    return 0
  fi

  local now
  now=$(date +%s)
  local age_seconds=$((now - mtime))
  local age_days=$((age_seconds / 86400))
  local threshold_seconds=$((threshold * 86400))

  if [[ "$age_seconds" -gt "$threshold_seconds" ]]; then
    echo "SESSION:STALE:${age_days}:${threshold}"
  else
    echo "SESSION:FRESH:${age_days}"
  fi

  return 0
}

# Produce consolidated freshness report
# Usage: pdlc_freshness_report <spec_dir>
# Output: multi-line report with per-artifact ages and overall status
# Returns: 0 always (Observer — never fails)
pdlc_freshness_report() {
  local spec_dir="$1"
  local overall="FRESH"
  local now
  now=$(date +%s)

  echo "=== Context Freshness ==="

  # Per-artifact ages
  local artifact
  for artifact in spec.md plan.md tasks.md; do
    local filepath="${spec_dir}/${artifact}"
    if [[ -f "$filepath" ]]; then
      local mtime age_days
      mtime=$(pdlc_get_mtime "$filepath")
      if [[ -n "$mtime" ]]; then
        age_days=$(( (now - mtime) / 86400 ))
        local status="FRESH"
        if [[ "$age_days" -gt "${PDLC_FRESHNESS_THRESHOLD_DAYS}" ]]; then
          status="STALE"
          overall="STALE"
        fi
        echo "${artifact}: ${age_days} days old [${status}]"
      fi
    else
      echo "${artifact}: not found"
    fi
  done

  # Session check
  local session_result
  session_result=$(pdlc_freshness_check_session)
  echo "HANDOFF.md: ${session_result}"
  if echo "$session_result" | grep -q "STALE"; then
    overall="STALE"
  fi

  # Drift check
  local drift_result
  drift_result=$(pdlc_freshness_check_drift "$spec_dir")
  echo "Drift: ${drift_result}"
  if echo "$drift_result" | grep -q "DRIFT"; then
    overall="STALE"
  fi

  echo "Overall: ${overall}"
  return 0
}
