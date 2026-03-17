# Formal Architecture Verification

Alloy model verifying PDLC Autopilot's 6 architectural primitives before
Phase 1 implementation builds on them.

## Prerequisites

```bash
brew install alloy-analyzer   # Alloy 6.2.0 (requires Java 17+)
alloy help                    # verify installation
```

## Quick Start

```bash
# Run all checks (text output to stdout)
alloy exec --type text --output - formal/pdlc-primitives.als

# Run all checks (JSON output to file)
alloy exec --type json --output formal/results/ --force formal/pdlc-primitives.als

# Run a specific check by name
alloy exec --command "NoGateSideEffects" --type text --output - formal/pdlc-primitives.als

# List all commands in the model
alloy commands formal/pdlc-primitives.als
```

## Interpreting Results

Alloy `check` commands search for **counterexamples** — instances that violate
an assertion.

| Result | Meaning |
|--------|---------|
| **Unsatisfiable** | No counterexample found within scope. Assertion holds. |
| **Satisfiable** | Counterexample found! The assertion is violated. |

A satisfiable result means the architecture has a flaw that needs fixing.

## What's Verified

14 invariants across 6 architectural primitives:

| Primitive | Invariants | Scope |
|-----------|-----------|-------|
| Hook Taxonomy | NoGateSideEffects, ObserversNeverBlock, ReactorsNoStateWrites, CategoriesMutuallyExclusive | for 10 |
| Spec Lifecycle | NoStateSkips, ArchivedIsTerminal, AllStatesReachable | for 7 |
| Context Stack | NoLowerLayerModifiesHigher | for 6 |
| Spec Scopes | NoWorkingLeakToShared, SharedSpecsNotInProgress | for 6 |
| Feedback Loop | AnnotationsAppendOnly, DriftMutuallyExclusive | for 6 |
| Health + State Files | HealthChecksReadOnly, HandoffIsSingleAgentTruth | for 6 |

## Latest Results (2026-03-15)

**14/14 checks passed** — no counterexamples found. Architecture validated.

```
00. check NoGateSideEffects              UNSAT
01. check ObserversNeverBlock            UNSAT
02. check ReactorsNoStateWrites          UNSAT
03. check CategoriesMutuallyExclusive    UNSAT
04. check NoStateSkips                   UNSAT
05. check ArchivedIsTerminal             UNSAT
06. check AllStatesReachable             UNSAT
07. run   ShowReachability               SAT (expected — reachability demo)
08. check NoLowerLayerModifiesHigher     UNSAT
09. check NoWorkingLeakToShared          UNSAT
10. check SharedSpecsNotInProgress       UNSAT
11. check AnnotationsAppendOnly          UNSAT
12. check DriftMutuallyExclusive         UNSAT
13. check HealthChecksReadOnly           UNSAT
14. check HandoffIsSingleAgentTruth      UNSAT
```

See `results/verification-summary.md` for full analysis and go/no-go recommendation.

## File Structure

```
formal/
├── pdlc-primitives.als       # Alloy model (all 6 primitives, single file)
├── results/                  # Alloy Analyzer output
│   └── verification-run.json
└── README.md                 # This file
```

## When to Re-run

Re-run verification after:
- Adding or reclassifying a hook category
- Changing the spec lifecycle state machine
- Modifying context stack layer definitions
- Altering spec scope promotion rules
- Updating state file truth properties
