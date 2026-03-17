#!/bin/bash
# hooks/lib/pdlc-director.sh — PDLC Director decision engine
#
# The Director is the LLM-driven reasoning layer that decides:
#   - What lifecycle phase to execute next
#   - How to dispatch (same-session or spawn)
#   - How to respond to Critic feedback (accept/retry/escalate)
#
# The shell script is the deterministic skeleton. The Director
# is the LLM judgment step within each outer loop iteration.
#
# Sourced by pdlc-outer-loop.sh:
#   source "$(dirname "$0")/lib/pdlc-director.sh"
#
# Depends on: pdlc-state.sh, pdlc-lifecycle.sh

set -euo pipefail

# Source dependencies if not already loaded
DIRECTOR_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -f pdlc_lifecycle_infer &>/dev/null; then
  source "${DIRECTOR_LIB_DIR}/pdlc-lifecycle.sh"
fi
if ! declare -f pdlc_freshness_report &>/dev/null; then
  source "${DIRECTOR_LIB_DIR}/pdlc-freshness.sh"
fi

# Valid Director actions
PDLC_DIRECTOR_ACTIONS=(specify plan generate-tasks implement review archive)

# Valid dispatch modes
PDLC_DIRECTOR_MODES=(same-session spawn)

# Default retry limit
PDLC_MAX_RETRIES="${PDLC_MAX_RETRIES:-3}"

# Validate a Director action
# Returns 0 if valid, 1 if invalid
pdlc_director_validate_action() {
  local action="$1"
  local a
  for a in "${PDLC_DIRECTOR_ACTIONS[@]}"; do
    if [[ "$a" == "$action" ]]; then
      return 0
    fi
  done
  return 1
}

# Build the Director prompt for the LLM reasoning step
# Usage: pdlc_director_build_prompt <spec_dir> <inferred_state>
# Output: the constructed prompt string to stdout
pdlc_director_build_prompt() {
  local spec_dir="$1"
  local inferred_state="$2"

  # Gather artifact summaries
  local task_total task_done task_pending
  local tasks_file="${spec_dir}/tasks.md"
  task_total=$(pdlc_count_tasks "$tasks_file" "total")
  task_done=$(pdlc_count_tasks "$tasks_file" "done")
  task_pending=$(pdlc_count_tasks "$tasks_file" "pending")

  # Gather budget info from HANDOFF.md
  local total_cost session_count max_cost
  total_cost=$(pdlc_get_field "total_cost_usd")
  total_cost="${total_cost:-0.00}"
  session_count=$(pdlc_get_field "session_count")
  session_count="${session_count:-0}"
  max_cost="${PDLC_MAX_COST_USD:-50.00}"

  # Gather retry context
  local retry_count
  retry_count=$(pdlc_get_field "retry_count")
  retry_count="${retry_count:-0}"

  cat <<PROMPT
You are the PDLC Director. Assess the current state and decide what to do next.

## Current State
- Lifecycle state: ${inferred_state}
- Spec directory: ${spec_dir}
- Tasks: ${task_total} total, ${task_done} done, ${task_pending} pending
- Budget: \$${total_cost} spent of \$${max_cost} max (${session_count} sessions)
- Retry count: ${retry_count}

## Context Freshness
$(pdlc_freshness_report "$spec_dir" 2>/dev/null || echo "Freshness check unavailable")

## Dispatch Heuristics (guidance, not rules)
- Phases before Implementing (specify, plan, generate-tasks) are typically same-session
- Implementation with multiple user stories typically benefits from spawn (one session per story)
- If remaining budget is low (<20%), prefer same-session to avoid spawn overhead
- If retry_count > 0, include context about what failed and why

## Required Output
Respond with ONLY a JSON object (no markdown fencing, no explanation):
{"action": "<specify|plan|generate-tasks|implement|review|archive>", "mode": "<same-session|spawn>", "rationale": "<brief explanation>", "actor_prompt": "<specific instructions for the Actor>"}
PROMPT
}

# Parse the Director's LLM response into structured fields
# Usage: pdlc_director_parse_response <raw_output>
# Output: parsed fields as "action|mode|rationale|actor_prompt"
# Falls back to conservative defaults on parse failure
pdlc_director_parse_response() {
  local raw_output="$1"

  # Try to extract JSON from the response
  local action mode rationale actor_prompt

  if [[ -n "$raw_output" ]] && command -v jq &>/dev/null; then
    # Try parsing as JSON directly — single jq call
    # Use @base64 encoding to safely handle embedded newlines in rationale/actor_prompt
    local action_b64 mode_b64 rationale_b64 actor_prompt_b64
    action_b64=$(echo "$raw_output" | jq -r '(.action // "") | @base64' 2>/dev/null) || true
    mode_b64=$(echo "$raw_output" | jq -r '(.mode // "") | @base64' 2>/dev/null) || true
    rationale_b64=$(echo "$raw_output" | jq -r '(.rationale // "") | @base64' 2>/dev/null) || true
    actor_prompt_b64=$(echo "$raw_output" | jq -r '(.actor_prompt // "") | @base64' 2>/dev/null) || true

    if [[ -n "$action_b64" ]]; then
      action=$(echo "$action_b64" | base64 -d 2>/dev/null) || true
      mode=$(echo "$mode_b64" | base64 -d 2>/dev/null) || true
      rationale=$(echo "$rationale_b64" | base64 -d 2>/dev/null) || true
      actor_prompt=$(echo "$actor_prompt_b64" | base64 -d 2>/dev/null) || true
    fi

    # If direct parse failed, try extracting JSON from within text
    if [[ -z "$action" ]]; then
      local json_block
      json_block=$(echo "$raw_output" | grep -o '{[^}]*}' | head -1) || true
      if [[ -n "$json_block" ]]; then
        action_b64=$(echo "$json_block" | jq -r '(.action // "") | @base64' 2>/dev/null) || true
        mode_b64=$(echo "$json_block" | jq -r '(.mode // "") | @base64' 2>/dev/null) || true
        rationale_b64=$(echo "$json_block" | jq -r '(.rationale // "") | @base64' 2>/dev/null) || true
        actor_prompt_b64=$(echo "$json_block" | jq -r '(.actor_prompt // "") | @base64' 2>/dev/null) || true

        if [[ -n "$action_b64" ]]; then
          action=$(echo "$action_b64" | base64 -d 2>/dev/null) || true
          mode=$(echo "$mode_b64" | base64 -d 2>/dev/null) || true
          rationale=$(echo "$rationale_b64" | base64 -d 2>/dev/null) || true
          actor_prompt=$(echo "$actor_prompt_b64" | base64 -d 2>/dev/null) || true
        fi
      fi
    fi
  fi

  # Validate and apply defaults
  if [[ -z "$action" ]] || ! pdlc_director_validate_action "$action"; then
    action="implement"
  fi
  if [[ "$mode" != "same-session" && "$mode" != "spawn" ]]; then
    mode="same-session"
  fi
  if [[ -z "$rationale" ]]; then
    rationale="Fallback: could not parse Director response"
  fi
  if [[ -z "$actor_prompt" ]]; then
    actor_prompt="Read HANDOFF.md and execute the next batch of work."
  fi

  printf '%s\x1e%s\x1e%s\x1e%s' "$action" "$mode" "$rationale" "$actor_prompt"
}

# Make a Director decision (build prompt + deterministic fallback)
# In production, this calls claude -p with the Director prompt.
# For unit testing, it uses a deterministic mapping from state to action.
# Usage: pdlc_director_decide <spec_dir> <inferred_state>
# Output: parsed decision as "action<RS>mode<RS>rationale<RS>actor_prompt" (RS = \x1e)
pdlc_director_decide() {
  local spec_dir="$1"
  local inferred_state="$2"

  # If claude CLI is available and not in test mode, use LLM
  if [[ "${PDLC_DIRECTOR_TEST_MODE:-0}" != "1" ]] && command -v claude &>/dev/null; then
    local prompt
    prompt=$(pdlc_director_build_prompt "$spec_dir" "$inferred_state")
    local raw_response
    raw_response=$(claude -p "$prompt" --model claude-haiku-4-5-20251001 --max-turns 1 2>/dev/null) || true
    if [[ -n "$raw_response" ]]; then
      pdlc_director_parse_response "$raw_response"
      return 0
    fi
  fi

  # Deterministic fallback: map state to sensible defaults
  case "$inferred_state" in
    Draft)
      printf '%s\x1e%s\x1e%s\x1e%s' "specify" "same-session" "State is Draft — spec needs completion" "Complete the feature specification in ${spec_dir}/spec.md. Fill all template placeholders and define requirements."
      ;;
    Specified)
      printf '%s\x1e%s\x1e%s\x1e%s' "plan" "same-session" "State is Specified — planning needed" "Create implementation plan in ${spec_dir}/plan.md based on the completed spec."
      ;;
    Planned)
      printf '%s\x1e%s\x1e%s\x1e%s' "generate-tasks" "same-session" "State is Planned — tasks needed" "Generate tasks.md from the plan and spec in ${spec_dir}."
      ;;
    Tasked|Implementing)
      printf '%s\x1e%s\x1e%s\x1e%s' "implement" "spawn" "State is ${inferred_state} — implementation work" "Implement the next incomplete user story from ${spec_dir}/tasks.md. Follow TDD: write tests first, then implement."
      ;;
    Complete)
      printf '%s\x1e%s\x1e%s\x1e%s' "review" "same-session" "State is Complete — review needed" "Review all completed work in ${spec_dir}. Run full test suite and verify quality."
      ;;
    Archived)
      printf '%s\x1e%s\x1e%s\x1e%s' "archive" "same-session" "State is Archived — no action needed" "Feature is archived. No further action required."
      ;;
    *)
      printf '%s\x1e%s\x1e%s\x1e%s' "implement" "same-session" "Unknown state fallback" "Read HANDOFF.md and execute the next batch of work."
      ;;
  esac
}

# Evaluate Critic feedback and decide accept/retry/escalate
# Usage: pdlc_director_evaluate_critics <batch_num> <retry_count>
# Output: "accept", "retry", or "escalate"
pdlc_director_evaluate_critics() {
  local batch_num="$1"
  local retry_count="${2:-0}"
  local max_retries="${PDLC_MAX_RETRIES:-3}"

  # Read critic results from HANDOFF.md
  local advocate_status skeptic_status
  advocate_status=$(pdlc_get_field "batch_${batch_num}_advocate")
  skeptic_status=$(pdlc_get_field "batch_${batch_num}_skeptic")

  # If no critic results yet (first batch or critics haven't run), accept
  if [[ -z "$advocate_status" && -z "$skeptic_status" ]]; then
    echo "accept"
    return 0
  fi

  # Both PASS or PASS_WARN → accept
  if [[ "$advocate_status" =~ ^PASS ]] && [[ "$skeptic_status" =~ ^PASS ]]; then
    echo "accept"
    return 0
  fi

  # At least one FAIL — check retry limit
  if [[ "$retry_count" -ge "$max_retries" ]]; then
    echo "escalate"
    return 0
  fi

  # Under retry limit — retry
  echo "retry"
  return 0
}
