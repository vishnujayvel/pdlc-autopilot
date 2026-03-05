# Docs & Launch Phases (P2 + P3)

**Opt-in phases** that run AFTER Final validation passes. These are NOT automatic — they run when the user says "document this" or "launch prep."

---

## When to Run

| Trigger | Phase |
|---------|-------|
| "document this feature" | P2: Document |
| "write docs for this" | P2: Document |
| "launch prep" | P2 + P3: Document + Demo & Package |
| "demo script" | P3: Demo & Package |
| "create README" | P3: Demo & Package |
| After Final validation (if user opts in) | P2 → P3 sequential |

**Prerequisites:** Final validation MUST pass before P2/P3. These phases generate artifacts from IMPLEMENTED code, not from specs.

---

## Phase P2: Document

### Purpose
Generate documentation from actual source code. Every claim in the docs must reference a real `file:line` in the codebase.

### Flow

```text
DevRel Actor → Docs Critic → Fix cycle (max 2) → Docs complete
```

### DevRel Actor Template

```yaml
Task tool (general-purpose):
  description: "DevRel Actor: generate docs for [feature]"
  prompt: |
    You are the DevRel Actor — a technical writer who generates documentation
    from SOURCE CODE, not from specs or memory.

    ## Product Context
    {product_context_full}

    ## Spec Reference
    - Requirements: [summary of FR-* requirements]
    - Feature name: [name]

    ## Your Mission
    Generate documentation for this feature by reading the ACTUAL CODE.

    ## Rules (CRITICAL)
    1. Every API, config option, or behavior you document MUST exist in the codebase
    2. Every claim must be backed by a file:line reference
    3. If you can't find it in the code, DON'T document it
    4. Use product-context.md to frame the docs for the right audience tier
    5. Code examples must be runnable (test them if possible)

    ## Output Structure (adapt to audience tier)

    ### Tier 0 (Personal)
    - Quick-start snippet (how to use it)
    - Config options (if any)
    - Known limitations

    ### Tier 1 (Community)
    - Getting started guide
    - API reference (from actual exports/endpoints)
    - Configuration reference
    - Examples with expected output
    - Troubleshooting FAQ

    ### Tier 2 (Enterprise)
    - All of Tier 1, plus:
    - Architecture overview
    - Security considerations
    - Performance characteristics
    - Migration guide (if applicable)

    ## Format
    Write as markdown. Include file:line citations inline:
        The `transform()` function accepts... (src/transform.ts:42)

    ## Deliverables
    1. Documentation content (markdown)
    2. Citation index: every claim mapped to file:line
    3. Gaps found: features in code with no obvious docs angle
```

### Docs Critic Template

```yaml
Task tool (general-purpose):
  description: "Docs Critic: verify docs for [feature]"
  prompt: |
    You are the Docs Critic — your job is to find HALLUCINATIONS in documentation.

    A hallucination is: any documented API, option, behavior, or claim that
    does NOT exist in the actual codebase.

    ## Documentation Under Review
    {devrel_actor_output}

    ## Instructions
    1. For EACH file:line citation in the docs:
       - Read the actual file at that line
       - Verify the claim matches reality
       - Flag mismatches

    2. For EACH API/function/config documented:
       - Search the codebase for it
       - Verify it exists and works as described
       - Flag phantom APIs (documented but don't exist)

    3. For EACH code example:
       - Verify it would actually work
       - Check imports, function signatures, return types

    ## Report Format
    - ✅ VERIFIED: [claim] — confirmed at [file:line]
    - ❌ HALLUCINATION: [claim] — [what actually exists / doesn't exist]
    - ⚠️ STALE: [claim] — exists but behavior differs from docs
    - 📊 Coverage: [X/Y claims verified, Z hallucinations found]

    ## Verdict
    - PASS: 0 hallucinations, all citations verified
    - FAIL: [N] hallucinations found — list each with correction
```

### Fix Cycle
1. DevRel Actor generates docs
2. Docs Critic reviews — if FAIL, returns specific hallucinations
3. DevRel Actor fixes ONLY the flagged issues (max 2 cycles)
4. If still failing after 2 cycles → report to user with remaining issues

---

## Phase P3: Demo & Package

### Purpose
Create launch-ready artifacts: demo scripts, comparison matrices, README updates, and packaging.

### Flow

```text
Demo Actor → Director validation (run demo + spot-check) → Fix cycle (max 2) → Launch artifacts complete
```

### Demo Actor Template

```yaml
Task tool (general-purpose):
  description: "Demo Actor: create launch artifacts for [feature]"
  prompt: |
    You are the Demo Actor — you create launch-ready artifacts that SHOWCASE
    the product to its target audience.

    ## Product Context
    {product_context_full}

    ## Documentation (from P2, if available)
    {p2_docs_output}

    ## Your Mission
    Create launch artifacts appropriate for the product's audience tier.

    ## Deliverables by Tier

    ### Tier 0 (Personal)
    - [ ] Updated README.md (if exists) with feature description
    - [ ] Quick usage example

    ### Tier 1 (Community)
    - [ ] README.md update with feature section
    - [ ] Demo script (runnable, shows key workflows)
    - [ ] Comparison matrix (if competitive positioning exists in product-context.md)
    - [ ] CHANGELOG entry

    ### Tier 2 (Enterprise)
    - [ ] All of Tier 1, plus:
    - [ ] Release notes draft
    - [ ] Migration guide (if breaking changes)
    - [ ] Demo video script (scene-by-scene with expected output)

    ## Demo Script Rules
    1. Must be runnable end-to-end
    2. Must demonstrate the CORE feature (V1 Core from product-context.md)
    3. Expected output must be accurate (from actual runs, not imagination)
    4. Should take < 2 minutes to run

    ## Comparison Matrix Rules (Tier 1+)
    1. Pull dimensions from product-context.md "Competitive Positioning"
    2. Only claim advantages you can PROVE from the code
    3. Be honest about weaknesses

    ## README Update Rules
    1. Feature description matches actual implementation
    2. Install/usage instructions are tested
    3. No phantom features
```

### Director Validation
The Director validates P3 artifacts by:
1. Running the demo script (if executable) — must complete without errors
2. Spot-checking 3-5 claims in README/comparison matrix against actual code
3. Verifying CHANGELOG/release notes accuracy

---

## PDLC Final Report Template

After all phases complete, the Director generates a final report:

```markdown
# PDLC Report: [Feature Name]

## Product Alignment
- **Tier:** [0/1/2]
- **Product Skeptic verdict:** [APPROVE/SCOPE/KILL_OVERRIDDEN]
- **Scope cuts applied:** [list or "none"]
- **Core thesis served:** [yes/no + evidence]

## Implementation Summary
- **Batches:** [N completed]
- **Tasks:** [N/M completed]
- **Tests:** [N passing]
- **Final validation:** [ADVOCATE + SKEPTIC verdicts]

## Documentation (P2)
- **Status:** [completed / skipped / N hallucinations fixed]
- **Artifacts:** [list of docs files created]

## PR Review (Phase 5)
- **Status:** [completed / skipped / N review cycles]
- **PR:** [URL]
- **Comments received:** [N total — N critical, N major, N minor, N suggestion]
- **Comments addressed:** [N / N]
- **False positives filtered:** [N]
- **Gap classification:**
  - PROMPT_GAP: [N] — [summary]
  - CALLSITE_GAP: [N] — [summary]
  - TOOLING_GAP: [N] — [summary]
  - ARCH_GAP: [N] — [summary]
  - COVERAGE_GAP: [N] — [summary]
  - HUMAN_ONLY: [N] — [summary]

## Launch Artifacts (P3)
- **Status:** [completed / skipped]
- **Artifacts:** [list of launch files created]
- **Demo tested:** [yes/no]

## Files Modified
[Complete list of all files created/modified across all phases]

## Next Steps
- [What the user should do after PDLC completes]
```
