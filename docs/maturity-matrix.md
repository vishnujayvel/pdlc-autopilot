# PDLC Autopilot — Maturity Matrix

> Tracks the enforcement level of every documented PDLC capability.
> Updated as features move from guidance to enforcement.

## Legend

| Level | Meaning | Description |
|-------|---------|-------------|
| **Enforced** | Hook/code blocks violations | Feature has a working hook or code gate that prevents bypass |
| **Tested** | Verified by BATS tests | Feature has automated tests but no enforcement hook |
| **Guidance** | LLM prompt only | Feature relies on SKILL.md instructions; no code enforcement |
| **Aspirational** | Documented, not implemented | Feature is described in docs but has no implementation |

## Matrix

| # | Capability | Source | Level | Hook/File | Version |
|---|-----------|--------|-------|-----------|---------|
| 1 | SpecGate (block spec gen via Task) | hooks/spec-gate.sh | **Enforced** | spec-gate.sh | v1.0.0 |
| 2 | CriticGate (block Actor without critic review) | hooks/critic-gate.sh | **Enforced** | critic-gate.sh | v1.0.0 |
| 3 | Stop Guard (block exit with pending tasks) | hooks/pdlc-stop-check.sh | **Enforced** | pdlc-stop-check.sh | v1.0.0 |
| 4 | Session state restore (compaction survival) | hooks/pre-compact-save.sh, post-compact-restore.sh | **Enforced** | pre/post-compact hooks | v1.0.0 |
| 5 | Session init (HANDOFF.md injection) | hooks/session-init.sh | **Enforced** | session-init.sh | v1.0.0 |
| 6 | Post-edit formatting | hooks/post-edit-lint.sh | **Enforced** | post-edit-lint.sh | v1.1.0 |
| 7 | Post-edit test runner | hooks/post-edit-test.sh | **Enforced** | post-edit-test.sh | v1.1.0 |
| 8 | Stop hook staleness awareness | hooks/pdlc-stop-check.sh | **Enforced** | pdlc-stop-check.sh | v1.1.1 |
| 9 | Resource governance (signal cleanup) | hooks/pdlc-outer-loop.sh | **Enforced** | pdlc-outer-loop.sh | v1.1.1 |
| 10 | Constitution (architectural tenets) | .specify/memory/constitution.md | **Enforced** | Spec Kit | v1.1.1 |
| 11 | Outer loop orchestration (Director-driven) | hooks/pdlc-outer-loop.sh, hooks/lib/pdlc-director.sh | **Tested** | 27 Director + 9 outer-loop tests | v1.2.0 |
| 12 | HANDOFF.md state persistence | hooks/lib/pdlc-state.sh | **Tested** | pdlc-state.sh | v1.0.0 |
| 13 | Dual-perspective validation (ADVOCATE + SKEPTIC) | SKILL.md | Guidance | — | — |
| 14 | Product Skeptic (5-lens analysis) | hooks/lib/pdlc-skeptic.sh | **Tested** | 23 BATS tests | v1.2.0 |
| 15 | T-Mode parallel strategies (S1-S5) | SKILL.md, ref/t-mode-strategies.md | Guidance | — | v3.0.0 |
| 16 | Phase visualization | SKILL.md, ref/phase-viz.md | Guidance | — | v1.3.0 |
| 17 | Context freshness checks | hooks/lib/pdlc-freshness.sh | **Tested** | 11 BATS tests | v1.2.0 |
| 18 | Decision logging | SKILL.md, ref/context-health.md | Guidance | — | v2.0.0 |
| 19 | Three workflow paths (Full/Bug/Iteration) | SKILL.md, ref/lightweight-paths.md | Guidance | — | — |
| 20 | Product Context (Phase P0) | SKILL.md, ref/product-context-template.md | Guidance | — | — |
| 21 | Task batching by file ownership | SKILL.md | Guidance | — | — |
| 22 | Max 2 fix cycles per batch | SKILL.md | Guidance | — | — |
| 23 | Test Strategy Research (Phase 0.75) | SKILL.md, ref/test-strategy.md | Guidance | — | v1.2.0 |
| 24 | PR Review Cycle (Phase 5) | SKILL.md, ref/pr-review-cycle.md | Guidance | — | v1.2.0 |
| 25 | Architecture constraint extraction (ARCH-*) | SKILL.md | Guidance | — | v1.2.0 |
| 26 | Session persistence (progress.md / validation-criteria.md) | SKILL.md, ref/session-persistence.md | Guidance | — | — |
| 27 | Spec lifecycle states | hooks/lib/pdlc-lifecycle.sh | **Tested** | 29 BATS tests | v1.2.0 |
| 28 | Placeholder detection | hooks/lib/pdlc-placeholder.sh | **Tested** | 15 BATS tests | v1.2.0 |
| 29 | Cross-reference consistency | hooks/lib/pdlc-xref.sh | **Tested** | 13 BATS tests | v1.2.0 |
| 30 | Structural lint + semantic validation | hooks/lib/pdlc-lint.sh, hooks/lib/pdlc-semantic.sh | **Tested** | 12 BATS tests | v1.2.0 |
| 31 | CLI (status/list/inspect/archive) | src/cli.ts (install-only) | Aspirational | — | v1.3.0 |
| 32 | Mode awareness (pdlc/normal/paused) | — | Aspirational | — | v2.1.0 |
| 33 | Multi-agent dispatcher | — | Aspirational | — | v3.0.0 |
| 34 | Agent adapters (Claude/Gemini) | — | Aspirational | — | v3.0.0 |
| 35 | Worktree manager | — | Aspirational | — | v3.0.0 |
| 36 | Cross-model adversarial critics | — | Aspirational | — | v3.0.0 |
| 37 | Steering file split | — | Aspirational | — | v2.0.0 |
| 38 | ADR directory | — | Aspirational | — | v2.0.0 |
| 39 | Formal architecture verification (Alloy) | formal/pdlc-primitives.als | **Tested** | 14 invariant checks | v1.1.1 |

## Summary

| Level | Count | Percentage |
|-------|-------|------------|
| Enforced | 10 | 26% |
| Tested | 9 | 23% |
| Guidance | 12 | 31% |
| Aspirational | 8 | 21% |
| **Total** | **39** | **100%** |

## Roadmap

Prioritized implementation order. Each item is a candidate for a Spec Kit feature cycle
(`/speckit.specify` → plan → tasks → implement). Revisit ordering after each completion.

| Order | Rows | Theme | Rationale |
|-------|------|-------|-----------|
| **R1** | 27, 28, 29 | Spec lifecycle enforcement | ✅ DONE. Alloy-verified state machine implemented as code. 63 new tests. |
| **R2** | 11, 27 | Director + lifecycle orchestration | ✅ DONE. LLM-driven Director: infer → decide → dispatch → evaluate. 36 new tests. |
| **R3** | 17 | Context freshness checks | ✅ DONE. Spec-embedded dates + mtime fallback for staleness detection. 11 new tests. Rework pending: switch from mtime to date fields. |
| **R4** | 30 | Structural lint + semantic validation | ✅ DONE. Two-layer quality: rumdl wrapper + LLM semantic checks. 12 new tests. |
| **R5** | — | C4 architecture model (LikeC4) | Formal C4 model with native MCP server. Replaces original ARCH-* extraction. Director queries architecture for dispatch decisions. |
| **R6** | 14 | Product Skeptic enforcement | Move 5-lens analysis from prompt-only to code-enforced. Higher effort, high value. |
| **R7** | 23, 24 | Test strategy + PR review cycle | Phase 0.75 and Phase 5 workflows. Currently guidance-only. |
| **R8** | 13 | Dual-perspective validation | ADVOCATE + SKEPTIC pattern. Requires Product Skeptic (R6) first. |
| **R9** | 26 | Session persistence hardening | progress.md / validation-criteria.md. Currently guidance-only. |
| **R10** | 18, 37, 38 | Decision logging, steering split, ADR | v2.0.0 scope. Architectural decisions infrastructure. |
| **R11** | 31, 16, 32 | CLI, phase visualization, mode awareness | v1.3.0-v2.1.0 scope. User-facing tooling. |
| **R12** | 33, 34, 35, 36 | Multi-agent, adapters, worktrees, adversarial critics | v3.0.0 scope. Major architecture expansion. |
| **R13** | — | Delta-merge (spec promotion) | OpenSpec-style: promote working spec findings into canonical docs on feature completion. New capability, not in matrix yet. |

Items without version targets (rows 19-22) are stable guidance — promote opportunistically when touched.

## Changelog

- **v1.2.0** — Row 14 promoted from Guidance to Tested: Product Skeptic 5-lens analysis (23 tests). Rows 27-29 promoted from Aspirational to Tested: spec lifecycle states (29 tests), placeholder detection (15 tests), cross-reference consistency (13 tests). 10 enforced, 9 tested, 12 guidance, 8 aspirational.
- **v1.1.1** — Added row 39: formal architecture verification via Alloy (14 invariant checks, all pass). 10 enforced, 3 tested, 14 guidance, 12 aspirational.
- **v1.1.1** — Initial published audit. Rows 8-10 promoted from Aspirational to Enforced (staleness, signal cleanup, constitution). 10 enforced, 2 tested, 14 guidance, 12 aspirational.
