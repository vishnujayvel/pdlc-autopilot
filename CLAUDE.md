# CLAUDE.md — PDLC Autopilot

## Project Overview

PDLC Autopilot is a CLI skill for Claude Code that orchestrates autonomous product development lifecycles using a Director/Actor/Critic pattern.

## Code Conventions

### Shell Scripts (hooks/)
- All hook scripts MUST exit 0, even on error. Use `trap 'exit 0' ERR` (or `trap '...; exit 0' ERR` if output is needed).
- Use `set -euo pipefail` at the top of every script.
- Atomic writes: write to `.tmp` then `mv` to final path. Never write directly to state files.
- HANDOFF.md uses flat YAML frontmatter (no nested objects). Parse with awk, not yq.
- `pdlc_get_field` / `pdlc_set_field` in `hooks/lib/pdlc-state.sh` are the canonical state accessors. Do not reimplement frontmatter parsing inline.
- Use `substr($0, length(key)+3)` in awk to preserve values containing `: `. Never use just `$2` with `-F': '` for value extraction.
- Prefer single-word values in HANDOFF.md fields (e.g., `PASS_WARN` not `PASS WITH WARNINGS`) to avoid word-splitting issues.
- Environment variable names: `PDLC_` prefix for all configurable vars.

### Process Enforcement
- **SpecGate** (`hooks/spec-gate.sh`): Blocks spec generation via Task tool. Specs must use Kiro skills.
- **CriticGate** (`hooks/critic-gate.sh`): Blocks Actor dispatch without prior critic review.
- Deny messages use `<error-recovery>` XML framing for LLM self-correction.
- The `"matcher": "Task"` in settings.json ensures gate hooks only fire for Task tool calls.

### Testing
- Framework: BATS-core (`bats tests/`)
- Live e2e tests: `PDLC_LIVE_TESTS=1 bats tests/e2e/hooks-live.bats` (costs API credits)
- Stub tests use `tests/stubs/claude` — no API calls needed.
- Test helpers in `tests/helpers/common-setup.bash` — use `create_handoff`, `run_hook` for consistency.

### State Management
- `.pdlc/state/` is gitignored (runtime state, not version-controlled).
- Only `.pdlc/state/.gitkeep` is tracked.
- HANDOFF.md is the single source of truth for cross-session state.

### Git
- Hook scripts should never block Claude's git operations.
- The outer loop auto-commits to specific directories: `hooks/`, `.pdlc/`, `src/`, `tests/`.
- `.pdlc/state/*` is gitignored so progress detection (`git diff --stat HEAD`) correctly ignores bookkeeping files.

### Documentation
- Keep header comments in sync with actual behavior (env vars, defaults, timeouts).
- When listing default values (e.g., pattern lists), list ALL defaults, not a subset.

## Do NOT
- Use `yq` — the project has no yq dependency.
- Use `grep` pipelines for YAML parsing — use awk.
- Add nested YAML to HANDOFF.md — keep it flat.
- Skip ERR traps in hook scripts that document "always exit 0".
