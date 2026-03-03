# Product Context Template

**What:** Template for `{project}/.claude/product-context.md` — a project-level file shared across all features.

**MANDATORY:** If this file doesn't exist when PDLC Autopilot is invoked, Phase P0 runs FIRST to create it. No SDLC work starts without product context.

**Where it lives:** `{project}/.claude/product-context.md` (NOT in the spec directory — it's project-wide)

---

## Audience Tier

Every product gets a tier that determines the DEPTH of each section, not WHETHER the section exists:

| Tier | Audience | Depth | Example |
|------|----------|-------|---------|
| **Tier 0: Personal** | Just me / internal tool | 1-line answers OK for most sections | hookwise, fitbit-analytics |
| **Tier 1: Community** | OSS users, team members | Full paragraphs, comparison table expected | practice-tracker, obsidian-para-tools |
| **Tier 2: Enterprise** | Paying customers, broad public | Comprehensive with metrics and formal analysis | SaaS products |

---

## Phase P0: Generation Protocol

**When:** product-context.md doesn't exist for the project.

**Director instructions:**

```
1. ASK user: "What audience tier is this product?"
   - Tier 0: Personal/internal tool
   - Tier 1: Community/OSS
   - Tier 2: Enterprise/public

2. ASK targeted questions based on tier:

   ALL TIERS:
   - "What problem does this solve? Who has this problem?"
   - "What's the ONE thing this must do well in V1?"

   TIER 1+ additionally:
   - "Who are 2-3 alternatives? Why would someone pick yours?"
   - "What would make you STOP working on this?"

   TIER 2 additionally:
   - "What metrics define success? (adoption, retention, revenue)"
   - "What's your go-to-market motion?"

3. WRITE product-context.md using the template below

4. SHOW the generated file to user for confirmation

5. PROCEED to Phase 0a (spec generation)
```

---

## Template

The Director writes this file at `{project}/.claude/product-context.md`:

```markdown
# Product Context: [Product Name]
<!-- last_reviewed: YYYY-MM-DD -->
<!-- reviewed_by: user -->

## Core Thesis & Problem
<!-- ALL TIERS: Always substantive. What pain does this solve? -->

**Problem:** [1-3 sentences describing the pain point]

**Thesis:** [1 sentence — "We believe [audience] needs [solution] because [reason]"]

## Audience & Maturity Tier

**Tier:** [0 Personal | 1 Community | 2 Enterprise]

**Primary persona:** [Who is this for? Be specific.]
<!-- Tier 0: "Me" is valid -->
<!-- Tier 1+: Name the persona (e.g., "Solo devs who use Claude Code daily") -->

**Current maturity:** [Idea | MVP | Growing | Mature]

## MVP Scope & Hydration Roadmap

### V1 Core (must ship)
<!-- ALL TIERS: What's the minimum that delivers the core thesis? -->
- [Feature 1 — the ONE thing]
- [Feature 2]
- [Feature 3]

### Layer 2 (next iteration)
<!-- Tier 0: Can be empty or "TBD" -->
<!-- Tier 1+: 3-5 concrete features -->
- [Feature]

### Layer 3 (future / maybe never)
<!-- Tier 0: Can be "N/A" -->
<!-- Tier 1+: Aspirational features that should NOT creep into V1 -->
- [Feature]

## Feature Philosophy
<!-- ALL TIERS: Pre-filled defaults, customize as needed -->

**Defaults (override per product):**
- Depth over breadth: Do fewer things, do them completely
- Convention over configuration: Smart defaults, escape hatches for power users
- Source code is truth: Docs generated from code, not maintained separately
- Deterministic over probabilistic: Prefer exact computation over LLM estimation

**Product-specific principles:**
- [Principle 1]
<!-- Tier 0: 1-2 informal principles -->
<!-- Tier 1+: 3-5 formal principles -->

## Kill Criteria
<!-- When should you STOP building this? -->

<!-- Tier 0: "none" or "when I stop using it" is valid -->
<!-- Tier 1+: Specific conditions -->

- [Condition that means this product should be abandoned or pivoted]
- [e.g., "If no external users after 3 months of being public"]
- [e.g., "If maintaining this costs more than the problem it solves"]

## Competitive Positioning
<!-- Tier 0: "N/A — personal tool" is valid -->
<!-- Tier 1+: Fill in comparison table -->

| Dimension | This Product | Alternative A | Alternative B |
|-----------|-------------|---------------|---------------|
| Core strength | | | |
| Weakness | | | |
| Price | | | |
| Target user | | | |

**Why pick this over alternatives:** [1-2 sentences]

## Product Principles
<!-- Guiding principles for ALL product decisions -->

<!-- Tier 0: 1-2 informal, e.g., "Keep it simple, keep it fast" -->
<!-- Tier 1+: 3-5 formal principles with rationale -->

1. **[Principle]** — [Why this matters]
2. **[Principle]** — [Why this matters]

## Decision History

See `{project}/.claude/decision-log.md` for the full append-only log of product decisions made during PDLC cycles.

Key decisions are logged when:
- Product Skeptic issues SCOPE or KILL verdicts
- Retrospectives surface reusable learnings
- Assumptions break during implementation
- Scope drift is detected and resolved
```

---

## cc-sdd Bridge (Optional)

If the project uses Kiro/cc-sdd, the Director can auto-populate `.kiro/steering/product.md` from product-context.md:

```
Mapping:
  product-context.md "Core Thesis & Problem"    → product.md "Product Overview"
  product-context.md "Audience & Maturity Tier"  → product.md "Target Users"
  product-context.md "MVP Scope" V1 Core         → product.md "Core Features"
  product-context.md "Feature Philosophy"         → product.md "Design Principles"
```

This is one-way: product-context.md is the source of truth. If cc-sdd steering already exists, the Director compares and flags discrepancies rather than overwriting.

---

## Validation

A valid product-context.md:
- Has ALL 8 sections present (even if some say "N/A" for Tier 0)
- Has a declared tier (0, 1, or 2)
- Has at least 1 V1 Core feature
- "Core Thesis & Problem" is never empty — even personal tools solve a problem
- Has `<!-- last_reviewed: YYYY-MM-DD -->` comment (added on generation, updated on review)
- Has `<!-- reviewed_by: user|retrospective -->` comment
