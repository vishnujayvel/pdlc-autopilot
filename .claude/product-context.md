<!-- last_reviewed: 2026-03-05 -->
<!-- tier: T0-daily -->
<!-- review_cycle: 1d -->

# Product Context: PDLC Autopilot

## What Is This?

PDLC Autopilot is an autonomous product development lifecycle orchestrator for Claude Code. It wraps the SDLC loop (specs, implementation, validation) with product phases — product context before specs, docs/demos after implementation. It uses a Director/Actor/Critic pattern where separate agents write code, review it, and orchestrate the flow.

## Who Is It For?

- **Primary user**: Solo developer (Vishnu) using Claude Code for all development work
- **Secondary audience**: Open-source developers who want structured AI-assisted development
- **Distribution**: npm package (`pdlc-autopilot`), installed via `npx cc-sdd@latest --claude`

## Core Value Proposition

"You set the direction. The machine handles the rest." — Automates the boring, disciplined parts of product development (specs, validation, fix cycles) while keeping the human in the loop for direction and judgment.

## Key Design Principles

1. **The agent that writes code should never review it** — Director/Actor/Critic separation with opposing incentives
2. **Spec-driven development** — Requirements before design, design before tasks, product context before requirements
3. **Batch by file** — Group tasks touching the same files into one Actor dispatch (77-87% agent overhead reduction)
4. **Session persistence** — State survives context compaction via progress.md, validation-criteria.md, CLAUDE.md
5. **Process constraints are enforced, not suggested** — SpecGate (Kiro skills mandatory for specs), CriticGate (critics mandatory per batch)

## Architecture

- **Skills-based**: Installed as Claude Code skills in `~/.claude/skills/` or project `.claude/skills/`
- **Kiro integration**: Uses cc-sdd (Kiro) for structured spec generation and validation
- **Subagent orchestration**: Task tool for Actor/Critic dispatch, Skill tool for Kiro invocations
- **T-Mode**: 5 parallelization strategies for team-based execution (experimental)

## Current State (v3.6)

- Core PDLC loop is stable and actively used
- Backlog implementation branch active (`pdlc/v3.6-backlog-implementation`)
- Key gap: **Session continuity** — context compaction breaks PDLC state; no outer loop; hooks not implemented
- Key gap: **Process enforcement** — SpecGate/CriticGate are documented but not hook-enforced

## What Success Looks Like

- PDLC can run multi-batch implementations without human intervention
- Context compaction doesn't lose progress or process state
- Process constraints are enforced automatically (not just documented)
- Outer loop can cycle fresh sessions per batch, avoiding compaction entirely

## Competitive Landscape

| Tool | Approach | PDLC Differentiator |
|------|----------|-------------------|
| Cursor | IDE-integrated AI | PDLC is CLI-native, process-heavy |
| Aider | Git-aware coding | PDLC adds product context + validation |
| Cline | VSCode agent | PDLC has Director/Actor/Critic separation |
| Devin | Full autonomous | PDLC keeps human in loop with gates |
| Continue | IDE copilot | PDLC is lifecycle-oriented, not completion-oriented |

## Technical Constraints

- Claude Code hook API is unstable (7 to 18 events in ~6 months)
- SessionStart[compact] is broken (Bug #15174) — additionalContext silently dropped
- PreCompact cannot block compaction; stdout is ignored
- Hook timeouts default to 60s
