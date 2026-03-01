# Session Persistence & Compaction Survival

**Problem:** Long SDLC sessions often hit conversation compaction. Context is lost — which batches completed, critic results, test counts, files created all vanish.

**Solution:** TWO persistent files in the spec directory survive compaction:

1. **`validation-criteria.md`** — What are the rules? (tenets, phase checklists)
2. **`progress.md`** — Where are we? (batch status, critic results, test counts, next steps)

## The Pattern

```
┌────────────────────────────────────────────────────────────────┐
│                 CONVERSATION COMPACTION SURVIVAL               │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│   BEFORE COMPACTION:                                           │
│   ┌──────────────────┐                                         │
│   │ Director Memory  │ ← "I know the tenets, I know the rules" │
│   │ validation rules │    "Batch D complete, 282 tests"         │
│   │ tenets T0-T15    │    "SKEPTIC found T1 issue, fixed"       │
│   └──────────────────┘                                         │
│                                                                │
│   AFTER COMPACTION:                                            │
│   ┌──────────────────┐                                         │
│   │ Director Memory  │ ← "Context lost! What were the rules?"  │
│   │ (empty)          │    "Where did we stop?"                  │
│   └──────────────────┘                                         │
│            │                                                   │
│            ▼                                                   │
│   ┌──────────────────────────────────────┐                     │
│   │ {project}/.claude/product-context.md │ ← STRATEGY PERSISTS! │
│   │ - Core thesis & problem              │                     │
│   │ - Audience tier                      │                     │
│   │ - MVP scope & hydration roadmap      │                     │
│   │ - Kill criteria & principles         │                     │
│   └──────────────────────────────────────┘                     │
│   ┌──────────────────────────────────────┐                     │
│   │ {spec_dir}/validation-criteria.md    │ ← RULES PERSIST!    │
│   │ - Phase validation checklists        │                     │
│   │ - Tenet compliance (T0-T15)          │                     │
│   │ - Validation Agent Prompt            │                     │
│   │ - Project-specific rules             │                     │
│   └──────────────────────────────────────┘                     │
│   ┌──────────────────────────────────────┐                     │
│   │ {spec_dir}/progress.md              │ ← PROGRESS PERSISTS! │
│   │ - Batch status table                 │                     │
│   │ - Critic results per batch           │                     │
│   │ - Test count after each batch        │                     │
│   │ - Fixes applied                      │                     │
│   │ - Files created/modified             │                     │
│   │ - Next steps (what to do next)       │                     │
│   │ - Retrospective state                │                     │
│   └──────────────────────────────────────┘                     │
│   ┌──────────────────────────────────────┐                     │
│   │ {project}/.claude/decision-log.md   │ ← DECISIONS PERSIST! │
│   │ - Append-only, newest first          │                     │
│   │ - Product Skeptic verdicts           │                     │
│   │ - Retro learnings & scope changes    │                     │
│   │ - Drift resolutions                  │                     │
│   └──────────────────────────────────────┘                     │
│            │                                                   │
│            ▼                                                   │
│   Director re-reads ALL FOUR files → FULL CONTINUITY RESTORED  │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

## progress.md — Execution Checkpoint File (CRITICAL)

**When to write:** After EVERY significant event:
- Batch Actor completes (update batch status + test count)
- Batch Critics complete (update critic results)
- Fix applied (add to fixes section)
- New batch starts (update "Next Steps")

**Where:** `{spec_dir}/progress.md`

**MANDATORY:** The Director MUST update progress.md after each batch and critic pass. This is not optional.

**Template:**
```markdown
# SDLC Progress: [feature-name]

## Execution State
- **Started:** [ISO timestamp]
- **Last checkpoint:** [ISO timestamp]
- **Test count:** [number] passing
- **Phase:** execution
- **Project dir:** [absolute path to project]

## PDLC State
- **Mode:** PDLC v3
- **Tier:** [0 Personal | 1 Community | 2 Enterprise]
- **Product Skeptic verdict:** [APPROVE | SCOPE | KILL_OVERRIDDEN | pending]
- **Scope cuts applied:** [list of FR-* IDs cut, or "none"]
- **P2 (Docs) status:** [skipped | pending | in_progress | complete]
- **P3 (Launch) status:** [skipped | pending | in_progress | complete]

## Batch Plan
| Batch | Tasks | Files |
|-------|-------|-------|
| A | T1+T2 | db.py, config.py |
| B | T3+T14 | rocketmoney.py, bank.py |
| ... | ... | ... |

## Batch Status
| Batch | Status | Tests After | ADVOCATE | SKEPTIC |
|-------|--------|-------------|----------|---------|
| A | DONE+CRITICS | 62 | PASS | PASS |
| B | DONE+CRITICS | 112 | PASS | PASS_WARN |
| C | DONE | 156 | pending | pending |
| D | PENDING | - | - | - |

## Critic Results
### Batch [X] Critics
- **ADVOCATE:** [PASS/FAIL] — [1-line summary]
- **SKEPTIC:** [PASS/FAIL/PASS_WARN] — [1-line summary]
  - [specific findings with file:line]

## Fixes Applied
1. [file:line] — [what was fixed] ([which critic found it])

## Files Created
- src/module/file.py (T1)
- tests/test_file.py (T1)

## Next Steps
1. [Exactly what to do next — be specific]
2. [Then what]
3. [Then what]

## Retrospective State
- **Last retro:** [ISO timestamp | none]
- **Decisions logged this cycle:** [N | 0]
- **Context updates pending:** [yes — what section | no]
- **Lightweight cycle log:** [bug-fix: description | iteration: description | none]
```

## Context Budget Awareness (CRITICAL)

**Problem:** The SDLC loop dispatches many agents. Each agent result floods the context window. After ~6-8 batches, compaction hits.

**Mitigation strategies (Director MUST follow):**

1. **Lean agent result handling:**
   - When an Actor/Critic subagent returns, extract ONLY the summary
   - Do NOT echo full agent output back into the conversation
   - Write detailed results to progress.md instead
   - Main context should only contain: "Batch X complete. Tests: N. See progress.md."

2. **Checkpoint before heavy operations:**
   - BEFORE dispatching actors for a new batch, update progress.md with current state
   - If you're about to dispatch 3+ parallel agents, save state FIRST
   - After critics return, save results to progress.md IMMEDIATELY

3. **Proactive saves:**
   - After every 2 batches, do a full progress.md update
   - If you notice context is getting long (many agent round-trips), save state
   - The cheapest action is writing to progress.md — do it often

4. **Resume efficiency:**
   - On resume after compaction, read progress.md FIRST
   - Skip re-reading completed batch details — trust progress.md
   - Only read the files needed for the NEXT batch

```
PATTERN: Save-Before-Dispatch

BEFORE dispatching any batch:
  1. Update progress.md with current state
  2. Dispatch actors
  3. When actors return → update progress.md
  4. Dispatch critics
  5. When critics return → update progress.md
  6. THEN move to next batch

This way, even if compaction hits MID-BATCH, progress.md has the last known good state.
```

## Creating validation-criteria.md

**When:** During or after requirements phase, BEFORE running SDLC

**Where:** `{spec_dir}/validation-criteria.md`

**Contents:**
1. **Phase Validation Checklists** - What to check after requirements, design, tasks, implementation
2. **Tenet Compliance Checklist** - Project-specific tenets (T0, T1, T2...)
3. **Validation Agent Prompt** - Custom instructions for validators
4. **SDLC Loop Integration** - How validators should use this file

**Template:**
```markdown
# Validation Criteria for [Feature Name]

## Phase Validation

### Requirements Phase
After generating requirements.md, verify:
- [ ] Criterion 1
- [ ] Criterion 2

### Design Phase
After generating design.md, verify:
- [ ] Criterion 1

### Tasks Phase
After generating tasks.md, verify:
- [ ] Each task is tagged with relevant tenet(s)
- [ ] Criterion 2

### Implementation Phase
For each implementation PR/commit, verify:
- [ ] Criterion 1
- [ ] Criterion 2

### Output Format Contracts
For each output-producing function, verify:
- [ ] Output format is explicitly specified (JSON schema or type definition)
- [ ] All possible output values are enumerated (e.g., block/allow/warn, not just "action")
- [ ] Output format matches what consumers actually parse
- [ ] Edge cases define output (error states, empty results, timeouts)

## Tenet Compliance Checklist

### T0: [Tenet Name]
- [ ] Sub-check 1
- [ ] Sub-check 2

### T1: [Tenet Name]
- [ ] Sub-check 1

## Validation Agent Prompt

Use this prompt when running tenet validation:

You are the Tenet Validation Agent for [Feature].

Your task: Validate [ARTIFACT_TYPE] against the tenets above.

Input:
- Artifact to validate: [ARTIFACT_PATH]
- Tenets: See "Tenet Compliance Checklist" above

Process:
1. Read the artifact
2. For each tenet, check compliance
3. Report findings

Output format:
| Tenet | Status | Evidence/Issue |
|-------|--------|----------------|
| T0 | PASS/FAIL/WARN | [specific evidence] |

## SDLC Loop Integration

phase_complete:
  - artifact: requirements.md → Check Requirements Phase section
  - artifact: design.md → Check Design Phase section
  - artifact: tasks.md → Check Tasks Phase section
  - artifact: implementation → Full tenet checklist + Implementation Phase
```

## Why This Works

1. **Files persist** - Even when conversation context is lost, files remain
2. **Single source of truth** - All validators read the SAME file
3. **Project-specific** - Each spec has its own validation rules
4. **Auditable** - You can see exactly what criteria were used
5. **Version controlled** - Changes to criteria are tracked
6. **Product strategy persists** - product-context.md survives compaction, so Product Skeptic verdicts and scope cuts are never lost mid-session
