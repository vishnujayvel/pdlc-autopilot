# Agentic Principles: Why PDLC Autopilot Works This Way

A design philosophy document for developers building or extending autonomous AI development pipelines.

---

## 1. The Self-Evaluation Problem

Here is a fact that every developer knows intuitively but rarely articulates: **the person who wrote the code is neurologically the worst person to review it.**

This is not a metaphor. The human brain's prefrontal cortex handles planning and implementation. The anterior cingulate cortex handles error monitoring and conflict detection. These two systems compete for cognitive resources. When you are deep in implementation mode -- holding the architecture in your head, reasoning about edge cases, making tradeoff decisions -- your error-detection circuits are literally suppressed. Your brain is spending its budget on building, not auditing.

This is why code review exists as a practice. Not because the author is incompetent, but because the author's brain is in the wrong mode. A fresh pair of eyes, unburdened by the implementation journey, catches things the author's brain actively filters out.

LLMs have a strikingly similar problem. When a model generates code, its next-token predictions are anchored to its own output. The context window is saturated with the reasoning that led to those decisions. If you then ask "is this correct?" in the same context, you are asking a system to evaluate its own output while surrounded by all the justifications it just produced. The model is statistically more likely to confirm its choices than to find flaws. This is not a bug in the model -- it is a structural property of autoregressive generation. The same weights that produced the code will produce the review.

**The solution is context separation.** The Actor generates code in one context, with a builder's framing: "implement this specification." The Critic evaluates it in a fresh context, with an auditor's framing: "what could fail here?" These are not different prompts in the same conversation. They are different agent invocations with different system prompts, different context windows, and different objectives. The Critic never sees the Actor's reasoning process. It sees only the artifacts.

This is the foundational insight behind the Director/Actor/Critic pattern: **separation of concerns is not just an organizational principle. It is a debiasing technique.**


## 2. Opposing Incentives

If one Critic is good, two Critics with different objectives are substantially better. But the reason is not what you might think.

Consider two framings for the same review task:

**ADVOCATE framing:** "You are reviewing an implementation. Look for evidence that it meets the requirements. Confirm what works well and identify strengths."

**SKEPTIC framing:** "You are auditing an implementation. Look for gaps, edge cases, security issues, and unhandled scenarios. Assume bugs exist until proven otherwise."

These are not just different words. They produce fundamentally different evaluation behaviors. The ADVOCATE's optimistic bias makes it excellent at catching completeness issues -- "Task 3 has no implementation at all" or "the acceptance criteria says X but the code does Y." The SKEPTIC's pessimistic bias makes it excellent at catching robustness issues -- "this handles the happy path but throws on null input" or "there is no timeout on this network call."

**Neither perspective is sufficient alone.** An ADVOCATE-only system is too permissive. It finds reasons to approve and underweights risks. A SKEPTIC-only system is too paranoid. It flags everything, including things that are working correctly, creating so much noise that real issues get lost.

The power comes from the consensus rules:

- **Both pass:** High confidence the implementation is solid. Ship it.
- **Both fail:** High confidence something is wrong. Fix it.
- **They disagree:** This is where it gets interesting. The Director (which has full project context that neither Critic has) reviews both reports and makes a judgment call. Disagreement is signal, not noise -- it means the implementation is in a gray area that benefits from human-level reasoning.

In production use across multiple projects, SKEPTIC caught 5 real issues that ADVOCATE missed entirely. ADVOCATE prevented 3 false positive blocks that SKEPTIC would have raised. The combined system has a better signal-to-noise ratio than either alone.

There is a deeper principle here: **adversarial evaluation is more robust than consensus evaluation.** When two agents with opposing incentives agree, you can trust the result more than when a single agent with one incentive gives the same verdict. This is the same reason legal systems have prosecution and defense, and why red teams exist in security.


## 3. Role Separation as Architecture

A common question: why are Director, Actor, and Critic separate agents instead of sections in one long prompt? The answer involves more than just the debiasing argument from Section 1.

**Context contamination.** When the Actor's implementation details are in the same context as the Critic's evaluation, the Critic's assessment is polluted. It has seen the Actor's reasoning, its tradeoff decisions, its justifications. This makes the Critic more sympathetic and less rigorous. By running the Critic in a completely separate context, it evaluates the code on its own merits, not on the strength of the author's reasoning.

**Differential tool access.** Actors need write tools -- Edit, Write, Bash for running tests. Critics only need read tools -- Read, Grep, Glob. Claude Code does not enforce tool restrictions on subagents today, but the architecture supports it. When tool-level permissions become available, the right security boundary is already in place: Critics physically cannot modify code, so a jailbroken Critic prompt cannot cause damage.

**Parallel execution.** ADVOCATE and SKEPTIC run simultaneously because they are independent agents, not sequential prompts. If they were two sections of one prompt, you would pay the full latency cost of both sequentially. As separate agent invocations, they run in parallel and the Director waits for both to return.

**Failure isolation.** If an Actor crashes mid-implementation (context window exceeded, tool error, rate limit), the Director can re-dispatch that batch without affecting any Critic state. If the Actor and Critic were in one context, a crash means losing the review state too. Separate agents give you the same fault isolation that microservices give you over monoliths -- and for the same reasons.

The architectural insight: **roles are not prompt engineering. They are deployment units.** Each role has its own lifecycle, its own failure modes, and its own scaling characteristics.


## 4. Batching: The Counter-Intuitive Insight

The naive approach to multi-agent implementation is one agent per task. Ten tasks means ten Actors plus ten Critics, which means thirty agent calls (including the Director coordination). This is expensive, slow, and -- counterintuitively -- **produces worse results than fewer agents.**

Here is why. Consider ten tasks spread across three files:

```
File A: tasks 1, 2, 3, 4
File B: tasks 5, 6, 7
File C: tasks 8, 9, 10
```

With per-task agents, Agent-1 implements task 1 in File A. Then Agent-2 opens File A again to implement task 2. It sees Agent-1's changes but does not understand the reasoning behind them. It might restructure something Agent-1 carefully arranged. Agent-3 does the same. By task 4, File A has been opened, modified, and closed four times by four agents that each saw only a fragment of the picture. Integration bugs are almost guaranteed.

With batched agents, one Actor gets all four tasks for File A. It reads the file once, plans all changes together, considers how the tasks interact, handles shared state, gets import ordering right, and produces a cohesive result. One read, one coherent set of changes.

**The unit of work is the file, not the task.** This matches how human developers actually work. You open a file, make all related changes, then move on. You do not open a file, make one change, close it, reopen it for the next change. That workflow would feel absurd to any developer, yet it is exactly what per-task agent dispatch does.

The efficiency numbers are dramatic. Each count below represents a logical dispatch unit: one Actor dispatch or one Critic dispatch. Note that each Critic dispatch internally spawns two subagents (ADVOCATE and SKEPTIC) that run in parallel, so the actual subagent count is higher, but the coordination overhead is captured by the dispatch count.

| Scenario | Per-task dispatches | Batched dispatches | Reduction |
|----------|----------------|----------------|-----------|
| 4 tasks, 1 file | 12 | 2 | 83% |
| 10 tasks, 2 files | 30 | 4 | 87% |
| 10 tasks, 5 files | 30 | 10 | 67% |

But cost reduction is the secondary benefit. The primary benefit is **coherence.** A batched Actor produces better code because it sees the full picture of what needs to happen in each file.

The batching strategy is straightforward: group tasks by their primary file, cap batches at a reasonable size (five tasks), and mark non-overlapping batches for parallel execution. The Director handles this grouping before any Actor is dispatched.


## 5. Composing Claude Code Primitives

PDLC Autopilot has no runtime. No server. No database. No API. Its only dependencies are Claude Code itself and [cc-sdd](https://github.com/gotalab/cc-sdd) for spec generation.

This is not a limitation -- it is the core design decision. The entire system is a SKILL.md file that tells Claude Code how to compose its own primitives into a development pipeline:

| Primitive | Role in PDLC Autopilot |
|-----------|----------------------|
| **Task tool** | Spawns subagent Actors and Critics with isolated contexts |
| **Skill tool** | Invokes Kiro spec generators for requirements, design, and tasks |
| **TeamCreate / SendMessage** | T-Mode parallel execution with file ownership |
| **TaskCreate / TaskUpdate / TaskList** | Shared coordination between parallel teammates |
| **Read / Write / Edit** | File operations delegated to Actors |
| **Bash / Grep / Glob** | Test execution, code search, file discovery |
| **spec.json** (artifact, not a primitive) | Persistent state that survives context loss |

The key insight: **orchestration logic does not need infrastructure.** PDLC Autopilot is pure coordination -- it decides what to do and in what order, then delegates all actual work to Claude Code's built-in capabilities.

This has three consequences that matter in practice:

**Minimal installation friction.** One `npx` command installs the SKILL.md file. There is no Docker container, no persistent server, no runtime environment to configure. The prerequisite is [cc-sdd](https://github.com/gotalab/cc-sdd) for spec generation, also a single `npx` command.

**Automatic model upgrades.** When Claude Code gets faster models or better tool calling, the autopilot benefits immediately without any changes -- the orchestration logic is model-agnostic. However, the SKILL.md file itself is installed as a static file. To pick up new orchestration features or bug fixes, re-run `npx pdlc-autopilot` to update it.

**Portability.** The SKILL.md file works in any project, any language, any framework. It does not parse code or understand syntax. It delegates those concerns to Claude Code, which already handles them.

This is the "composition over construction" principle applied to AI agents. Instead of building agent infrastructure, you compose existing agent capabilities. The result is more maintainable, more portable, and more likely to stay current as the underlying platform evolves.


## 6. Autonomous Execution: The "No Stopping" Principle

Early versions of the autopilot paused between phases to ask the user: "Requirements look good. Should I proceed to design?" Then again: "Design is ready. Should I start implementation?" And again for each batch.

This was well-intentioned and completely wrong.

The pause-and-ask pattern turns an autonomous pipeline into supervised execution with extra steps. The user has to monitor every transition, read every intermediate artifact, and give approval to continue. At that point, they might as well be running each phase manually. The autopilot adds overhead without removing toil.

**The solution is to define clear stopping conditions and run autonomously between them.**

There are exactly four valid reasons for the autopilot to stop and report to the user:

1. **Both ADVOCATE and SKEPTIC fail.** This means both the optimistic and pessimistic reviewers agree the implementation is broken. The system cannot self-correct because it does not know what the user actually wants. Escalate.

2. **Maximum fix cycles exceeded.** After two rounds of "Critic finds issue, Actor fixes, Critic re-reviews," if the implementation still does not pass, something structural is wrong. Continuing to loop will not help. Escalate.

3. **All batches complete.** The work is done. Report the summary.

4. **Product Skeptic issues KILL verdict.** The feature is misaligned with product goals. No amount of implementation quality can fix a wrong direction. Stop immediately.

There is one deliberate pause point that is not a stopping condition: when T-Mode is active, the Director presents parallelization strategy options and waits for the user to select one. Once selected, execution resumes autonomously.

Everything else flows automatically. Phase transitions, batch dispatching, fix cycles, retries after Actor errors -- all automatic. The system tells the user what happened, not asks what to do.

This principle has a name in the autonomy literature: **defined-exception autonomy.** The system operates independently within defined boundaries. It only escalates when it hits a boundary condition it cannot resolve. This is the same model used in self-driving cars (operate normally, escalate on edge cases) and in well-run organizations (make decisions at your level, escalate blockers).

The practical test: if you find the system about to generate the text "Should I proceed?" or "Would you like me to..." -- that is a design flaw. Rephrase it as a stopping condition or remove the pause entirely.


## 7. Product Context as a Forcing Function

A perfectly orchestrated development loop that implements the wrong feature is worse than no automation. It is confidently wrong at scale.

This is the "wrong thing efficiently" problem, and it is the reason product context is mandatory in PDLC Autopilot, not a nice-to-have. Before any code is written, the system requires a `product-context.md` that captures:

- **Product tier** (T0 personal, T1 community, T2 enterprise). This determines how much process rigor to apply. A personal project does not need the same validation depth as an enterprise system.
- **Target users and their needs.** This is the reference point for the Product Skeptic gate -- the check that catches scope creep, gold-plating, and misalignment before they become implementation debt.
- **Success criteria.** What does "done" look like from the user's perspective, not the developer's perspective?

The Product Skeptic is a specific gate that uses product context to evaluate whether the planned work aligns with product goals. It can issue a KILL verdict -- a hard stop that prevents implementation of misaligned features. Without product context, this gate is impossible. There is nothing to evaluate alignment against.

**The cost is trivial: three to seven questions (depending on product tier), two minutes of thought.** The value is permanent. Product context survives across all sessions and all features in the project. It is written once and referenced every time the autopilot runs.

The deeper principle: **automation amplifies direction, good or bad.** If the direction is right, automation accelerates value delivery. If the direction is wrong, automation accelerates waste. Product context is the mechanism for ensuring direction is right before amplification begins.


## 8. Context Health: Treating Specs as Living Documents

Specifications are not written once and frozen. They drift. Requirements from three months ago may not reflect current product direction. Design decisions made before a dependency upgrade may be invalid. A task list written for version 1.0 may not apply to version 1.3.

PDLC Autopilot tracks spec freshness and flags when documents are potentially stale:

| Product Tier | Freshness Threshold |
|-------------|-------------------|
| T0 (personal / hobby) | 90 days |
| T1 (community / internal) | 30 days |
| T2 (enterprise / production) | 14 days |

These are non-blocking warnings, not hard gates. The autopilot does not refuse to run on a stale spec -- it flags the staleness and continues. The retrospective (Section 9) captures whether staleness actually caused problems, feeding back into the freshness model.

The companion mechanism is the **decision log.** Every significant decision during execution -- "chose library X over library Y because of Z," "deviated from design in section 3 because the API changed," "SKEPTIC flagged issue Q but Director overrode because R" -- gets logged to `decision-log.md`. This creates an audit trail that future sessions can reference.

The decision log solves a specific problem: **cross-session amnesia.** When a new session picks up work from a previous session, it has no idea why certain decisions were made. The code exists, but the reasoning is gone. The decision log preserves reasoning alongside artifacts, so future sessions (and future developers) can understand not just what was built but why.

Freshness checks and decision logs together treat specifications as living documents rather than static artifacts. The specs evolve with the project, and the system tracks that evolution explicitly.


## 9. The Retrospective Loop

Every execution path in PDLC Autopilot -- full PDLC, bug fix, iteration -- ends with the same three questions:

1. **What changed?** Actual outcome versus expected -- scope cuts, unexpected complexity, deviations from the plan.
2. **What did we learn?** Reusable insight -- a pattern, a mistake, a broken assumption worth recording.
3. **Should context update?** Does `product-context.md` need changes based on what we discovered?

This is not ceremony. Each answer feeds back into concrete system state:

**Context health updates.** If the retrospective confirms the spec was accurate, freshness timestamps get updated. If the spec was stale and caused problems, that is captured as evidence for tighter freshness thresholds.

**Decision log entries.** New insights from the retrospective ("we discovered that the caching layer needs TTL support, which was not in the original design") become decision log entries that inform future sessions.

**Product context evolution.** If the third question reveals shifted priorities ("we realized feature X is more important than feature Y"), product context gets updated so future runs reflect the new direction.

The retrospective is the mechanism that makes the system learn across runs. Without it, each execution is isolated -- the same mistakes get repeated, the same insights get rediscovered, the same stale specs cause the same problems. With it, each execution builds on the knowledge of previous ones.

There is an important subtlety here: **the retrospective is automated, not interactive.** The system generates retrospective content based on what happened during execution (which batches needed fix cycles, which Critics disagreed, which specs were flagged as stale). The user reviews the output, but the generation is automatic. This keeps the "no stopping" principle intact while still capturing learning.


## 10. Design Principles Summary

| Principle | Implementation | Why It Matters |
|-----------|---------------|----------------|
| Separate who writes from who reviews | Director/Actor/Critic with isolated contexts | Eliminates confirmation bias in self-evaluation |
| Opposing incentives surface more issues | ADVOCATE + SKEPTIC with consensus rules | Adversarial review has better signal-to-noise than single-perspective |
| Batch by file, not by task | Director groups tasks by primary file | Coherent changes, fewer integration bugs, dramatic cost reduction |
| Persist state to survive context loss | spec.json + validation-criteria.md on disk | Long sessions hit context compaction; disk state survives |
| Never ask "should I proceed?" | Autonomous execution with four defined stopping points | Pause-and-ask defeats the purpose of automation |
| Product context before code | Mandatory product-context.md, Product Skeptic gate | Automation amplifies direction -- ensure direction is right first |
| Compose, don't build | Minimal infrastructure -- a SKILL.md file over Claude Code primitives | No runtime dependencies, model upgrades flow through automatically, works everywhere Claude Code works |
| Every run learns | Retrospective feeds decision log and context health | Without feedback loops, the same mistakes repeat across sessions |

---

## Appendix: Frequently Challenged Assumptions

**"Why not just use a longer system prompt instead of multiple agents?"**

Because context window length is not the bottleneck -- cognitive mode is. A single agent with a long prompt containing both "implement this" and "now review what you implemented" is still one agent reviewing its own work. The debiasing comes from context separation, not prompt length.

**"Isn't the Director a single point of failure?"**

Yes, and that is intentional. The Director is the one role that should have full context -- it sees the spec, the batch plan, both Critic reports, and the project state. Distributing this coordination would create consistency problems that are harder to solve than single-point-of-failure problems. The mitigation is state persistence: if the Director crashes, a new Director can read spec.json and resume.

**"Why two Critics and not three or five?"**

Diminishing returns. Two opposing perspectives (optimistic and pessimistic) cover the primary failure modes: missing functionality and missing robustness. A third perspective would need a clearly differentiated objective to justify its cost. If we identified one (security-focused, performance-focused), it could be added -- but two has proven sufficient across every project we have tested.

**"Does batching ever produce worse results?"**

When tasks in a batch have genuinely conflicting requirements, a single Actor may struggle to satisfy both. This is rare in practice because conflicting requirements are usually caught during spec validation (Phase 0b). If it happens, the Critic will flag the conflict and the Director can split the batch.

**"What about non-code artifacts? Can this work for documentation, design, infrastructure?"**

The Director/Actor/Critic pattern is agnostic to artifact type. The Actor implements, the Critic reviews. Whether "implements" means writing TypeScript or writing Terraform or writing documentation, the orchestration is identical. The ADVOCATE/SKEPTIC framing works for any artifact that has success criteria.
