# PDLC Autopilot — Retrospective Audit (R1-R9)

**Date**: 2026-03-18
**Scope**: 9 roadmap items, ~4088 LOC across 23 shell scripts, 406 BATS tests
**Quality Score**: 67/100
**Commit**: `5c40782` (main branch)

---

## Executive Summary

- **3 critical-severity findings** (integration): CriticGate enforcement permanently bypassed, dual-critic consensus unreachable at runtime, `local` keyword used outside function scope aborts on macOS bash 3.2
- **5 high-severity findings**: 4 library modules missing from C4 model, Alloy mutual-exclusivity invariant violated, 2 hook scripts missing ERR traps with wrong `set` flags, 2 hook scripts with zero test coverage
- **11 medium-severity findings**: duplicate code patterns, documentation/code naming divergence, unimplemented Alloy state files, missing freshness signal, env var override incompatibility
- **Top 3 remediation priorities**: (1) Wire `pdlc-critic.sh` into outer loop and fix `batch` increment, (2) Fix `post-edit-lint.sh`/`post-edit-test.sh` convention violations and add tests, (3) Update C4 model with 4 missing library modules

---

## Metrics Dashboard

| Metric | Value |
|--------|-------|
| Total library files | 14 |
| Total hook scripts | 9 |
| Total test files | 21 |
| Total tests | 406 |
| Total LOC (hooks + lib) | 4,088 |
| Code LOC (excluding comments/blanks) | 1,696 |
| Total functions | 53 |
| Comment ratio | 32% |
| Assertion density (avg) | 1.5 per test |
| Convention compliance | 18/23 files (78%) |
| C4 model coverage | 10/14 libraries (71%) |
| Alloy invariant compliance | 12/14 invariants hold |
| Functions with zero test coverage | 7 |
| Hook scripts with zero test coverage | 2 |
| Duplicate code patterns | 7 identified |

---

## Dimension 1: Cross-Feature Integration

**Auditor**: Integration Analysis | **Findings**: 13 (3 High, 4 Medium, 6 Low)

### Critical Integration Gaps

**F-01 [HIGH] — `local` keyword outside function scope in outer loop**
`hooks/pdlc-outer-loop.sh` lines 321–326 use `local` inside the main `while` loop body (not a function). On macOS `/bin/bash` (3.2), this aborts with `set -euo pipefail`, preventing `pdlc_session_save` from ever executing.

**F-02 [HIGH] — Dual-critic consensus path unreachable**
`pdlc_director_evaluate_critics` guards `pdlc_critic_consensus` behind `declare -f`, but neither the outer loop nor `pdlc-director.sh` ever sources `pdlc-critic.sh`. The structured dual-critic consensus logic (accept-with-caveats, nuanced WARN handling) is permanently bypassed in favor of a simple PASS/FAIL heuristic.

**F-03 [HIGH] — CriticGate enforcement permanently disabled**
`batch` field is initialized to `1` in HANDOFF.md but never incremented. Since `critic-gate.sh` allows any dispatch when `batch <= 1`, the entire Actor → Critic → Actor cadence is bypassed. This is a core process invariant that exists only on paper.

### Additional Findings

| ID | Severity | Description |
|----|----------|-------------|
| F-04 | Medium | 3 libraries declare `pdlc-state.sh` dependency they never use (copy-paste artifact) |
| F-05 | Medium | `pdlc_quality_report` runs `pdlc_placeholder_check` and `pdlc_xref_check` twice per invocation |
| F-06 | Medium | `last_session_date` field read but never written — primary freshness signal dead |
| I-01 | Medium | `batch_N_advocate/skeptic` field writes depend on LLM Actor behavior — unvalidated |
| F-07–F-13 | Low | Stale headers, dead code (`pdlc_session_get_checkpoint_field`, lifecycle utilities), regex divergence, `grep -oP` portability |

### Dependency Graph

No circular dependencies found. `pdlc-state.sh` is the clean root. The sourcing graph is acyclic with proper `declare -f` guards preventing double-sourcing.

---

## Dimension 2: Code Quality

**Auditor**: Static Analysis | **Findings**: 14 (5 Medium, 5 Low, 4 Info)

### Code Metrics

| File | LOC | Functions | Max Function Size |
|------|-----|-----------|-------------------|
| pdlc-critic.sh | 378 | 4 | 125 lines |
| pdlc-director.sh | 312 | 6 | 64 lines |
| pdlc-freshness.sh | 291 | 6 | 71 lines |
| pdlc-quality.sh | 142 | 1 | 119 lines |
| pdlc-review.sh | 143 | 1 | 120 lines |
| pdlc-test-strategy.sh | 147 | 1 | 131 lines |
| **TOTAL** | **2,610** | **53** | — |

14 functions exceed the 50-line threshold. Three files (`pdlc-quality.sh`, `pdlc-review.sh`, `pdlc-test-strategy.sh`) are single monolithic functions with no decomposition.

### Duplicate Code Patterns

| Pattern | Files | Occurrences |
|---------|-------|-------------|
| Edge-case awk block | pdlc-critic.sh, pdlc-skeptic.sh, pdlc-test-strategy.sh | 3x |
| Acceptance scenario count (`grep -c '\*\*Given\*\*'`) | pdlc-critic.sh, pdlc-skeptic.sh, pdlc-test-strategy.sh | 3x |
| Success criteria count (`grep -c "SC-"`) | pdlc-critic.sh, pdlc-skeptic.sh | 2x |
| Task counting (reimplemented inline) | pdlc-review.sh (misses `[X]`) | 1x |
| `PDLC_MAX_RETRIES` default assignment | pdlc-director.sh, pdlc-critic.sh | 2x |
| `extract_file_path` function | post-edit-lint.sh, post-edit-test.sh | 2x |
| Whitespace trimming after `grep -c` | 8 files | 8x |

### Key Quality Issues

| ID | Severity | Finding |
|----|----------|---------|
| Q-01 | Medium | `pdlc-state.sh` (foundational lib) has no `set` directive at all |
| Q-02 | Medium | `PDLC_SOURCE_DIRS` documented as string but initialized as bash array — env override broken |
| Q-03 | Medium | `pdlc_xref_check` and `pdlc_placeholder_check` run twice per quality report |
| Q-04 | Medium | Triplicated edge-case awk block should be extracted to shared helper |
| Q-05 | Medium | `pdlc-review.sh` reimplements task counting inline (misses case-insensitive `[xX]`) |

### Positive Findings

- Observer discipline consistently applied (all lib functions return 0)
- Lazy-sourcing guards prevent double-sourcing throughout
- Awk-only YAML parsing with no yq/grep-pipeline violations
- `PDLC_DISABLED=1` respected across all relevant functions
- 32% comment ratio — well-documented codebase

---

## Dimension 3: Test Quality

**Auditor**: Test Coverage Analysis | **Findings**: 20 (8 High, 8 Medium, 4 Low)

### Coverage Overview

| Layer | Files | Tests | Avg Density |
|-------|-------|-------|-------------|
| Unit | 13 | 281 | 1.5 |
| Integration | 6 | 69 | 1.3 |
| E2E (stub) | 1 | 9 | 2.0 |
| E2E (live) | 1 | 6 | 1.2 |
| **Total** | **21** | **406** | **1.5** |

### Zero-Coverage Functions

| Function | File | Impact |
|----------|------|--------|
| `pdlc_count_tasks` | pdlc-state.sh | **HIGH** — used by outer loop, director, review |
| `pdlc_get_mtime` | pdlc-state.sh | Medium — cross-platform divergence |
| `pdlc_freshness_date_to_epoch` | pdlc-freshness.sh | Medium — macOS/Linux portability |
| `pdlc_xref_extract_ids` | pdlc-xref.sh | Low — tested via wrappers |

### Zero-Coverage Hook Scripts

| Hook | Complexity | Risk |
|------|-----------|------|
| `post-edit-lint.sh` | High (formatter routing, 10+ extensions) | **HIGH** |
| `post-edit-test.sh` | High (framework detection, timeout logic) | **HIGH** |

### Missing Integration Scenarios

| Scenario | Severity |
|----------|----------|
| Director → Actor → Critic full cycle | HIGH |
| Compact → Restore → Continue round-trip | HIGH |
| Critic gate with PASS_WARN values | Medium |
| Stop-check + outer loop interaction | Medium |
| Session persistence across loop iterations | Medium |

### Edge Cases Missing

- `pdlc_set_field` with value containing `:` (colon in URL values)
- Future date producing negative age in freshness calculations
- Signal handling (SIGINT/SIGTERM) in outer loop
- `PDLC_DISABLED` bypass in lifecycle transition and xref check
- CRLF line endings in HANDOFF.md

---

## Dimension 4: Architecture Alignment

**Auditor**: Model-to-Code Cross-Reference | **Findings**: 9 (2 High, 3 Medium, 4 Low)

### Model-to-Code Mapping

All 7 C4 containers and all 9 hook script components have implementations. However, 4 of 14 library modules are completely absent from the C4 model:

| Missing from C4 | Role | Sourced By |
|-----------------|------|------------|
| `pdlc-critic.sh` | Dual-critic consensus engine | pdlc-director.sh (duck-typed) |
| `pdlc-session.sh` | Session checkpoint save/restore | pdlc-director.sh, outer loop |
| `pdlc-test-strategy.sh` | Test strategy for Director prompts | pdlc-director.sh |
| `pdlc-skeptic.sh` | Product Skeptic 5-lens analysis | pdlc-quality.sh |

### Alloy Invariant Compliance

| Status | Count | Details |
|--------|-------|---------|
| Holds | 10 | INV-1, INV-2, INV-5, INV-6, INV-7, INV-9, INV-10, INV-13, INV-14, and HANDOFF single-agent truth |
| Violated | 2 | INV-4 (pre-compact-save.sh is Mutator+Reactor), INV-3 (post-compact-restore.sh deletes state file) |
| Partially Implemented | 2 | INV-12 (only SpecAhead drift, not CodeAhead/Conflict), INV-8/INV-11 (no runtime enforcement) |

### Key Architecture Drift

| ID | Severity | Finding |
|----|----------|---------|
| A-01 | High | 4 library modules absent from C4 model entirely |
| A-02 | High | `pre-compact-save.sh` violates Alloy mutual-exclusivity invariant (Mutator + Reactor) |
| A-03 | Medium | `DISPATCH` and `Annotations` state files in Alloy but never implemented |
| A-04 | Medium | Lifecycle code uses `spec.md`/`plan.md` but docs say `requirements.md`/`design.md` — lifecycle states never trigger for documented workflow |
| A-05 | Medium | Director library has 2 undeclared source dependencies |

---

## Dimension 5: Convention Compliance

**Auditor**: CLAUDE.md Rule Checker | **Findings**: 7 (4 High, 1 Medium, 3 Low)

### Compliance Checklist

| Convention | Status |
|------------|--------|
| Hook scripts exit 0 (ERR trap) | **FAIL** — 2 hooks missing trap |
| Hook scripts use `set -eo pipefail` | **FAIL** — 2 hooks use wrong flags |
| Library scripts use `set -euo pipefail` | PASS |
| Atomic writes (.tmp + mv) | PASS |
| No yq | PASS |
| No grep for YAML parsing | PASS |
| HANDOFF.md flat YAML | PASS |
| Canonical `pdlc_get_field`/`pdlc_set_field` | PASS |
| `substr($0, length(key)+3)` awk pattern | PASS |
| `PDLC_` prefix for env vars | PASS (marginal) |
| `<error-recovery>` XML framing | PASS |
| `PDLC_DISABLED` in blocking hooks | PASS |
| Headers match behavior | **PARTIAL** — 3 gaps |

### Convention Violations

| ID | Severity | File | Description |
|----|----------|------|-------------|
| V1 | **HIGH** | post-edit-lint.sh | `set -uo pipefail` (should be `-eo`) + missing ERR trap |
| V2 | **HIGH** | post-edit-test.sh | `set -uo pipefail` (should be `-eo`) + missing ERR trap |
| V3 | Medium | pdlc-outer-loop.sh | `local` used outside function scope (lines 321–326) |
| V4 | Low | pdlc-director.sh | `PDLC_DIRECTOR_TEST_MODE` undocumented |
| V5 | Low | critic-gate.sh | `PDLC_DISABLED` not mentioned in header |
| V6 | Low | post-edit-lint.sh | Header extension list incomplete |

**18 of 23 files are fully convention-compliant.**

---

## Cross-Cutting Themes

These patterns appear across multiple audit dimensions:

### 1. `post-edit-lint.sh` and `post-edit-test.sh` are systemic weak points
Flagged in **4 of 5 dimensions**: wrong set flags (conventions), missing ERR traps (conventions), zero test coverage (tests), `grep -oP` portability (integration), duplicate `extract_file_path` (quality). These two files need comprehensive remediation.

### 2. The dual-critic subsystem is architecturally present but operationally disconnected
`pdlc-critic.sh` contains the consensus engine described in architecture docs but is: never sourced by the outer loop (integration), missing from the C4 model (architecture), only called by tests (quality). The `batch` field that would drive critic enforcement is never incremented.

### 3. Documentation/code naming divergence creates dead lifecycle paths
The lifecycle inference code checks for `spec.md`/`plan.md` but all documentation describes `requirements.md`/`design.md`. Users following the documented workflow will never trigger the Specified or Planned states.

### 4. Spec-metric extraction is duplicated across 3+ libraries
Edge case counts, acceptance scenario counts, and success criteria counts are implemented independently in `pdlc-critic.sh`, `pdlc-skeptic.sh`, and `pdlc-test-strategy.sh` with identical grep/awk patterns. A shared `pdlc-spec-metrics.sh` helper would eliminate ~40 lines of duplication.

### 5. Dead code accumulation from unused library functions
Several library functions are defined but never called in production: `pdlc_lifecycle_transition`, `pdlc_lifecycle_is`, `pdlc_lifecycle_can_advance`, `pdlc_session_get_checkpoint_field`, `pdlc_critic_report`, `pdlc_review_summary`. These represent intended but unwired architectural capabilities.

---

## Remediation Plan

| Priority | Finding | Severity | Effort | Recommendation |
|----------|---------|----------|--------|----------------|
| **P1** | CriticGate bypassed (batch never incremented) | High | Low | Add `pdlc_set_field "batch" "$((BATCH + 1))"` after critic verdict accepted in outer loop |
| **P2** | Dual-critic consensus unreachable | High | Low | Source `pdlc-critic.sh` from `pdlc-director.sh` or outer loop |
| **P3** | `local` outside function in outer loop | High | Low | Replace `local` with plain variable assignment (3 lines) |
| **P4** | post-edit-lint.sh wrong set flags + missing ERR trap | High | Low | Change `set -uo` → `set -eo pipefail` + add `trap 'exit 0' ERR` |
| **P5** | post-edit-test.sh wrong set flags + missing ERR trap | High | Low | Same fix as P4 |
| **P6** | 4 library modules missing from C4 model | High | Medium | Add `pdlc-critic.sh`, `pdlc-session.sh`, `pdlc-test-strategy.sh`, `pdlc-skeptic.sh` to `components.likec4` |
| **P7** | `pdlc_count_tasks` zero test coverage | High | Low | Add 5–6 BATS tests in `pdlc-state.bats` |
| **P8** | post-edit-lint.sh zero test coverage | High | Medium | Create `tests/integration/post-edit-lint.bats` |
| **P9** | post-edit-test.sh zero test coverage | High | Medium | Create `tests/integration/post-edit-test.bats` |
| **P10** | Lifecycle naming divergence (spec.md vs requirements.md) | Medium | Low | Update `pdlc_lifecycle_infer` to recognize both naming conventions |
| **P11** | pre-compact-save.sh Alloy invariant violation | Medium | Medium | Split into Mutator (HANDOFF write) and Reactor (marker touch), or update Alloy model |
| **P12** | Triplicated edge-case awk block | Medium | Low | Extract `pdlc_spec_count_edge_cases` shared helper |
| **P13** | `pdlc_quality_report` double execution of checks | Medium | Low | Remove direct calls; rely on `pdlc_semantic_validate` |
| **P14** | `pdlc-review.sh` inline task counting | Medium | Low | Replace with `pdlc_count_tasks` call |
| **P15** | `pdlc-state.sh` missing `set -euo pipefail` | Medium | Low | Add `set -euo pipefail` directive |
| **P16** | `PDLC_SOURCE_DIRS` env override broken | Medium | Low | Use string + `read -ra` conversion, or remove override docs |
| **P17** | Director → Actor → Critic integration test missing | High | Medium | Create stub-based integration test for full cycle |
| **P18** | `DISPATCH`/`Annotations` Alloy sigs with no implementation | Medium | Low | Either implement or remove from Alloy model |

**Estimated effort breakdown**: 8 Low-effort fixes (~1 hour), 5 Medium-effort fixes (~4 hours), 5 already-correct areas requiring no change.

---

*Generated by 5 parallel audit agents (integration, quality, tests, architecture, conventions) on 2026-03-18. Individual dimension reports available at `.loki/audit/`.*
