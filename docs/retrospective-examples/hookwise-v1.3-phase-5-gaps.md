# PDLC v3.5 Retrospective: hookwise PR #10 CodeRabbit Findings

**Date:** 2026-03-03
**Project:** hookwise v1.3
**Trigger:** CodeRabbit found 22 actionable issues (2 critical, 11 major) that the PDLC process missed

## Gap Classification Summary

| Gap Type | Count | Findings |
|----------|-------|----------|
| PROMPT_GAP | 14 | Architecture violations, input validation, timezone, test quality, docs |
| CALLSITE_GAP | 3 | Missing weather/memories in status, doctor, segments |
| TOOLING_GAP | 5 | Linter issues, type safety |
| ARCH_GAP | 1 | Dispatch phase ordering |
| COVERAGE_GAP | 1 | Shallow merge helper |
| HUMAN_ONLY | 1 | TOCTOU race |

> **Note:** Counts sum to 25 because 3 issues span multiple gap types. Unique issue count is 22.

## Root Cause: Spec-Criteria Tunnel Vision

The PDLC process is fundamentally spec-criteria-driven: "Does the code satisfy the acceptance criteria?" This catches spec misalignment but misses:
1. **Defensive coding** — no AC says "validate config reads" or "use timezone-aware dates"
2. **Cross-cutting callsite consistency** — batch isolation prevents seeing "what else needs updating"
3. **Engineering canon** — SKEPTIC checks code against spec, not against best practices
4. **Mechanical issues** — no linters/type-checkers in the loop

## P0 Action Items (High Impact, Low Effort)

### ACTION-1: Callsite Completeness Check

Add to Actor + SKEPTIC prompts: When adding new entities, grep for all registration points and update ALL of them.

### ACTION-2: Input Validation at Trust Boundaries

Add to SKEPTIC: Check all values from external sources (config, cache, API) for safe parsing. Flag raw float()/parseInt() without try/catch.

### ACTION-4: Test Assertion Quality

Add to SKEPTIC: Flag tests with no assertions, count-only assertions, non-deterministic tests, unused variables.

### ACTION-8: Linter/Type-Checker Gate

Add to Actor: Run project linter before self-review. Add to SKEPTIC: Check if linter was run.

## P1 Action Items

### ACTION-5: Execution Order Awareness

Add to Actor: When modifying existing functions, understand control flow first. Guards before side-effects.

### ACTION-3: Timezone Consistency

Add to SKEPTIC: Check UTC/local date mixing, day boundary consistency.

### ACTION-10: Registration Contract ARCH Extraction

Phase 0.5: Explicitly extract registration patterns as ARCH constraints.

### ACTION-7: Documentation Freshness

Add to Final Validator: Check README metrics match codebase reality.

## P2 Action Items

### ACTION-9: Dictionary/Map Exhaustiveness

Add to SKEPTIC: Check lookup maps cover all expected inputs.

### ACTION-6: Concurrency Patterns

Add to SKEPTIC: Flag check-then-act patterns, non-atomic PID files.

## Impact Projection

P0 actions alone would have caught **13 of 22 findings**. All actions together: **20 of 22**.
