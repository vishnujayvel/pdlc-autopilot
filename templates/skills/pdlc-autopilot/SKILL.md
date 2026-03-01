---
name: pdlc-autopilot
description: |
  THE primary entry point for all SDLC and PDLC work. Use when user mentions: "SDLC", "PDLC",
  "build this feature", "implement the spec", "run the SDLC loop", "go back to SDLC",
  "continue implementation", "product context", "document this feature", "launch prep",
  or any spec-related work (requirements, design, tasks, implementation).

  This skill ORCHESTRATES Kiro skills (kiro:spec-*) as sub-operations, wrapped with product
  phases (P0 product context, P1 product skeptic, P2 docs, P3 demo & packaging).

  ⚠️ DO NOT invoke kiro:spec-* skills directly when user wants SDLC/PDLC workflow!
  Always use this skill as the entry point. It will call Kiro skills internally.

  Triggers:
  - "SDLC" or "PDLC" (any mention)
  - "build this feature end-to-end"
  - "implement the spec"
  - "run the SDLC loop"
  - "product context" or "product skeptic review"
  - "document this feature" or "write docs"
  - "launch prep" or "demo script"
  - "continue where we left off"
  - "go back to the spec"
  - "PDLC bug fix" or "fix this bug using the SDLC process"
  - "iterate on this feature using PDLC"
  - "product retrospective" or "context freshness"
  - When spec.json has "active_workflow": "pdlc-autopilot"

  DO NOT USE FOR day planning (use daily-copilot), practice tracking (use practice-tracker),
  skill evaluation (use eval-runner), skill creation/editing (use writing-skills),
  writing a PRD from scratch (this is SDLC/PDLC, not generic product strategy),
  general product management advice, plain "fix this bug" without PDLC mention,
  or "just refactor this function" (generic dev work without SDLC/PDLC context).
---

# PDLC Autopilot v3.3 (Director/Actor/Critic)

**THE ORCHESTRATOR** - This skill is the single entry point for all SDLC and PDLC work. It wraps the SDLC loop with product phases — product context before specs, docs/demos after implementation.

Efficient autonomous PDLC execution using batched implementation with the Director/Actor/Critic pattern.

**Core principle:** Batch tasks by file → one Actor per batch → one Critic per batch = minimal agent overhead.

## Workflow Router (CLASSIFY FIRST)

**Before any work starts, classify the request into one of three paths:**

| Signal | Path | Details |
|--------|------|---------|
| Bug report + PDLC context ("PDLC bug fix") | **Bug Fix** | @ref/lightweight-paths.md |
| "Iterate", "tweak", "add flag" + PDLC context | **Iteration** | @ref/lightweight-paths.md |
| "Build feature", "implement spec", full SDLC | **Full PDLC** | This file (below) |

```
Classification rules:
  "bug", "fix", "broken", "regression" + PDLC → Bug Fix Path
  "add", "tweak", "iterate", "enhance"  + PDLC → Iteration Path
  "build", "feature", "implement", "spec"       → Full PDLC Path
  Ambiguous                                      → Ask user
```

**ALL paths share:** Context health check → visualization → retrospective + decision log.

## Context Health Check — RUNS ON EVERY INVOCATION

Before ANY path executes, check product context freshness. See @ref/context-health.md for full protocol.

```
1. Read product-context.md
2. Extract <!-- last_reviewed: YYYY-MM-DD -->
3. Compare against tier threshold (T0=90d, T1=30d, T2=14d)
4. IF stale → WARN (non-blocking), flag for retro
5. IF missing comment → treat as stale, suggest adding it
6. Proceed with selected path
```

## Product Context (Phase P0) — MANDATORY

**Every SDLC run goes through the full PDLC flow.** Product context is not optional.

```
IF {project}/.claude/product-context.md DOES NOT EXIST:
  → Phase P0 runs FIRST (asks user tier + targeted questions, generates file)
  → See @ref/product-context-template.md for generation protocol

IF {project}/.claude/product-context.md EXISTS:
  → Load it. Extract tier. Proceed to Phase 0a.
```

**No SDLC work starts without product context.** This prevents building the wrong thing efficiently.

The Product Skeptic (Phase P1) ALWAYS runs during Phase 0b validation. See @ref/product-skeptic.md.

## Workflow Stickiness (CRITICAL)

**Problem solved:** When user says "SDLC" or "go back to the spec", context was lost.

**Solution:** This skill is the ORCHESTRATOR. Kiro skills are building blocks it calls internally.

```
User says "SDLC" → ALWAYS use this skill
User says "go back to spec" → ALWAYS use this skill
User says "implement the feature" → ALWAYS use this skill
```

### Workflow State Protocol

**On skill invocation:**
1. Read spec.json
2. If `active_workflow == "pdlc-autopilot"`: Resume from last known phase (check progress.md)
3. If `active_workflow` missing/different: Set it, start fresh

**State tracking in spec.json:**
```json
{
  "active_workflow": "pdlc-autopilot",
  "sdlc_state": {
    "started_at": "2026-02-04T22:30:00.000Z",
    "current_phase": "execution",
    "last_batch_completed": 2,
    "validation_results": { "requirements": "pass", "design": "pass", "tasks": "pass" },
    "product_skeptic_verdict": "approve",
    "p2_docs": "skipped",
    "p3_launch": "skipped"
  }
}
```

## Quick Start: What To Do When Invoked

**FIRST ACTION (ALWAYS):**

```
1. Check for product-context.md:
   - Read {project}/.claude/product-context.md
   - IF MISSING → Run Phase P0 (see @ref/product-context-template.md)
   - IF EXISTS → Extract tier, load product context. Continue.

2. Locate spec.json:
   - ⚠️ VAULT GUARD: If cwd is the Obsidian vault (obsibrain-vault/):
     → Specs MUST NOT be created here. Ask: "Which ~/workplace/ repo does this spec belong to?"
     → Use the repo path as {project}, NOT the vault path.
     → Example: user says "life-metrics" → {project} = ~/workplace/life-metrics/
   - Check if user provided feature name → use {project}/.claude/specs/{feature}/spec.json
   - Check if in working directory → use .claude/specs/*/spec.json
   - If multiple specs, ask user which one

3. Read spec.json and check active_workflow field:

   IF active_workflow == "pdlc-autopilot":
     → Read {spec_dir}/progress.md (if exists) for EXACT execution state
     → Read {spec_dir}/validation-criteria.md (if exists) for rules
     → RESUME from where progress.md says (NOT from vague memory)

   IF active_workflow MISSING or DIFFERENT:
     → SET active_workflow = "pdlc-autopilot" in spec.json
     → START fresh from Phase 0a (artifact generation)

4. Run context health check (see above)
5. Classify request → select path (Bug Fix / Iteration / Full PDLC)
6. Render phase visualization for selected path (see @ref/phase-viz.md)
7. Announce: "PDLC Autopilot v3.1 active for {feature_name}. Tier: {tier}. Path: {path}. Phase: {current_phase}"
```

## CRITICAL: Autonomous Execution (NO STOPPING)

**⚠️ DO NOT ask "Would you like me to proceed?" between phases!**

This is an AUTONOMOUS loop. The ONLY valid stopping points are:
1. **Validation BOTH FAIL** - Cannot proceed until fixed
2. **Max 2 fix cycles exceeded** - Report to user, stop
3. **All batches complete** - Final report, done

If you find yourself about to ask "Should I proceed?" — STOP. That's the stickiness problem. Just proceed.

**Plan-before-code:** For Full PDLC tasks, the Director MUST complete Phase 0a/0b (artifact generation + validation) before any code is written. Front-load planning — don't rush to implementation.

## Architecture

**Standard Mode (single Actor per batch):**
```
┌─────────────────────────────────────────────────────────────┐
│                    DIRECTOR (Main Claude)                    │
│  - Reads spec ONCE, extracts all context                    │
│  - Groups tasks by file/domain                              │
│  - Dispatches Actors with BATCHED tasks                     │
│  - Dispatches Critics to review batch output                │
└─────────────────────────────────────────────────────────────┘
         │                              │
         ▼                              ▼
┌─────────────────┐           ┌─────────────────┐
│     ACTOR       │           │     CRITIC      │
│  (Implementer)  │           │   (Reviewer)    │
│  - ALL tasks    │           │  - ALL criteria │
│  - Self-review  │           │  - Pass/fail    │
└─────────────────┘           └─────────────────┘
```

**T-Mode (parallel Actor teammates per batch):** See @ref/t-mode-strategies.md

## The Loop

### Full PDLC Path (default for new features)

```
Phase P0: Product Context (MANDATORY — runs if product-context.md missing)
    → Ask user tier → ask targeted questions → write product-context.md
    → See @ref/product-context-template.md

Phase 0a: Auto-generate missing artifacts (invoke Kiro skills)
    → Check requirements.md, design.md, tasks.md
    → If MISSING: invoke kiro:spec-requirements / kiro:spec-design / kiro:spec-tasks
    → Runtime error: output cc-sdd install instructions, STOP

Phase 0b: Dual-Perspective + Product Skeptic Validation
    → Requirements: ADVOCATE + SKEPTIC + Product Skeptic (3 parallel subagents)
    → Product Skeptic: checks alignment with product-context.md (see @ref/product-skeptic.md)
    → Gap Analysis: kiro:validate-gap (informational, non-blocking)
    → Design: kiro:validate-design (GO/NO-GO)
    → Tasks: ADVOCATE + SKEPTIC (parallel subagents)
    → Consensus: all PASS → proceed, Product Skeptic SCOPE → cut + proceed, KILL → block

Phase 0.5: Load validation-criteria.md + Extract Architecture Constraints
    → Single source of truth for "what does valid mean?"
    → ALL validators receive this content in their prompts
    → Survives conversation compaction
    → NEW: Extract ARCH-* constraints from design.md (see below)

Phase 1+: Execute Batches
    → Group tasks by file → batches
    → Per batch: Actor implements → Critics review → fix cycles (max 2)
    → Mark batch complete → next batch

Final: Final Validator (ADVOCATE + SKEPTIC + PDLC compliance + drift check) → Report
    → Drift check compares implementation against product-context.md (see @ref/context-health.md)

Retrospective: 3 questions → decision log + context review
    → See @ref/context-health.md retrospective protocol

Phase P2: Document (opt-in — "document this feature")
    → DevRel Actor generates docs from source code
    → Docs Critic catches hallucinations
    → See @ref/docs-phases.md

Phase P3: Demo & Package (opt-in — "launch prep")
    → Demo Actor creates README, demo scripts, comparison matrix
    → Director validates by running demo
    → See @ref/docs-phases.md
```

### Bug Fix Path (lightweight — ~2 agent calls)

```
B1: Diagnose → B2: Fix → B3: Validate (SKEPTIC only) → B4: Retrospective
See @ref/lightweight-paths.md for full protocol.
```

### Iteration Path (medium — ~4-6 agent calls)

```
I1: Mini-Spec → I2: Execute → I3: Validate (adaptive) → I4: Retrospective
See @ref/lightweight-paths.md for full protocol.
```

**ALL paths end with retrospective + decision log.** See @ref/context-health.md.

### Validation Subagent Matrix

| Step | Validator | Subagents | Blocks Execution? |
|------|-----------|-----------|-------------------|
| Requirements | Requirements + Product Skeptic | 3 (ADVOCATE + SKEPTIC + Product Skeptic) | Yes if BOTH FAIL or Product Skeptic KILL |
| Gap Analysis | kiro:validate-gap | 1 (informational) | Warnings only |
| Design | kiro:validate-design | 1 (Kiro built-in) | Yes if NO-GO |
| Tasks | Tasks Validator | 2 (ADVOCATE + SKEPTIC) | Yes if BOTH FAIL |
| Per-Batch | Critic | 2 (ADVOCATE + SKEPTIC) | Yes if BOTH FAIL |
| Final | Final Validator | 2 (ADVOCATE + SKEPTIC + PDLC check) | Reports gaps |
| P2 Docs | Docs Critic | 1 (hallucination check) | Opt-in only |

## Director Protocol

### Step 0: Auto-Generate & Validate Spec

**CRITICAL: This skill AUTO-GENERATES missing artifacts. Do NOT ask user to run Kiro skills manually.**

```
1. Read spec.json → get spec_dir and feature_name
2. Update spec.json: active_workflow = "pdlc-autopilot"
3. Check for required files and AUTO-GENERATE if missing:
   - requirements.md MISSING → Skill tool: kiro:spec-requirements
   - design.md MISSING → Skill tool: kiro:spec-design -y
   - tasks.md MISSING → Skill tool: kiro:spec-tasks -y
4. All artifacts exist → Phase 0b (Validation)
```

**Runtime Error Handling:** If Kiro skill fails:
```
⚠️ Kiro commands not found. SDLC Autopilot requires cc-sdd to generate specs.
Run this in your project directory:  npx cc-sdd@latest --claude
```

### Step 1: Read & Parse Spec
```
1. Read requirements.md, design.md, tasks.md
2. Read validation-criteria.md (if exists)
3. Extract: FR-* requirements, acceptance criteria, task→FR-* mapping, file paths, tenets
4. Store in memory (do NOT re-read during session)
5. Extract Architecture Constraints from design.md (Phase 0.5):
   a. Scan design.md for explicit architectural patterns, contracts, and invariants
      - Look for: "X must be Y", "X are stateless", "X should never Y", layer boundaries,
        dependency direction rules, state ownership rules, error handling strategies
   b. Formulate each as an ARCH-* constraint:
      - ARCH-1: [short name] — [rule from design doc with file:section reference]
      - Example: "ARCH-1: Stateless producers — Feed producers must not hold state in closures;
        all inter-feed state flows through cache bus (design.md §Feed Architecture)"
   c. Also scan: project CLAUDE.md, product-context.md (architecture principles section)
   d. Write extracted constraints to validation-criteria.md under:
      ## Architecture Constraints (extracted from design.md)
      - ARCH-1: ...
      - ARCH-2: ...
   e. If no design.md exists or no patterns found → skip (no constraints = no checks)
```

### Step 2: Create Batches
```
1. For each task, identify primary file(s)
2. Group tasks by file
3. If batch > 5 tasks, split by phase
4. Mark batches that can run in parallel
```

### Step 2.5: T-Mode Strategy Selection (if T-Mode active)

See @ref/t-mode-strategies.md for strategy flowchart, diagrams, and teammate templates.

```
1. Check env: CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
2. If active: analyze batches, present top 2-3 strategies to user
3. Store choice in spec.json: sdlc_state.t_strategy
4. This is the ONE place we pause for user input in T-Mode
```

### Step 3: Execute Batches
```
For each batch:
  0. UPDATE progress.md with "starting Batch X"
  1. Collect ALL tasks, acceptance criteria, design context
  2. Check T-Mode → apply strategy OR dispatch single Actor
  3. Actor returns → UPDATE progress.md
  4. Dispatch BOTH Critic ADVOCATE and SKEPTIC (parallel)
  5. Apply consensus rules (both pass / both fail / disagree)
  6. Mark batch complete in progress.md
  7. Update phase visualization (progress bar, test count, critic summary)

  IMPORTANT: Keep main context LEAN. Don't echo full agent output.
  Summarize: "Batch X: done, N tests, critics: PASS"

  Context Hygiene: Offload research to Explore subagents. One focused task per Actor. Don't accumulate research results in the Director's context — let subagents digest and summarize.
```

### Step 4: Retrospective + Decision Log
```
After Final Validator (or after lightweight path validation):
  1. Run retrospective protocol (3 questions — see @ref/context-health.md)
  2. Log decisions to {project}/.claude/decision-log.md if applicable
  3. Update context freshness if reviewed
  4. Render retrospective summary box (see @ref/phase-viz.md)
  5. Capture Lessons: If retrospective surfaces a reusable pattern or mistake, write to project's auto-memory (MEMORY.md) or CLAUDE.md
  6. Render final summary box
```

## Prompt Templates

- **Actor template:** See @ref/validator-templates.md (Actor section)
- **Critic ADVOCATE/SKEPTIC:** See @ref/validator-templates.md (Critic section)
- **Requirements ADVOCATE/SKEPTIC:** See @ref/validator-templates.md (Requirements section)
- **Product Skeptic:** See @ref/validator-templates.md (Product Skeptic section) + @ref/product-skeptic.md
- **Tasks ADVOCATE/SKEPTIC:** See @ref/validator-templates.md (Tasks section)
- **Final ADVOCATE/SKEPTIC:** See @ref/validator-templates.md (Final section)
- **DevRel Actor / Docs Critic:** See @ref/docs-phases.md (P2 section)
- **Demo Actor:** See @ref/docs-phases.md (P3 section)

## Task Primitive Integration (Cross-Session)

**Prerequisite:** `CLAUDE_CODE_TASK_LIST_ID=pdlc-autopilot` in shell env (persists tasks across sessions in `~/.claude/tasks/`).

### Implementation Tasks
```
Director Setup: Parse tasks.md → TaskCreate for each task
Per Batch: TaskUpdate(in_progress) → Actor → Critic → TaskUpdate(completed)
Final: TaskList() to verify all tasks completed
```

### Bug Tracking via Tasks API
```
Bug discovered (by Critic, test, or user):
  → TaskCreate with metadata: { "type": "bug", "project": "{project}", "severity": "high|medium|low", "found_by": "SKEPTIC|ADVOCATE|test|user", "batch": "N" }
  → Subject: "[BUG] {concise description}"
  → Description: root cause (if known), reproduction, affected files

Bug Fix path (B1 Diagnose):
  → TaskList() → filter for metadata.type == "bug" and status != "completed"
  → TaskGet(bugId) → read full context
  → TaskUpdate(bugId, status: "in_progress")

Bug fixed (B3 Validate passes):
  → TaskUpdate(bugId, status: "completed", metadata: { "fix": "description", "regression_test": "file:line" })

Retrospective:
  → TaskList() → count open bugs, report in retro summary
```

## Batching Strategy

**Group tasks that touch the same files:**
```
Tasks 1.1-1.4 all modify transform_snapshot.py → BATCH A (1 Actor, not 4)
Tasks 2.3 modifies app.js → BATCH B
→ Run A and B in PARALLEL if no file overlap
```

## Session Persistence

See @ref/session-persistence.md for compaction survival, progress.md template, context budget management, and validation-criteria.md template.

**Key files that survive compaction:**
- `{project}/.claude/product-context.md` — product strategy
- `{project}/.claude/decision-log.md` — decisions (append-only)
- `{spec_dir}/validation-criteria.md` — rules
- `{spec_dir}/progress.md` — execution state

### Resume Protocol

```
1. Read spec.json → get spec_dir, current_phase
2. Read {spec_dir}/progress.md → EXACT execution state
3. Read {spec_dir}/validation-criteria.md → rules
4. Do NOT re-read completed batch files
5. Resume from EXACTLY where progress.md says
```

## Examples

See @ref/examples.md for full standard mode and T-Mode execution walkthroughs.

## Red Flags

**Never:**
- Dispatch per-task agents (use batches)
- Have Actor dispatch sub-agents (defeats purpose)
- Skip Critic review
- Run parallel batches that touch same file
- Let two teammates modify the same file (T-Mode)

**Fix cycles:** Max 2 Critic cycles per batch. If still failing, report to user.

## Integration

**Required:** Kiro spec with requirements.md, design.md, tasks.md
**Required (PDLC):** `{project}/.claude/product-context.md` — auto-generated by Phase P0 if missing
**Optional but RECOMMENDED:** validation-criteria.md for session persistence

**Kiro Validation Skills:**
- `kiro:validate-gap` - Analyze implementation gaps
- `kiro:validate-design` - GO/NO-GO design decision
- `kiro:spec-requirements/design/tasks` - Generate missing artifacts

**Uses:** Task tool with general-purpose subagent type

**Complements:**
- `superpowers:test-driven-development` (Actors should follow TDD)
- `superpowers:verification-before-completion` (Critic verifies)

**PDLC Phases (ref/ files):**
- @ref/product-context-template.md — Phase P0: product-context.md generation
- @ref/product-skeptic.md — Phase P1: adversarial product alignment review
- @ref/docs-phases.md — Phase P2 (Document) + P3 (Demo & Package)
- @ref/lightweight-paths.md — Bug Fix + Iteration paths (lightweight alternatives to full PDLC)
- @ref/context-health.md — Freshness validation, decision log, retrospective, drift detection
- @ref/phase-viz.md — Phase visualization templates (pipelines, progress bars, summary boxes)

## When NOT to Use Kiro Skills Directly

| If user says... | DON'T use... | DO use... |
|-----------------|--------------|-----------|
| "SDLC", "go back to spec" | kiro:spec-* directly | pdlc-autopilot |
| "implement the feature" | kiro:spec-tasks | pdlc-autopilot |
| "continue where we left off" | kiro:spec-* | pdlc-autopilot |

**When IS it OK to use Kiro skills directly?**
- User explicitly says "just generate requirements" (no full SDLC)
- User wants to re-generate a specific artifact without running the loop
- Debugging/inspecting a single phase
