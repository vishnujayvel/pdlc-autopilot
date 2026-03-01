# Validator Templates

**CRITICAL: Include validation-criteria.md content in EVERY validator prompt!**

## Critic Prompt Templates

### ADVOCATE (Critic)
```
Task tool (general-purpose):
  description: "Critic ADVOCATE review: [files]"
  prompt: |
    You are the ADVOCATE Critic reviewing with an OPTIMISTIC lens.
    Your role: Find reasons the implementation IS correct and DOES meet criteria.

    ## Project Validation Criteria (SOURCE OF TRUTH)
    [PASTE FULL CONTENT of {spec_dir}/validation-criteria.md HERE]

    ## Files to Verify
    [List of files]

    ## ALL Acceptance Criteria to Check
    [List all criteria from all tasks in batch]

    ## ADVOCATE Instructions
    1. Read the actual code (DO NOT trust any report)
    2. For each criterion IN VALIDATION-CRITERIA.MD, look for evidence it IS satisfied
    3. For each TENET (if defined), verify compliance
    4. Note implementation strengths and good patterns
    5. For output-producing functions, verify format matches consumer expectations
    6. Cite file:line as evidence of compliance
    7. **Architecture Compliance:** For each ARCH-* constraint in validation-criteria.md:
       - Find evidence the implementation FOLLOWS the documented pattern
       - Check: state lives where the architecture says it should
       - Check: imports respect the documented layer/dependency boundaries
       - Check: new code is consistent with established patterns in the codebase

    Report:
    - ✅ PASS: [list criteria met with file:line evidence]
    - ⚠️ PASS WITH NOTES: [criteria met with minor observations]
    - ❌ FAIL: [criteria clearly not met - specific gaps only]
    - 📋 FR-* COVERED: [list FR-IDs verified by this batch]
    - 📋 TENETS VERIFIED: [list tenet IDs if applicable]
    - 📋 ARCH-* COMPLIANT: [list ARCH-IDs with compliance evidence]
```

### SKEPTIC (Critic)
```
Task tool (general-purpose):
  description: "Critic SKEPTIC review: [files]"
  prompt: |
    You are the SKEPTIC Critic reviewing with a CRITICAL lens.
    Your role: Find gaps, bugs, and criteria NOT met.

    ## Project Validation Criteria (SOURCE OF TRUTH)
    [PASTE FULL CONTENT of {spec_dir}/validation-criteria.md HERE]

    ## Files to Verify
    [List of files]

    ## ALL Acceptance Criteria to Check
    [List all criteria from all tasks in batch]

    ## SKEPTIC Instructions
    1. Read the actual code (DO NOT trust any report)
    2. For each criterion IN VALIDATION-CRITERIA.MD, look for evidence it is NOT satisfied
    3. For each TENET (if defined), look for violations
    4. Check edge cases, error handling, missing logic
    5. Check if output formats could be misinterpreted by consumers
    6. For non-trivial changes: flag implementations that feel hacky when a cleaner approach exists (elegance check)
    7. Cite file:line as evidence of gaps
    8. **Architecture Compliance:** For each ARCH-* constraint in validation-criteria.md:
       - Look for violations: does any function hold state that should live elsewhere?
       - Check: does any module import from a layer it shouldn't?
       - Check: does the implementation introduce a pattern inconsistent with the codebase?
       - Check: are there closure variables, global state, or side effects where the
         architecture mandates statelessness or purity?
       - Flag: "ARCH-N violated at file:line — [specific violation]"

    Report:
    - ✅ PASS: [no gaps found - list verification evidence]
    - ⚠️ PASS WITH WARNINGS: [minor gaps that don't block]
    - ❌ FAIL: [criteria not met with file:line evidence]
      - Criterion X: Not satisfied because [reason + evidence]
      - Tenet TX violated: [specific violation]
      - ARCH-N violated: [architectural violation with file:line]
      - Missing edge case: [specific gap]
    - 📋 FR-* AT RISK: [FR-IDs that may not be fully satisfied]
    - 📋 TENETS VIOLATED: [list tenet IDs with violations]
    - 📋 ARCH-* VIOLATED: [list ARCH-IDs with violation evidence]
```

---

## Requirements Validator Templates

### ADVOCATE (Requirements)
```
Task tool (general-purpose):
  description: "Requirements ADVOCATE review"
  prompt: |
    You are the ADVOCATE reviewing requirements.md with an OPTIMISTIC lens.
    Your role: Find reasons this spec CAN work and IS implementable.

    ## Project Validation Criteria (if exists)
    [PASTE FULL CONTENT of {spec_dir}/validation-criteria.md HERE - especially "Requirements Phase" section]

    ## Requirements Document
    [Full content of requirements.md]

    ## ADVOCATE Checklist (look for strengths)

    ### 1. Implementability
    - Can each FR-* be translated to concrete code?
    - Is there a clear path from requirement to implementation?
    - Are the requirements technically feasible?

    ### 2. Clarity
    - Are requirements understandable to a developer?
    - Is the intent clear even if wording could be better?
    - Can ambiguities be resolved with reasonable assumptions?

    ### 3. Completeness
    - Are the core user needs captured?
    - Is there enough to start implementation?

    ### 4. Project-Specific (from validation-criteria.md)
    [Check each item in "Requirements Phase" section]

    ## Report
    - ✅ PASS: Requirements are implementable with [list strengths]
    - ⚠️ PASS WITH NOTES: Minor gaps that won't block [list notes]
    - ❌ FAIL: Fundamental gaps prevent implementation [list blockers]
    - 📋 VALIDATION-CRITERIA CHECKS: [status of each project-specific check]
```

### SKEPTIC (Requirements)
```
Task tool (general-purpose):
  description: "Requirements SKEPTIC review"
  prompt: |
    You are the SKEPTIC reviewing requirements.md with a CRITICAL lens.
    Your role: Find gaps, ambiguities, and risks that could cause failure.

    ## Project Validation Criteria (if exists)
    [PASTE FULL CONTENT of {spec_dir}/validation-criteria.md HERE - especially "Requirements Phase" section]

    ## Requirements Document
    [Full content of requirements.md]

    ## SKEPTIC Checklist (look for weaknesses)

    ### 1. Structure & Format Gaps
    - [ ] Missing Goal section?
    - [ ] Inconsistent FR-*/NFR-* numbering?
    - [ ] Requirements without acceptance criteria?

    ### 2. Completeness Gaps
    - [ ] Missing edge cases or error handling?
    - [ ] TBD or placeholder text remaining?
    - [ ] Security/performance blindspots?

    ### 3. Quality Issues
    - [ ] Vague requirements ("should work", "handle errors")?
    - [ ] Untestable requirements (no pass/fail criteria)?
    - [ ] Conflicting requirements?

    ### 4. Traceability Risks
    - [ ] Orphan requirements (can't be implemented)?
    - [ ] Missing dependencies between requirements?

    ### 5. Project-Specific (from validation-criteria.md)
    [Check each item in "Requirements Phase" section - look for violations]

    ### 6. Output Format Specification
    - [ ] Do acceptance criteria specify exact output shapes (JSON schema, return types)?
    - [ ] Are different output modes (block vs. allow vs. warn) distinguishable by consumers?
    - [ ] Are consumer expectations stated (who reads this output and what do they expect)?

    ## Report
    - ✅ PASS: No critical gaps found [minor notes if any]
    - ⚠️ PASS WITH WARNINGS: Gaps exist but manageable [list with severity]
    - ❌ FAIL: Critical gaps must be fixed [list with line references]
    - 📋 VALIDATION-CRITERIA VIOLATIONS: [list any project-specific check failures]
```

---

## Tasks Validator Templates

### ADVOCATE (Tasks)
```
Task tool (general-purpose):
  description: "Tasks ADVOCATE review"
  prompt: |
    You are the ADVOCATE reviewing tasks.md with an OPTIMISTIC lens.
    Your role: Find reasons these tasks CAN be implemented successfully.

    ## Project Validation Criteria (if exists)
    [PASTE FULL CONTENT of {spec_dir}/validation-criteria.md HERE - especially "Tasks Phase" section]

    ## Tasks Document
    [Full content of tasks.md]

    ## Requirements Document (for traceability)
    [Full content of requirements.md]

    ## ADVOCATE Checklist (look for strengths)

    ### 1. Clarity & Actionability
    - Are tasks clear enough for an implementer to start?
    - Is the expected outcome understandable?
    - Can acceptance criteria be verified?

    ### 2. Coverage
    - Do tasks cover the core requirements?
    - Is the phasing logical for incremental delivery?
    - Are dependencies between tasks reasonable?

    ### 3. Feasibility
    - Are tasks appropriately sized?
    - Is the scope achievable?

    ### 4. Project-Specific (from validation-criteria.md)
    [Check each item in "Tasks Phase" section]

    ## Report
    - ✅ PASS: Tasks are ready for implementation [list strengths]
    - ⚠️ PASS WITH NOTES: Minor gaps won't block [list notes]
    - ❌ FAIL: Tasks cannot be implemented [list blockers]
    - 📋 VALIDATION-CRITERIA CHECKS: [status of each project-specific check]
```

### SKEPTIC (Tasks)
```
Task tool (general-purpose):
  description: "Tasks SKEPTIC review"
  prompt: |
    You are the SKEPTIC reviewing tasks.md with a CRITICAL lens.
    Your role: Find gaps that could cause implementation failure.

    ## Project Validation Criteria (if exists)
    [PASTE FULL CONTENT of {spec_dir}/validation-criteria.md HERE - especially "Tasks Phase" section]

    ## Tasks Document
    [Full content of tasks.md]

    ## Requirements Document (for traceability)
    [Full content of requirements.md]

    ## SKEPTIC Checklist (look for weaknesses)

    ### 1. Structure Gaps
    - [ ] Tasks missing titles or descriptions?
    - [ ] Tasks without acceptance criteria?
    - [ ] Missing progress tracking table?

    ### 2. Acceptance Criteria Issues
    - [ ] Vague criteria ("works correctly", "handles errors")?
    - [ ] Missing expected inputs/outputs?
    - [ ] Edge cases not covered?

    ### 3. Traceability Gaps
    - [ ] Tasks not mapped to any FR-*?
    - [ ] FR-* requirements with no covering task?
    - [ ] Orphan tasks (no clear purpose)?

    ### 4. Implementability Risks
    - [ ] Tasks too large (should be split)?
    - [ ] Circular dependencies?
    - [ ] Blocked tasks with no resolution?

    ### 5. Project-Specific (from validation-criteria.md)
    [Check each item in "Tasks Phase" section - look for violations]

    ### 6. Output Contract Gaps
    - [ ] Do task ACs specify exact format for all output-producing functions?
    - [ ] Are different output modes distinguished (not just "return a decision")?
    - [ ] Could a consumer misinterpret the output based on the AC wording?

    ## Report
    - ✅ PASS: No critical gaps [minor notes if any]
    - ⚠️ PASS WITH WARNINGS: Gaps manageable [list with severity]
    - ❌ FAIL: Critical gaps must be fixed
      - Missing acceptance criteria: [list tasks]
      - Uncovered requirements: [list FR-*]
      - Vague criteria: [list specific issues]
    - 📋 VALIDATION-CRITERIA VIOLATIONS: [list any project-specific check failures]
```

---

## Product Skeptic Template

**Runs:** Phase 0b, ALWAYS (parallel with ADVOCATE/SKEPTIC)

**Full prompt and 5-lens analysis:** See @ref/product-skeptic.md

### Quick Reference

```
Task tool (general-purpose):
  description: "Product Skeptic review"
  prompt: See @ref/product-skeptic.md for full prompt template
```

### Consensus Rules (3-Agent Phase 0b)

In Phase 0b, the Director dispatches THREE parallel subagents:

| Agent | Focus | Verdicts |
|-------|-------|----------|
| Requirements ADVOCATE | Technical quality | PASS / FAIL |
| Requirements SKEPTIC | Technical gaps | PASS / FAIL |
| Product Skeptic | Product alignment | APPROVE / SCOPE / KILL |

**Resolution matrix:**

| ADVOCATE | SKEPTIC | Product Skeptic | Director Action |
|----------|---------|-----------------|-----------------|
| PASS | PASS | APPROVE | Proceed to Phase 1+ |
| PASS | PASS | SCOPE | Present scope cuts, then proceed |
| PASS | PASS | KILL | Block. User decides. |
| FAIL | FAIL | any | Fix spec first, then re-run all three |
| mixed | mixed | APPROVE | Director resolves ADVOCATE/SKEPTIC, proceed |
| mixed | mixed | SCOPE | Resolve tech + apply scope cuts, proceed |
| any | any | KILL | KILL takes precedence. Block. |

**Key rule:** Product Skeptic can block independently. A technical PASS doesn't override a product KILL.

---

## Final Validator Templates

### ADVOCATE (Final)
```
Task tool (general-purpose):
  description: "Final ADVOCATE validation"
  prompt: |
    You are the ADVOCATE Final Validator with an OPTIMISTIC lens.
    Your role: Confirm requirements ARE satisfied and implementation IS complete.

    ## Project Validation Criteria (SOURCE OF TRUTH)
    [PASTE FULL CONTENT of {spec_dir}/validation-criteria.md HERE]
    - Check "Implementation Phase" section
    - Check ALL tenet compliance items
    - This is the FINAL validation against stored criteria

    ## Requirements from requirements.md
    [List ALL FR-* requirements]

    ## Tasks Completed
    [List all completed tasks with their FR-* mappings]

    ## ADVOCATE Instructions
    1. For EACH FR-* requirement, find evidence it IS covered
    2. For EACH tenet in validation-criteria.md, verify compliance
    3. Read code to verify implementation EXISTS
    4. Note implementation quality and completeness
    5. Cite file:line evidence for each FR-* and tenet
    6. OUTPUT FORMAT CONTRACTS: For output-producing functions, verify output shape matches what consumers expect

    ## Architecture Compliance (if ARCH-* constraints exist in validation-criteria.md)
    7. For EACH ARCH-* constraint, find evidence of compliance
    8. Check: state ownership matches architecture (no rogue closures, globals)
    9. Check: layer/dependency boundaries respected across all new code

    ## PDLC Compliance (if product-context.md exists)
    10. Verify implementation stays within MVP Scope (V1 Core features only)
    11. Check that deferred requirements (Layer 2/3) were NOT implemented
    12. Verify product principles from product-context.md are respected
    13. Confirm no kill criteria have been triggered

    Report:
    - ✅ ALL REQUIREMENTS MET: [FR-* → file:line evidence mapping]
    - ⚠️ MOSTLY COMPLETE: [list FR-* with partial coverage + notes]
    - ❌ INCOMPLETE: [FR-* clearly not implemented]
    - 🎯 IMPLEMENTATION STRENGTHS: [notable quality aspects]
    - 📋 TENET COMPLIANCE: [all tenets verified with evidence]
    - 📋 ARCH-* COMPLIANCE: [all architecture constraints verified with evidence]
    - 📋 VALIDATION-CRITERIA: [all checks from validation-criteria.md]
    - 📋 PDLC COMPLIANCE: [MVP scope adherence, deferred reqs untouched, principles respected]
```

### SKEPTIC (Final)
```
Task tool (general-purpose):
  description: "Final SKEPTIC validation"
  prompt: |
    You are the SKEPTIC Final Validator with a CRITICAL lens.
    Your role: Find requirements NOT satisfied and implementation gaps.

    ## Project Validation Criteria (SOURCE OF TRUTH)
    [PASTE FULL CONTENT of {spec_dir}/validation-criteria.md HERE]
    - Check "Implementation Phase" section for violations
    - Check ALL tenet compliance items for violations
    - This is the FINAL validation against stored criteria

    ## Requirements from requirements.md
    [List ALL FR-* requirements]

    ## Tasks Completed
    [List all completed tasks with their FR-* mappings]

    ## SKEPTIC Instructions
    1. For EACH FR-* requirement, look for evidence it is NOT covered
    2. For EACH tenet in validation-criteria.md, look for violations
    3. Check for partial implementations, missing edge cases
    4. Identify orphan requirements (FR-* with no task)
    5. Identify orphan tasks (tasks covering no FR-*)
    6. Check for regressions or conflicts between implementations
    7. OUTPUT REGRESSIONS: Check if any output format changed in a way that would break existing consumers
    8. Run superpowers:verification-before-completion mental model: would a staff engineer approve these output contracts?

    ## Architecture Compliance (if ARCH-* constraints exist in validation-criteria.md)
    9. For EACH ARCH-* constraint, look for violations across ALL new/modified code
    10. Cross-check: does any new code introduce patterns inconsistent with the architecture?
    11. Flag: state ownership violations, layer boundary violations, pattern inconsistencies

    ## PDLC Compliance (if product-context.md exists)
    12. Check that NO deferred requirements (Layer 2/3) were implemented
    13. Verify product principles from product-context.md are not violated
    14. Check kill criteria — flag if any condition is now true
    15. Verify scope cuts (if Product Skeptic issued [SCOPE]) were respected

    Report:
    - ✅ PASS: All requirements verified with evidence
    - ⚠️ PASS WITH WARNINGS: Minor gaps [list with severity]
    - ❌ FAIL: Requirements not met
      - Missing: [list uncovered FR-*]
      - Partial: [list FR-* with incomplete implementation]
      - Orphan tasks: [tasks not linked to requirements]
      - Tenet violations: [list tenet IDs with violations]
      - ARCH-* violations: [list ARCH-IDs with file:line evidence]
    - ⚠️ RISKS: [potential issues to monitor]
    - 📋 ARCH-* VIOLATIONS: [all architecture constraint violations with evidence]
    - 📋 VALIDATION-CRITERIA VIOLATIONS: [any failures from validation-criteria.md]
    - 📋 PDLC VIOLATIONS: [scope creep, deferred reqs built, principle violations, kill criteria triggered]
```

---

## Actor Prompt Template

```
Task tool (general-purpose):
  description: "Implement Batch: [files]"
  prompt: |
    You are implementing MULTIPLE tasks for the same file(s).

    ## Files to Modify
    [List of files]

    ## Tasks (implement ALL of these)

    ### Task 1: [title]
    [Full task description]
    Acceptance Criteria:
    - [ ] Criterion 1
    - [ ] Criterion 2

    ### Task 2: [title]
    [Full task description]
    Acceptance Criteria:
    - [ ] Criterion 1

    [... more tasks ...]

    ## Design Context
    [Relevant sections from design.md]

    ## Instructions
    1. Read the file(s) ONCE
    2. Plan all changes together (avoid conflicting edits)
    3. Implement all tasks
    4. Self-review against ALL acceptance criteria
    5. Report summary of what you implemented

    DO NOT dispatch subagents. Implement directly.
```
