# PDLC Execution Examples

## Standard Mode Example

```text
Director: Starting PDLC Autopilot v3.6 (Dual-Perspective Mode)...

📋 Spec: .claude/specs/my-feature/
   - 11 tasks

🔍 Phase P0: Product Context Check
   product-context.md found. Tier: 0 (Personal)
   → Product context loaded. Proceeding.

🔍 Phase 0a: Check/Generate Artifacts (PROC-1)...
   requirements.md ✅ exists
   design.md ✅ exists
   tasks.md ✅ exists
   → Provenance recorded in progress.md

🔍 Phase 0b: Kiro Validation (PROC-1 — Skill tool invocations)...
   [Skill tool: kiro:validate-gap] ⚠️ 2 areas need research (non-blocking)
   [Skill tool: kiro:validate-design] ✅ GO decision

🔍 Phase 0b: Subagent Validation (parallel)...
   [Requirements ADVOCATE] ✅ PASS - requirements implementable
   [Requirements SKEPTIC] ⚠️ PASS WITH WARNINGS - minor gaps noted
   [Product Skeptic] ✅ APPROVE — spec aligns with product context
   → Consensus: PASS (all pass)

   [Tasks ADVOCATE] ✅ PASS - tasks ready for implementation
   [Tasks SKEPTIC] ✅ PASS - no critical gaps
   → Consensus: PASS (both pass)

🔍 Phase 0.5: Load validation-criteria.md ✅
   → ARCH-1, ARCH-2 extracted from design.md

🔍 Phase 0.75: Test Strategy Research
   [Test Strategy Designer] ✅ infrastructure audited, 2 holdout scenarios sealed
   → Test tier requirements stored for Actors

📦 Batching:
   BATCH A: transform_snapshot.py (Tasks 1.1-1.4, 3.1-3.2)
   BATCH B: app.js (Tasks 2.3)
   BATCH C: validate_pipeline.py (Task 4.1)
   BATCH D: tests (Task 4.2)

🔄 Executing BATCH A (6 tasks, 1 file)
   [Actor] Implementing all 6 tasks...
   [Actor] Done. Self-review: all criteria addressed.
   [Critic ADVOCATE] ✅ 18/18 criteria pass
   [Critic SKEPTIC] ❌ 1 fail (missing fallback in Task 1.2)
   → Consensus: DISAGREE - Director reviews...
   → Director: SKEPTIC has valid point, fixing
   [Actor] Fixing specific issue...
   [Critic ADVOCATE] ✅ All pass
   [Critic SKEPTIC] ✅ All pass
   → Consensus: PASS
   ✅ BATCH A complete

🔄 Executing BATCH B (1 task, 1 file)
   [Actor] Implementing Task 2.3...
   [Critic ADVOCATE] ✅ All criteria pass
   [Critic SKEPTIC] ✅ All criteria pass
   → Consensus: PASS
   ✅ BATCH B complete

... (continues)

🏁 Final Validation:
   [Final ADVOCATE] ✅ All FR-* requirements covered + PDLC compliance OK
   [Final SKEPTIC] ✅ No gaps found. Holdout scenarios passed.
   → Consensus: PASS

🔄 Phase 5: PR Review Cycle (opt-in)
   [PR created] → 1 reviewer comment (minor style nit)
   [Review Actor] Fixed style issue → re-requested review
   → Approved ✅

📝 Retrospective:
   Changed: Implemented batch processing with 4 file groups
   Learned: SKEPTIC caught a missing fallback early — saved rework
   Context: updated | Decisions: 1 logged

📊 Summary:
   - 4 batches, 16 critic calls (8 ADVOCATE + 8 SKEPTIC)
   - 1 disagreement resolved (Batch A, SKEPTIC was right)
   - All 11 tasks complete
   - All FR-* requirements verified
   - Phase 5: 1 PR cycle, 1 comment addressed
```

## T-Mode Example (S2: Impl + Test)

```text
Director: Starting PDLC Autopilot v3.6 (T-Mode: Agent Teams)...

📋 Spec: .claude/specs/my-feature/
   - 9 tasks
   - T-Mode: ACTIVE (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1)

🔍 Phase P0-0b: Product Context + Artifacts + Validation (same as standard mode — PROC-1)
   [Product context loaded. Tier: 0]
   [Skill tool invocations for kiro:validate-gap, kiro:validate-design]
   [All validations PASS, Product Skeptic: APPROVE]

🔍 Phase 0.5-0.75: Validation criteria loaded, test strategy designed

📦 Batching:
   BATCH A: Task CRUD (handlers, validators, templates — 6 tasks)
   BATCH B: Integration wiring (index.ts, server.ts — 3 tasks)

🎯 Step 2.5: T-Mode Strategy Selection
   Analyzing batch characteristics...
   - BATCH A: 3 file groups, clear interfaces in design, tests needed
   - BATCH B: 2 tightly-coupled files, sequential

   T-Mode Strategy Options for BATCH A:

    [1] File Ownership
        3 teammates: handlers/, validators/, templates/
        + Maximum parallelism (3x speedup)
        - Integration risk at boundaries

    [2] Impl + Test (Recommended)
        2 teammates: Implementer (all source) + Test Writer (all tests)
        + Tests written against design interfaces = better coverage
        + Catches mismatches early
        - 2x speedup (not 3x)

    [3] Standard Mode
        Single Actor, sequential
        + Safest, no coordination overhead
        - Slowest

   → User selects: [2] Impl + Test
   → Stored: pdlc_state.t_strategy = "impl-test"
   → BATCH B: too coupled → Standard mode

🔄 Executing BATCH A (T-Mode S2: Impl + Test)
   [Lead] Spawning 2 teammates...
   [Teammate IMPL] Implementing all 6 tasks... ⏳
   [Teammate TEST] Writing tests against design interfaces... ⏳
   [Teammate IMPL] ✅ Done (6 tasks completed)
   [Teammate TEST] ✅ Done (test suite written)
   [Lead] Both finished. Updating barrel exports...
   [Lead] Running npm test... 14/15 pass, 1 fail (interface mismatch)
   [Lead] Fixing: validator return type doesn't match test expectation
   [Lead] Running npm test... ✅ 15/15 pass
   [Critic ADVOCATE] ✅ All criteria pass
   [Critic SKEPTIC] ✅ All criteria pass
   → Consensus: PASS
   ✅ BATCH A complete

🔄 Executing BATCH B (Standard mode)
   [Actor] Implementing 3 wiring tasks...
   [Critic ADVOCATE] ✅ All pass
   [Critic SKEPTIC] ✅ All pass
   → Consensus: PASS
   ✅ BATCH B complete

🏁 Final Validation: PASS

📊 Summary:
   - Strategy: Impl + Test (S2) for BATCH A, Standard for BATCH B
   - 2 teammates + 1 actor + 4 critic calls
   - 1 integration fix by Lead (interface mismatch)
   - All 9 tasks complete, all FR-* verified
```

## PDLC Mode Example

```text
Director: Starting PDLC Autopilot v3.6...

📋 Project: ~/workplace/hookwise/
   - Feature: hookwise-docs

🔍 Phase P0: Product Context Check
   product-context.md found at ~/workplace/hookwise/.claude/product-context.md
   Tier: 1 (Community)
   → Product context loaded. Proceeding.

🔍 Phase 0a: Check/Generate Artifacts (PROC-1)...
   requirements.md ✅ exists
   design.md ✅ exists
   tasks.md ✅ exists
   → Provenance recorded in progress.md ✅

🔍 Phase 0b: Kiro Validation (PROC-1 — Skill tool invocations)...
   [Skill tool: kiro:validate-gap] ✅ No critical gaps
   [Skill tool: kiro:validate-design] ✅ GO decision

🔍 Phase 0b: Subagent Validation (3 parallel)
   [Requirements ADVOCATE] ✅ PASS — requirements clear and implementable
   [Requirements SKEPTIC] ✅ PASS — no critical gaps
   [Product Skeptic] ⚠️ [SCOPE] — 2 requirements drift from V1 Core:
     - FR-7 (multi-language i18n): Layer 2 feature, not V1 Core
     - FR-11 (video tutorials): Layer 3, not V1

   → Director presents scope cuts to user:
     "Product Skeptic recommends cutting FR-7 and FR-11.
      FR-7 is Layer 2, FR-11 is Layer 3. Accept? [Yes]"
   → User accepts. FR-7, FR-11 removed from requirements.md and tasks.md.

🔍 Phase 0.5: Load validation-criteria.md ✅
   → ARCH-1, ARCH-2 extracted from design.md

🔍 Phase 0.75: Test Strategy Research
   [Test Strategy Designer] ✅ infrastructure audited, 3 holdout scenarios sealed
   → Test tier requirements stored for Actors

📦 Batching (after scope cuts):
   BATCH A: docs-generator.ts (Tasks 1-3)
   BATCH B: templates/ (Tasks 4-6)
   BATCH C: tests (Tasks 7-8)

🔄 Executing BATCH A-C... (same as standard mode)
   ... [Actor → Critic ADVOCATE + SKEPTIC → fix cycles] ...

🏁 Final Validation:
   [Final ADVOCATE] ✅ All FR-* covered + PDLC compliance OK
   [Final SKEPTIC] ✅ No gaps. Deferred FR-7/FR-11 correctly untouched. Holdout scenarios passed.
   → Consensus: PASS

🔄 Phase 5: PR Review Cycle
   [PR created] → 2 reviewer comments (1 critical, 1 minor)
   [Review Actor] Fixed critical: missing null check in docs-generator.ts:45
   [Review Actor] Fixed minor: typo in template header
   → Re-requested review → Approved ✅

📝 Retrospective:
   Changed: Implemented docs generator with 3 template types
   Learned: Product Skeptic caught Layer 2/3 scope creep — saved ~40% wasted effort
   Context: updated | Decisions: 2 logged (scope cuts)

📝 Phase P2: Document (user requested "document this")
   [DevRel Actor] Generating docs from source code...
   [DevRel Actor] Done. 3 docs files, 47 file:line citations.
   [Docs Critic] Reviewing...
   [Docs Critic] ❌ 1 hallucination: docs reference `--format yaml` flag
                  that doesn't exist in CLI parser (src/cli.ts:89)
   [DevRel Actor] Fixing... removed phantom flag reference.
   [Docs Critic] ✅ PASS — 0 hallucinations, 46 citations verified.

🚀 Phase P3: Demo & Package (user requested "launch prep")
   [Demo Actor] Creating: README update, demo script, CHANGELOG entry
   [Director] Running demo script... ✅ completes in 45s
   [Director] Spot-checking README claims... 5/5 verified

📊 PDLC Report:
   - Tier 1 Community, Product Skeptic: SCOPE (2 cuts)
   - 8 tasks completed, 3 batches
   - Phase 0.75: 3 holdout scenarios sealed, all passed at Final Validation
   - Phase 5: 1 PR cycle, 2 comments addressed (1 critical, 1 minor)
   - Retrospective: 2 decisions logged, context updated
   - P2: 3 docs files, 1 hallucination fixed
   - P3: README, demo script, CHANGELOG
   - All FR-* verified, deferred reqs untouched
```

## Efficiency Gains

| Scenario | v1 Agents | v3.6 Agents | v3.6+T-Mode | Savings |
|----------|-----------|-------------|-------------|---------|
| 4 tasks, same file | 12 | 2 | 2 (no gain) | 83% |
| 10 tasks, 2 files | 30 | 4 | 4 (parallel) | 87% |
| 10 tasks, 5 files | 30 | 10 | 5 teammates + 2 critics | 77% |
| 8 tasks, 3 file groups | 24 | 6 | 3 teammates + 2 critics | 79% |

**Token savings:**
- Actor reads file ONCE, implements ALL tasks
- Critic reads file ONCE, checks ALL criteria
- Director never re-reads spec

**T-Mode additional gains:**
- Teammates work in parallel (wall-clock time reduced by ~Nx for N teammates)
- Each teammate has smaller context (only their owned files)
- No file contention (exclusive ownership prevents merge conflicts)
