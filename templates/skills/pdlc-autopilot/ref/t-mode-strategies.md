# T-Mode: Agent Teams Integration

**When `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set**, the Director can spawn teammates for parallel work within a batch.

## T-Mode Detection

```text
On startup, check for Teams availability:

1. Check env: CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
   - If SET → T-Mode available, announce: "T-Mode active. Parallel teammates enabled."
   - If NOT SET → Standard mode, use single Actor subagent per batch

2. Store t_mode in spec.json pdlc_state:
   "t_mode": true           // persists across compaction
   "t_strategy": "..."      // selected strategy name (persists)
```

## Strategy Decision Flowchart

```dot
digraph strategy_selection {
    rankdir=TB;
    node [shape=diamond style=filled fillcolor=lightyellow];
    edge [fontsize=10];

    start [label="T-Mode active?\nBatch ready" shape=box fillcolor=lightblue];
    q1 [label="How many\nfile groups?"];
    q2 [label="Tests needed\nor missing?"];
    q3 [label="Spec evolving?\nGaps known?"];
    q4 [label="Natural dependency\nchain?"];
    q5 [label="Single complex\nfile?"];

    s1 [label="S1: File Ownership\n(max parallelism)" shape=box fillcolor=palegreen];
    s2 [label="S2: Impl + Test\n(quality focus)" shape=box fillcolor=palegreen];
    s3 [label="S3: Full Triad\n(discovery mode)" shape=box fillcolor=palegreen];
    s4 [label="S4: Pipeline\n(ordered handoff)" shape=box fillcolor=palegreen];
    s5 [label="S5: Swarm\n(divide & conquer)" shape=box fillcolor=palegreen];
    std [label="Standard Mode\n(single Actor)" shape=box fillcolor=lightgray];

    present [label="Present top 2-3\nto user" shape=box fillcolor=orange];

    start -> q1;
    q1 -> s1 [label="2+ groups"];
    q1 -> q2 [label="1-2 groups"];
    q2 -> s2 [label="yes, interfaces clear"];
    q2 -> q3 [label="no / unclear"];
    q3 -> s3 [label="yes, exploratory"];
    q3 -> q4 [label="no, spec is solid"];
    q4 -> s4 [label="yes, A→B→C"];
    q4 -> q5 [label="no chain"];
    q5 -> s5 [label="yes, 1 big file"];
    q5 -> std [label="no → small batch"];

    s1 -> present;
    s2 -> present;
    s3 -> present;
    s4 -> present;
    s5 -> present;
}
```

## Strategy Presentation Format

**When T-Mode is active, present options using this format:**

```text
T-Mode Strategy Options for [Batch Name]:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[1] S1: File Ownership (Recommended)

    ┌─────────┐  ┌─────────┐  ┌─────────┐
    │ Actor A │  │ Actor B │  │ Actor C │
    │handlers/│  │template/│  │validatr/│
    └────┬────┘  └────┬────┘  └────┬────┘
         └───────────┬┘────────────┘
                     ▼
              ┌────────────┐
              │Lead merges │
              │shared files│
              └──────┬─────┘
                     ▼
              ┌────────────┐
              │  Critics   │
              └────────────┘

    Teammates: 3 (one per module)
    Parallelism: ███████████ HIGH
    Risk: integration at module boundaries
    Best for: independent file groups

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[2] S2: Impl + Test

    ┌──────────────┐     ┌──────────────┐
    │ Implementer  │     │ Test Writer  │
    │ src/*.ts     │     │ __tests__/*  │
    └──────┬───────┘     └──────┬───────┘
           └────────┬───────────┘
                    ▼
             ┌────────────┐
             │Lead runs   │
             │test suite  │
             └──────┬─────┘
                    ▼
             ┌────────────┐
             │  Critics   │
             └────────────┘

    Teammates: 2 (builder + tester)
    Parallelism: ██████░░░░░ MEDIUM
    Risk: interface mismatch (Lead fixes)
    Best for: TDD flow, catching bugs early

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[3] S3: Full Triad

    ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
    │ Implementer  │ │ Test Writer  │ │ Product Eye  │
    │ builds code  │ │ writes tests │ │ evolves spec │
    └──────┬───────┘ └──────┬───────┘ └──────┬───────┘
           └────────────────┼────────────────┘
                            ▼
                   ┌──────────────┐
                   │Lead merges + │
                   │reconcile spec│
                   └──────┬───────┘
                          ▼
                   ┌────────────┐
                   │  Critics   │
                   └────────────┘

    Teammates: 3 (builder + tester + product)
    Parallelism: ██████░░░░░ MEDIUM
    Risk: spec drift mid-batch
    Best for: exploratory features, evolving requirements

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[4] S4: Pipeline

    ┌────────────┐     ┌────────────┐     ┌────────────┐
    │ A: Schemas │────→│ B: Handlers│────→│ C: Tests   │
    │ & types    │     │ & logic    │     │ & integr.  │
    └────────────┘     └────────────┘     └────────────┘
     starts first       waits for A        waits for B

    Teammates: 2-3 (staggered start)
    Parallelism: ████░░░░░░░ LOW (but ordered)
    Risk: blocked if upstream is slow
    Best for: schema→handler→test dependency chains

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[5] S5: Swarm

    ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
    │ Core Logic   │ │ Error Paths  │ │ Edge Cases   │
    │ happy path   │ │ validation   │ │ boundaries   │
    │ SAME FILES   │ │ SAME FILES   │ │ SAME FILES   │
    └──────┬───────┘ └──────┬───────┘ └──────┬───────┘
           └────────────────┼────────────────┘
                            ▼
                  ┌───────────────────┐
                  │ Lead RECONCILES   │
                  │ (merge conflicts!)│
                  └─────────┬─────────┘
                            ▼
                     ┌────────────┐
                     │  Critics   │
                     └────────────┘

    Teammates: 2-3 (different concerns, same files)
    Parallelism: ██████░░░░░ MEDIUM
    Risk: ⚠️ HIGH merge conflict risk
    Best for: single complex file, major refactoring

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[6] S5w: Swarm + Worktree (recommended over S5)

    main ──┬── worktree-batch-X-core ──── Actor CORE
           ├── worktree-batch-X-error ─── Actor ERROR
           └── worktree-batch-X-edge ──── Actor EDGE

    Each actor works on its own branch + filesystem copy.
    All modify the SAME logical files, but in SEPARATE worktrees.

    ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
    │ Core Logic   │ │ Error Paths  │ │ Edge Cases   │
    │ own branch   │ │ own branch   │ │ own branch   │
    │ own worktree │ │ own worktree │ │ own worktree │
    └──────┬───────┘ └──────┬───────┘ └──────┬───────┘
           └────────────────┼────────────────┘
                            ▼
                  ┌───────────────────┐
                  │ Lead merges       │
                  │ 3 branches → main │
                  │ (git merge, not   │
                  │  manual reconcile)│
                  └─────────┬─────────┘
                            ▼
                     ┌────────────┐
                     │  Critics   │
                     └────────────┘

    Teammates: 2-3 (different concerns, separate worktrees)
    Parallelism: ██████░░░░░ MEDIUM
    Risk: ✅ LOW (vs S5's ⚠️ HIGH) — git handles merge conflicts
    Best for: single complex file, when S5 reconciliation is too risky

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[7] S6: Fix Cycle Isolation

    Batch X fails → retry in fresh worktree

    main ──┬── worktree-batch-X-attempt-1 ── ❌ FAILED
           └── worktree-batch-X-attempt-2 ── ✅ PASSED → merge

    Attempt 1 preserved as evidence. Director can:
      git diff worktree-batch-X-attempt-1..worktree-batch-X-attempt-2

    Teammates: 1 per attempt (max 2 attempts per PDLC rules)
    Parallelism: N/A (sequential retries)
    Risk: ✅ LOW — failed attempts don't pollute main
    Best for: batches that fail and need fix cycles

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[0] Standard Mode (no teammates)
    Single Actor → Critics. Safe, sequential, no coordination overhead.

Which strategy? [0-5]
```

**After user selects:**
```text
4. Store choice in spec.json: pdlc_state.t_strategy = "<selected-strategy>"
5. Apply selected strategy for all batches (unless user overrides per-batch)
```

## Strategy Selection Matrix

| Signal | S1 File Own | S2 Impl+Test | S3 Full Triad | S4 Pipeline | S5 Swarm | S5w Worktree | S6 Fix Cycle |
|--------|-------------|--------------|---------------|-------------|----------|--------------|--------------|
| 2+ independent file groups | **best** | ok | ok | ok | no | no | no |
| Test suite needed | ok | **best** | **best** | ok | no | no | no |
| Spec has gaps/evolving | no | ok | **best** | ok | no | no | no |
| Natural task ordering | ok | ok | ok | **best** | no | no | no |
| Single complex file | no | no | no | no | ok (risky) | **best** | no |
| Small batch (1-2 tasks) | no | no | no | no | no -> Std | no | no |
| Tight file coupling | no | ok | ok | ok | caution | no | no |
| Single complex file (safe) | no | no | no | no | no | **best** | no |
| Fix cycle (retry needed) | no | no | no | no | no | no | **best** |

## Git Worktree Integration (Defense-in-Depth)

Claude Code supports `isolation: "worktree"` on subagents, giving each teammate its own filesystem copy of the repo on a separate branch. This provides **structural isolation** that complements prompt-based file ownership.

### Why Both Layers?

| Layer | Mechanism | What It Prevents |
|-------|-----------|-----------------|
| File Ownership (prompt) | "DO NOT touch files outside your list" | Most accidental edits |
| Worktree (structural) | Separate filesystem per actor | ALL accidental edits — impossible to stomps others' files |
| Branch merge | `git merge worktree-X` | Silent corruption — conflicts become visible git conflicts |
| Auto-cleanup | Worktree removed on no changes | Stale state from failed actors |

File ownership is the sign on the door. Worktrees give each actor their own room.

### Worktree Safety Mode (Opt-In)

Enable in spec.json to add worktree isolation to S1/S2/S3:

```json
"sdlc_state": {
  "worktree_safety": true
}
```

Effect: All teammates get `isolation: "worktree"` — same file ownership rules apply, but now structurally enforced. If a teammate accidentally touches another's file, it shows up as a merge conflict (visible) instead of silent overwrite (invisible).

Default: `false` (no overhead unless explicitly enabled).

## File Ownership Rules (applies to S1, partially to S4)

```text
1. NO two teammates touch the same file
2. Shared files (index.ts, barrel exports, package.json) are RESERVED for Lead
3. Lead updates shared files AFTER all teammates complete
4. Each teammate gets a clear list of files they OWN
5. If ownership can't be cleanly divided → consider S2 or Standard mode
```

## T-Mode Actor Protocols

### S1: File Ownership — Teammate Request Template

```text
"I need [N] teammates to implement this batch in parallel.

Teammate A: Implement tasks [1.1, 1.2] in [handlers/].
  Files you OWN: handlers/create-entity.ts, handlers/create-fleeting-note.ts
  DO NOT touch any files outside your ownership.
  Tasks: [paste task descriptions + acceptance criteria]
  Design context: [paste relevant design sections]
  When done, mark your tasks as completed in the task list.

Teammate B: Implement tasks [2.1] in [templates/].
  Files you OWN: templates/generators.ts, templates/index.ts
  [same structure...]

IMPORTANT: Each teammate ONLY modifies files in their ownership list.
Shared files will be updated by me (Lead) after you all finish."
```

### S2: Impl + Test — Teammate Request Template

```text
"I need 2 teammates working in parallel on this batch.

Teammate IMPL: Implement all tasks for this batch.
  Files you OWN: [list all source files]
  Tasks: [paste ALL task descriptions + acceptance criteria]
  Design context: [paste relevant design sections]
  Write the implementation code. DO NOT write tests.
  When done, mark your tasks as completed in the task list.

Teammate TEST: Write test cases for all tasks in this batch.
  Files you OWN: [list all test files, e.g. __tests__/*.test.ts]
  Tasks: Write tests covering these acceptance criteria:
    [paste ALL acceptance criteria from all tasks]
  Design context: [paste interfaces/contracts from design.md]
  Write tests against the DESIGNED interfaces (not the implementation).
  You can read source files but do NOT modify them.
  When done, mark your tasks as completed in the task list.

Both start simultaneously. I (Lead) will run the full test suite
after you both finish and fix any integration gaps."
```

### S3: Impl + Test + Product — Teammate Request Template

```text
"I need 3 teammates working on this batch.

Teammate IMPL: [same as S2 IMPL above]

Teammate TEST: [same as S2 TEST above]

Teammate PRODUCT: Evolve the spec based on implementation discoveries.
  Files you OWN: {spec_dir}/requirements.md, {spec_dir}/design.md
  Your job:
  1. Monitor implementation progress via the task list
  2. Read the source code as teammates write it
  3. Identify edge cases, UX issues, or spec gaps
  4. Update requirements.md with discovered requirements (mark as [DISCOVERED])
  5. Update design.md with revised designs if needed
  6. Create new tasks via TaskCreate for anything the current batch doesn't cover
  7. Flag blocking issues to me (Lead) immediately
  When done, summarize all spec changes in the task list.

IMPL and TEST start immediately. PRODUCT monitors and evolves.
I (Lead) will reconcile spec changes before the next batch."
```

### S4: Pipeline — Teammate Request Template

```text
"I need [N] teammates working in a pipeline for this batch.

Teammate A (schemas/types): Start IMMEDIATELY.
  Files you OWN: [schema/type files]
  Tasks: [schema/type tasks]
  When done, mark tasks completed. Teammate B is waiting on your interfaces.

Teammate B (handlers/logic): Start when Teammate A's tasks show 'completed'.
  Files you OWN: [handler/logic files]
  Tasks: [handler tasks]
  Read Teammate A's files for types/interfaces. DO NOT modify them.
  When done, mark tasks completed.

Teammate C (tests/integration): Start when Teammate B's tasks show 'completed'.
  Files you OWN: [test files]
  Tasks: [test tasks]
  Read source files but DO NOT modify them.
  When done, mark tasks completed.

Pipeline: A → B → C. Each waits for the previous to finish.
I (Lead) will merge shared files and run the full suite after C completes."
```

### S5w: Swarm + Worktree — Teammate Request Template

```
"I need [N] teammates to swarm on this batch, each in an isolated worktree.

Teammate CORE (isolation: worktree):
  Concern: Core happy-path logic
  Files to modify: [list files]
  Tasks: [paste task descriptions]
  You have your own copy of the repo. Commit when done.

Teammate ERROR (isolation: worktree):
  Concern: Error handling and validation
  Files to modify: [SAME files as CORE — that's fine, you're isolated]
  Tasks: [paste task descriptions]
  You have your own copy of the repo. Commit when done.

Teammate EDGE (isolation: worktree):
  Concern: Edge cases and boundary conditions
  Files to modify: [SAME files as CORE]
  Tasks: [paste task descriptions]
  You have your own copy of the repo. Commit when done.

After all teammates commit, I (Lead) will merge the 3 branches.
Git handles structural conflicts; I resolve semantic conflicts."
```

### S6: Fix Cycle — Retry Protocol

```
When an Actor fails and enters a fix cycle:

1. Actor attempt-1 failed in worktree-batch-X-attempt-1
   → Keep worktree as evidence (do NOT clean up)

2. Create fresh worktree: worktree-batch-X-attempt-2
   → Actor starts clean, informed by attempt-1's critic feedback

3. If attempt-2 passes:
   → Merge attempt-2 branch to main
   → Clean up both worktrees
   → Log: "Fix cycle succeeded on attempt 2"

4. If attempt-2 fails:
   → Escalate to user (max 2 fix cycles per PDLC rules)
   → Provide diff: git diff attempt-1..attempt-2
   → Keep both worktrees for debugging
```

## Teammate Coordination (all strategies)

```text
1. Lead creates TaskCreate for each task (if not already created)
2. Lead requests teammates per selected strategy template
3. Teammates work per their assigned role
4. Teammates use TaskUpdate to mark tasks completed
5. Lead monitors TaskList for all teammate tasks → completed
6. Lead updates shared files (barrel exports, index.ts, etc.)
7. Lead runs full test suite to verify integration
8. Lead dispatches Critics (ADVOCATE + SKEPTIC) on ALL changed files
```

## Lead Post-Teammate Checklist

```text
After all teammates complete:
  1. TaskList() → verify all teammate tasks are "completed"
  2. If S3 (Product): review spec changes, reconcile with current batch
  3. Read shared files that may need updates (index.ts, barrel exports)
  4. Update shared files to integrate teammate work
  5. Run test suite: npm test / pytest / etc.
  6. If tests fail: Lead fixes integration issues directly
  7. Dispatch Critics on the FULL batch (all files, all teammates' work)
```

## Fallback: When to Abort T-Mode

```text
Abort T-Mode and fall back to standard Actor if:
  - File ownership can't be cleanly divided (S1)
  - Tasks have data dependencies that don't fit a pipeline (S4)
  - Only 1 task in the batch
  - Teammate fails repeatedly (2+ failures on same task)
  - User requests Standard mode
```

## T-Mode Batch Analysis

```text
Standard mode: Group tasks by file → one Actor per batch
T-Mode:        Group tasks by file → analyze → select strategy → spawn teammates

For each batch, determine:
  1. How many independent file groups? (→ S1 if 2+)
  2. Are tests needed/missing? (→ S2 or S3)
  3. Is the spec evolving? (→ S3)
  4. Natural dependency chain? (→ S4)
  5. Single complex file? (→ S5)
  6. Only 1 task or tightly coupled? (→ Standard)

Present viable options to user at Step 2.5 (see Strategy Selection above).
```

## Worktree Status Visualization

When T-Mode is active with worktrees, show status using this format:

```
T-Mode Status: S5w (Swarm + Worktree Isolation)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  main ──┬── wt-batch-A-core ───── Actor CORE   ✅ committed
         ├── wt-batch-A-error ──── Actor ERROR  ⏳ working...
         └── wt-batch-A-edge ───── Actor EDGE   ✅ committed

  Director: waiting for ERROR to complete
  Files in play: dispatcher.ts, config.ts, types.ts
  Next: merge 3 branches → run Critics
```

Update on each state change:
- `⏳ working...` → actor is implementing
- `✅ committed` → actor finished and committed
- `🔀 merging` → Lead is merging this branch
- `🧹 cleaned up` → worktree removed after merge
- `❌ failed` → actor failed (worktree preserved for debugging)

## Worktree User Education (Progressive Disclosure)

### First T-Mode Run (verbose)
```
📚 Worktree Isolation Active

Each actor gets their own copy of the repository on a separate git branch.
This means actors CAN'T accidentally overwrite each other's work — even if
they're editing the same file. When all actors finish, their branches get
merged back together.

Think of it like giving each actor their own desk with their own copy of
the documents, instead of having them all crowd around one desk.
```

### Subsequent Runs (concise)
```
🌳 Worktree isolation: 3 actors × 3 branches
```

### During Merge (educational)
```
🔀 Merging 3 worktree branches into main...
   ├── wt-batch-A-core: 4 files changed → merged ✅
   ├── wt-batch-A-error: 2 files changed → merged ✅
   └── wt-batch-A-edge: 1 file changed → conflict in dispatcher.ts
       → Director resolving conflict (core logic + edge case overlap)
```

### On Cleanup
```
🧹 Worktrees cleaned up:
   - 2 worktrees merged and removed
   - 1 worktree kept (failed attempt — available for debugging)
```
