#!/bin/bash
# hooks/lib/pdlc-state.sh — PDLC state management library
# Sourced by hook scripts: source "$(dirname "$0")/lib/pdlc-state.sh"
#
# Provides helpers for reading/writing HANDOFF.md with flat YAML frontmatter.
# All YAML fields are flat (no nesting). Atomic writes via tmp+mv.

PDLC_STATE_DIR=".pdlc/state"
PDLC_HANDOFF="${PDLC_STATE_DIR}/HANDOFF.md"
PDLC_MARKER="${PDLC_STATE_DIR}/.compact_marker"

# Ensure state directory exists
pdlc_ensure_state_dir() {
  mkdir -p "${PDLC_STATE_DIR}"
}

# Read a flat YAML frontmatter field from HANDOFF.md
# Usage: pdlc_get_field "phase"  →  returns "ACTOR"
# Returns empty string if file or field does not exist.
pdlc_get_field() {
  local field="$1"
  if [[ ! -f "${PDLC_HANDOFF}" ]]; then
    echo ""
    return 0
  fi
  # Extract frontmatter between first pair of --- delimiters
  # Guard: if no closing --- exists, awk stops at EOF (safe — no bleed into body)
  local frontmatter
  frontmatter=$(awk '
    BEGIN { in_fm=0; count=0 }
    /^---[[:space:]]*$/ { count++; if (count==1) { in_fm=1; next } else { exit } }
    in_fm { print }
  ' "${PDLC_HANDOFF}")
  if [[ -z "${frontmatter}" ]]; then
    echo ""
    return 0
  fi
  # Single awk pass: match exact field name, print value, exit
  echo "${frontmatter}" | awk -F': ' -v key="${field}" '$1 == key { print substr($0, length(key)+3); exit }'
}

# Write HANDOFF.md atomically (write to .tmp, then mv)
# Usage: pdlc_write_handoff "$yaml_content" "$markdown_body"
# $yaml_content should be the raw YAML lines (without --- delimiters).
# $markdown_body is the markdown content after the frontmatter.
pdlc_write_handoff() {
  local yaml_content="$1"
  local markdown_body="${2:-}"
  pdlc_ensure_state_dir
  local tmp="${PDLC_HANDOFF}.tmp"
  {
    echo "---"
    echo "${yaml_content}"
    echo "---"
    if [[ -n "${markdown_body}" ]]; then
      echo ""
      echo "${markdown_body}"
    fi
  } > "${tmp}"
  mv "${tmp}" "${PDLC_HANDOFF}"
}

# Update a single field in existing HANDOFF.md (atomic)
# If the field exists, replace its value. If not, append it to frontmatter.
# If HANDOFF.md does not exist, create it with just that field.
# Usage: pdlc_set_field "phase" "DONE"
pdlc_set_field() {
  local field="$1"
  local value="$2"
  if [[ ! -f "${PDLC_HANDOFF}" ]]; then
    pdlc_write_handoff "${field}: ${value}" ""
    return 0
  fi

  # Guard: if file has fewer than 2 frontmatter delimiters or first line isn't ---, treat as malformed — recreate with field + existing content as body
  local fm_delims
  fm_delims=$(grep -c '^---[[:space:]]*$' "${PDLC_HANDOFF}" 2>/dev/null || true)
  if [[ "${fm_delims}" -lt 2 ]] || ! head -n1 "${PDLC_HANDOFF}" | grep -q '^---[[:space:]]*$'; then
    local existing_content
    existing_content=$(cat "${PDLC_HANDOFF}")
    pdlc_write_handoff "${field}: ${value}" "${existing_content}"
    return 0
  fi

  local tmp="${PDLC_HANDOFF}.tmp"
  local found=0
  local in_fm=0
  local fm_count=0
  local past_fm=0
  # Process line by line, preserving everything
  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${past_fm}" -eq 1 ]]; then
      echo "${line}"
      continue
    fi
    if [[ "${line}" =~ ^---[[:space:]]*$ ]]; then
      fm_count=$((fm_count + 1))
      if [[ ${fm_count} -eq 1 ]]; then
        in_fm=1
        echo "${line}"
        continue
      else
        # Closing delimiter — insert field if not found yet
        if [[ ${found} -eq 0 ]]; then
          echo "${field}: ${value}"
        fi
        echo "${line}"
        in_fm=0
        past_fm=1
        continue
      fi
    fi
    # Only match within frontmatter; exact field name match
    if [[ ${in_fm} -eq 1 ]] && [[ "${line%%:*}" == "${field}" ]]; then
      echo "${field}: ${value}"
      found=1
    else
      echo "${line}"
    fi
  done < "${PDLC_HANDOFF}" > "${tmp}"

  # Guard: if only opening --- found (no closing), the tmp file may be incomplete
  # In this case, still mv — the field was either found and replaced or appended
  mv "${tmp}" "${PDLC_HANDOFF}"
}

# Read a field from JSON on stdin via jq
# Usage: local prompt=$(pdlc_read_json_field "tool_input.prompt" <<< "$stdin_json")
pdlc_read_json_field() {
  local field_path="$1"
  jq -r ".${field_path} // empty"
}

# Touch compact marker
pdlc_touch_marker() {
  pdlc_ensure_state_dir
  touch "${PDLC_MARKER}"
}

# Check if marker exists (returns 0 if exists, 1 otherwise)
pdlc_marker_exists() {
  [[ -f "${PDLC_MARKER}" ]]
}

# Delete marker
pdlc_delete_marker() {
  rm -f "${PDLC_MARKER}"
}
