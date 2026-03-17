#!/bin/bash
# hooks/lib/pdlc-quality.sh — Unified spec quality report
#
# Runs all quality checks (lifecycle, placeholder, cross-reference)
# and produces a consolidated report.
#
# Sourced by other scripts: source "$(dirname "$0")/lib/pdlc-quality.sh"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source all quality check libraries
source "${SCRIPT_DIR}/pdlc-lifecycle.sh"
source "${SCRIPT_DIR}/pdlc-placeholder.sh"
source "${SCRIPT_DIR}/pdlc-xref.sh"

# Run all quality checks and produce unified report
# Usage: pdlc_quality_report <spec_dir>
# Returns: 0 if all pass, 1 if any fail
pdlc_quality_report() {
  local spec_dir="$1"
  local overall=0

  echo "=== Spec Quality Report ==="
  echo "Directory: ${spec_dir}"
  echo ""

  # Section 1: Lifecycle State
  echo "--- Lifecycle State ---"
  local state
  state=$(pdlc_lifecycle_get)
  echo "Current state: ${state}"
  if pdlc_lifecycle_validate "$state"; then
    echo "Status: VALID"
  else
    echo "Status: INVALID"
    overall=1
  fi
  echo ""

  # Section 2: Placeholder Detection
  echo "--- Placeholder Detection ---"
  local placeholder_output
  local placeholder_failed=0
  placeholder_output=$(pdlc_placeholder_check "$spec_dir" 2>&1) || {
    placeholder_failed=1
    overall=1
  }
  if [[ $placeholder_failed -eq 0 ]]; then
    echo "Status: CLEAN"
  else
    echo "$placeholder_output" | grep -v "^Placeholders found:" | grep -v "^No placeholders"
    echo "Status: ISSUES FOUND"
  fi
  echo ""

  # Section 3: Cross-Reference Consistency
  echo "--- Cross-Reference Consistency ---"
  local xref_output
  xref_output=$(pdlc_xref_check "$spec_dir" 2>&1) || {
    overall=1
  }
  if echo "$xref_output" | grep -q "All cross-references resolve"; then
    echo "Status: CLEAN"
  elif echo "$xref_output" | grep -q "skipping"; then
    echo "$xref_output" | grep "skipping"
    echo "Status: SKIPPED"
  else
    echo "$xref_output" | grep -v "^Cross-reference gaps:"
    echo "Status: ISSUES FOUND"
    overall=1
  fi
  echo ""

  # Overall
  echo "=== Overall ==="
  if [[ $overall -eq 0 ]]; then
    echo "Result: PASS"
  else
    echo "Result: FAIL"
  fi

  return $overall
}
