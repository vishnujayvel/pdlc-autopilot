# Agentic CLI Topology

> Architectural reference for how PDLC Autopilot's components map to
> the layers of an agentic CLI system. Uses Kubernetes as a shared
> mental model for infrastructure, scheduling, and orchestration
> concepts.

## The Stack

An agentic CLI system has 8 distinct layers. Each layer has a clear
responsibility and well-defined interfaces to adjacent layers.

| # | Layer | Concern | Kubernetes Analogy |
|---|-------|---------|-------------------|
| 1 | **Infrastructure** | Models, runtimes, compute providers | Nodes, container runtime |
| 2 | **Scheduling** | Model selection, resource allocation, token budgets | Scheduler, resource quotas |
| 3 | **Orchestration** | Multi-agent dispatch, session lifecycle, pipeline chaining | Controllers, Deployments |
| 4 | **Networking** | Agent-to-agent communication, state passing | Services, ConfigMaps |
| 5 | **Capability** | Skills, tools, MCP servers | Containers, images |
| 6 | **Knowledge** | Context, specs, constitution, steering files | ConfigMaps, Secrets |
| 7 | **Enforcement** | Gates, guards, circuit breakers, cost limits | Admission Controllers, NetworkPolicy |
| 8 | **Observability** | Cost tracking, progress, health, telemetry | Prometheus, logging |

## Kubernetes Mapping (Detailed)

```
Kubernetes                    PDLC Equivalent                        Status
───────────────────────────────────────────────────────────────────────────────
Pod                           Agent session (ephemeral)               Working
Deployment / ReplicaSet       Actor pool (PDLC_MAX_PARALLEL)          Partial (=1)
Service                       Skill interface (/speckit.*)            Working
ConfigMap                     Constitution, CLAUDE.md, specs          Working
Secret                        API keys, .envrc                        Working
Admission Controller          SpecGate, CriticGate hooks              Working
NetworkPolicy                 Stop Guard, circuit breakers            Working
Controller (reconcile loop)   pdlc-outer-loop.sh                     Working
Scheduler                     Model selector                         Not built
PV / PVC                      HANDOFF.md (single-agent state)         Working
StatefulSet                   DISPATCH.md (multi-agent state)         Aspirational
Node                          LLM provider (Anthropic, Google, etc.)  Single-provider
CronJob                       /loop skill (recurring tasks)           Working
Job                           Single skill invocation                 Working
Namespace                     Git worktree (isolation boundary)       Aspirational
Ingress                       MCP server interfaces                   Working
```

## Layer Details

### Layer 1: Infrastructure

**What it is**: The compute substrate — which LLM providers are
available, what models they offer, and how sessions connect to them.

**Current state**: Single-provider (Anthropic), single-model per
session (whatever Claude Code defaults to). No model selection logic.

**Questions this layer answers**:
- Which LLM providers are available?
- What are the rate limits and pricing per model?
- How are API keys managed and rotated?
- What's the fallback when a provider is down?

**PDLC roadmap**: Phase 5 (Multi-Agent v3.0.0) introduces agent
adapters for Claude, Gemini, and others. Each adapter is ~100 lines
and handles the provider-specific last mile.

### Layer 2: Scheduling

**What it is**: The decision logic for which model handles which task.
Not every task needs the most expensive model.

**Current state**: No scheduling. Every task uses whatever model the
session was started with.

**Ideal state**:
- **Opus** for planning, critics, and architectural decisions
- **Sonnet** for implementation (Actor work)
- **Haiku** for validation checks, linting, simple assertions
- Cost-aware routing: if budget is 80% consumed, downgrade to cheaper
  models for remaining work

**Questions this layer answers**:
- Which model should handle this specific task?
- What's the token budget per agent/feature?
- When should we downgrade model tier to stay within budget?
- How do we balance quality vs. cost vs. speed?

**PDLC roadmap**: Phase 4 (Mode Awareness v2.1.0) introduces routing
logic. Phase 5 adds cross-model adversarial critics (e.g., Claude
critic vs. Gemini critic for higher-quality review).

### Layer 3: Orchestration

**What it is**: How work flows between agents and skills. This
includes pipeline chaining (specify → plan → tasks → implement),
multi-agent dispatch (parallel actors), and session lifecycle
management (outer loop).

**Current state**: Working. The Director-driven outer loop implements
a 5-layer orchestration model:

```
┌─────────────────────────────────────────────┐
│ Layer 1: State Inference (shell)            │
│   pdlc_lifecycle_infer() → 7-state machine │
├─────────────────────────────────────────────┤
│ Layer 2: Director (LLM judgment)            │
│   Assess → Decide action + dispatch mode    │
├─────────────────────────────────────────────┤
│ Layer 3: Actor (LLM, same or spawned)       │
│   Executes the Director's crafted prompt    │
├─────────────────────────────────────────────┤
│ Layer 4: Critic (LLM)                       │
│   ADVOCATE + SKEPTIC dual review            │
├─────────────────────────────────────────────┤
│ Layer 5: Hooks (shell)                      │
│   SpecGate, CriticGate, Stop Guard          │
└─────────────────────────────────────────────┘
```

**Key components**:
- **Lifecycle inference**: `pdlc_lifecycle_infer(spec_dir)` derives
  state from artifact presence (Draft→Specified→Planned→Tasked→
  Implementing→Complete→Archived). No explicit transitions needed.
- **Director**: LLM reasoning step that reads inferred state +
  artifacts, produces a dispatch decision (action + mode + rationale
  + actor prompt). Falls back to deterministic state-to-action
  mapping when LLM is unavailable.
- **Dispatch modes**: Same-session (lightweight phases) or spawn
  (new `claude -p` for heavy implementation). The Director assesses
  complexity — this is LLM judgment, not a deterministic lookup.
- **Critic evaluation**: Director evaluates ADVOCATE/SKEPTIC
  feedback and decides accept, retry (with amended instructions),
  or escalate (to user, exit code 3).

**PDLC roadmap**: Phase 5 adds DISPATCH.md for multi-agent
coordination graphs and parallel Actor dispatch.

### Layer 4: Networking

**What it is**: How agents communicate. In single-agent systems, this
is state files. In multi-agent systems, this is coordination
protocols.

**Current state**: HANDOFF.md (flat YAML frontmatter + markdown body)
is the single-agent state passing mechanism. Read by `session-init.sh`
at session start, written by `pre-compact-save.sh` before compaction,
updated by the outer loop between sessions.

**Multi-agent (aspirational)**: DISPATCH.md would be a coordination
graph — which agent is working on which batch, what's the consensus
state, where are blocking dependencies.

**Questions this layer answers**:
- How do agents share context across sessions?
- How do parallel agents avoid conflicting writes?
- What's the consensus protocol when critics disagree?
- How is partial progress preserved on interruption?

**PDLC roadmap**: Phase 5 introduces DISPATCH.md and consensus
protocols.

### Layer 5: Capability

**What it is**: What an agent can actually do — the skills, tools,
and MCP servers available to it.

**Current state**: Working.
- **Skills**: Spec Kit commands (9), PDLC skills, custom user skills
- **Tools**: Claude Code built-in (Bash, Edit, Read, Write, Grep,
  Glob, Agent)
- **MCP servers**: Extensible tool surface (GitHub, Obsidian, etc.)

**Questions this layer answers**:
- What skills are available for this task?
- What tools does the agent need access to?
- Are there MCP servers that provide domain-specific capabilities?

### Layer 6: Knowledge

**What it is**: The context an agent operates with — what it knows
about the project, the architecture, the conventions, and the current
state of work.

**Current state**: Working. Maps to the 4-layer context stack:

| Context Layer | Scope | Examples |
|--------------|-------|---------|
| Library | Ecosystem-wide | Context Hub (opt-in), API docs |
| Steering | Project-wide | CLAUDE.md, constitution, AGENTS.md |
| Spec | Per-feature | spec.md, plan.md, tasks.md |
| Engine | Runtime | HANDOFF.md, hooks, state files |

**PDLC roadmap**: Phase 1 (Enforcement Reality v1.2.0) adds context
freshness checks. Phase 3 adds steering file split for cleaner
separation.

### Layer 7: Enforcement

**What it is**: Constraints that prevent agents from violating
architectural rules, process requirements, or budget limits.

**Current state**: Working. 10 enforced capabilities across 5 hook
categories:

| Category | Behavior | Examples |
|----------|----------|---------|
| Gate | Block operations, read-only | SpecGate, CriticGate |
| Guard | Warn or block on thresholds | Stop Guard |
| Observer | Inject context, never block | session-init, post-compact-restore |
| Mutator | Write state as side effect | pre-compact-save |
| Reactor | External side effects, no state writes | post-edit-lint, post-edit-test |

**Key principle**: Fail closed on spend, fail open on everything else
(constitution R1).

### Layer 8: Observability

**What it is**: Visibility into what agents are doing, how much
they're spending, and whether they're making progress.

**Current state**: Partial.
- **Cost tracking**: Circuit breaker at $50 default, 80% warning
- **Progress detection**: `git diff --stat HEAD` after each session
- **No-progress detection**: Counter incremented when no git changes

**Gaps**:
- No per-feature cost breakdown
- No token-level telemetry
- No dashboard or visualization
- No alerting beyond circuit breaker termination

**PDLC roadmap**: Phase 2 (CLI & Visibility v1.3.0) adds
`pdlc status` with spend visibility. Phase 4 adds mode-aware
reporting.

## Evolution Roadmap Alignment

Each PDLC evolution phase builds specific layers of this topology:

| Phase | Version | Primary Layers | Status |
|-------|---------|---------------|--------|
| 0a Formal Verification | v1.1.1 | Knowledge (Alloy architecture verification) | Done |
| R1 Lifecycle Enforcement | v1.2.0 | Enforcement (lifecycle, placeholders, xref) | Done |
| R2 Director Orchestration | v1.2.0 | Orchestration (Director-driven outer loop) | Done |
| R3 Context Freshness | v1.2.0 | Knowledge (freshness checks) | Next |
| R4 Markdownlint | v1.2.0 | Enforcement (quality gates) | Queued |
| R5 Architecture Constraints | v1.2.0 | Knowledge (ARCH-* extraction) | Queued |
| R6-R9 | v1.3.0-2.0.0 | Enforcement, Observability, Knowledge | Queued |
| R10 CLI & Visibility | v1.3.0 | Observability (CLI, status, spend) | Queued |
| R11-R12 | v2.1.0-3.0.0 | Scheduling, Infrastructure, Networking | Future |

## Design Principles

1. **Build bottom-up**: Lower layers must be solid before upper layers
   can work. You can't schedule across models (Layer 2) without model
   adapters (Layer 1). You can't dispatch agents (Layer 3) without
   state passing (Layer 4).

2. **Each layer is independently testable**: Enforcement works without
   orchestration. Knowledge works without scheduling. This is why
   formal verification (Phase 0a) validates the architecture before
   implementation phases build on it.

3. **Layers communicate through text files**: Constitution tenet E2
   (Text Files Are the Database). HANDOFF.md, DISPATCH.md, specs,
   CLAUDE.md — all plain text, all inspectable with `cat`, all
   versionable with `git`.

4. **Enforcement degrades gracefully**: Constitution tenet X5. When a
   layer is missing, the system continues with reduced capability.
   No multi-agent dispatch? Run single-agent. No model scheduler?
   Use the default model. No cost tracking? Warn and proceed.
