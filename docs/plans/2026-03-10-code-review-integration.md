# Code Review Integration Plan

## Decision

Use Anthropic's `/code-review` plugin as a **PR-time quality gate**, complementing the existing `/simplify` skill which runs mid-implementation for inline cleanup.

## Workflow

```
Implementation Loop:
  Write code → /simplify (inline fixes) → Write more code → /simplify → ...

PR Boundary:
  Push branch → Create PR → /code-review (post findings) → Address findings → Merge
```

| Tool | When | What It Does | Edits Code? |
|------|------|-------------|-------------|
| `/simplify` | Mid-implementation | 3-agent review (reuse, quality, efficiency), fixes inline | Yes |
| `/code-review` | After PR created | Multi-agent review, posts findings as PR comment | No |

## Setup

### Plugin Installation

The `code-review` plugin from `claude-plugins-official` marketplace is installed at user scope. It provides the `/code-review` slash command.

To run:
```bash
# Terminal-only output (no GitHub comment):
/code-review

# Post findings as PR comment:
/code-review --comment
```

### CLAUDE.md Created

`CLAUDE.md` at project root provides the compliance baseline for the CLAUDE.md review agents. Key sections:
- Shell script conventions (ERR traps, atomic writes, awk over grep)
- SpecGate/CriticGate enforcement rules
- Testing conventions (BATS, stubs, live tests)
- State management rules (flat YAML, gitignored state)

### REVIEW.md (Future)

For review-specific guidance that shouldn't affect normal Claude Code sessions, create `REVIEW.md` at project root. Candidates:
- "Flag any hook script missing an ERR trap"
- "Flag any inline frontmatter awk that doesn't use pdlc_get_field"
- "Flag any HANDOFF.md field value that contains spaces"

## Trial Run Results (PR #52)

Ran 4 parallel review agents against PR #52 (Session Hooks):

| Agent | Model | Findings | Passed 80+ |
|-------|-------|----------|------------|
| CLAUDE.md compliance | - | No CLAUDE.md existed | 0 |
| Bug scan | Sonnet | 2 bugs (bc dep, awk $2 truncation) | 1 |
| Git history context | Opus | 3 issues (read -r regression, no-progress reset, stale hook) | 0 (all 60-75) |
| Code comments compliance | Sonnet | 5 issues (stale docs, missing ERR traps) | 2 |

**3 findings posted** at 80+ confidence. **5 additional findings** below threshold but still worth fixing.

All 8 issues were fixed:
1. Removed undocumented `PDLC_STATE_FILE` env var from docs
2. Updated spec-gate.sh header to list all 16 patterns
3. Added `bc` dependency check to outer loop
4. Reverted `read -r ADVOCATE SKEPTIC` to two separate awk calls (space-split regression)
5. Added ERR traps to post-compact-restore.sh, session-init.sh, pre-compact-save.sh
6. Fixed stale hook comment referencing old env var name
7. Added missing no-progress counter reset on successful progress
8. Removed stale outer-loop doc referencing deprecated `PDLC_STATE_FILE`

## Cost Analysis

| Step | Agents | Estimated Cost |
|------|--------|---------------|
| Eligibility check | 1 Haiku | ~$0.01 |
| CLAUDE.md discovery | 1 Haiku | ~$0.01 |
| PR summary | 1 Haiku | ~$0.02 |
| Review agents | 5 Sonnet (or 2 Sonnet + 2 Opus) | ~$2-8 |
| Validation scoring | N Haiku (1 per finding) | ~$0.01-0.10 |
| **Total** | | **~$2-10 per review** |

For our typical PR sizes (500-2000 lines), expect ~$3-5 per review.

## Comparison: Local Plugin vs Managed Service

| Feature | Local Plugin (`/code-review`) | Managed Service (GitHub App) |
|---------|-------------------------------|------------------------------|
| Trigger | Manual slash command | Auto on PR open/push |
| Output | Terminal or PR comment | Inline PR comments |
| Cost | Your API credits | Teams/Enterprise subscription |
| Customization | Edit command .md file | CLAUDE.md + REVIEW.md |
| Availability | Any Claude Code user | Teams/Enterprise only |

**Recommendation:** Use the local plugin for now. Upgrade to managed service if/when the project moves to a team plan.
