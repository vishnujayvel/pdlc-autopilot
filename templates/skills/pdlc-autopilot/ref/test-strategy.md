# Test Strategy Designer (Phase 0.75)

**Runs:** After Phase 0.5 (validation-criteria loaded), before Phase 1+ (execution).

**Purpose:** Research the codebase's test infrastructure, define a test strategy, design holdout scenarios the Actor won't see, and establish test tier requirements. This prevents actors from gaming test coverage by writing tests that pass trivially.

---

## Test Strategy Designer Prompt Template

### Required Inputs

Before dispatching this prompt, the Director MUST substitute:

| Variable | Source |
|----------|--------|
| `{feature_name}` | Feature name from spec |
| `{product_context_summary}` | Summary from `{project}/.claude/product-context.md` (core thesis, tier, principles) |
| `{requirements_list}` | FR-* requirements from `{spec_dir}/requirements.md` |
| `{design_sections}` | Relevant architectural sections from `{spec_dir}/design.md` |
| `{task_list}` | Tasks with acceptance criteria from `{spec_dir}/tasks.md` |

```yaml
Task tool (general-purpose):
  description: "Test Strategy Designer: {feature_name}"
  prompt: |
    You are the Test Strategy Designer. Your job is to research the project's test
    infrastructure and produce a test strategy BEFORE any implementation begins.

    ## Project Context
    {product_context_summary}

    ## Spec Reference
    - Requirements: {requirements_list}
    - Design: {design_sections}
    - Tasks: {task_list}

    ## Your Mission
    Research the codebase's test setup and produce a comprehensive test strategy.

    ## Step 1: Test Infrastructure Audit
    1. Identify the test framework(s) in use (Jest, Vitest, pytest, etc.)
    2. Find test configuration files (jest.config, vitest.config, pytest.ini, etc.)
    3. Catalog existing test patterns:
       - Unit test conventions (file naming, directory structure)
       - Integration test setup (fixtures, mocks, test databases)
       - E2E test infrastructure (if any)
    4. Identify test utilities and helpers already in the codebase
    5. Check for existing test coverage thresholds or CI gates

    ## Step 2: Test Tier Definitions
    Define which tests are required for this feature at each tier:

    ### Tier 1: Unit Tests (MANDATORY)
    - Pure function input/output verification
    - Error path coverage (invalid inputs, edge cases)
    - Boundary conditions (empty arrays, null values, max values)

    ### Tier 2: Integration Tests (MANDATORY for features touching >1 module)
    - Cross-module interactions
    - Data flow through pipelines
    - External dependency behavior (with mocks/stubs)

    ### Tier 3: Behavioral Tests (MANDATORY for user-facing features)
    - End-to-end workflows
    - CLI command invocations with expected output
    - API endpoint request/response cycles

    ### Tier 4: Regression Tests (MANDATORY for bug fixes)
    - Reproduce the exact bug scenario
    - Verify fix prevents recurrence
    - Test related edge cases that might have the same root cause

    ## Step 3: Holdout Scenario Design (CRITICAL — Anti-Gaming)
    Design 3-5 scenarios the Actor will NOT see. These are revealed ONLY during
    Final Validation to catch superficial implementations.

    ### Holdout Scenario Rules
    1. Each scenario tests a REAL edge case from the requirements
    2. Scenarios must be executable (not hypothetical)
    3. Scenarios should catch "happy path only" implementations
    4. At least one scenario must test error/failure behavior
    5. At least one scenario must test boundary conditions

    ### Holdout Scenario Format
    ```
    HOLDOUT-1: [short name]
    - Setup: [preconditions]
    - Action: [what to do]
    - Expected: [exact expected outcome]
    - Catches: [what superficial implementation this would expose]
    ```

    **ANTI-GAMING CONSTRAINT:** Do NOT include holdout scenarios in task descriptions
    or acceptance criteria given to Actors. Holdout scenarios are revealed ONLY during
    Final Validation.

    ## Step 4: Test Quality Requirements
    Define minimum quality bars for this feature:

    1. **No assertion-free tests** — Every test must assert something meaningful
    2. **No count-only assertions** — Don't just check `.length`, check contents
    3. **Deterministic tests** — No reliance on timestamps, random values, or ordering
       without explicit control (mocking, sorting, seeding)
    4. **Error path coverage** — Every public function must have at least one error
       test case
    5. **Test isolation** — Tests must not depend on other tests' side effects

    ## Output
    Produce a test strategy document with:
    1. **Infrastructure Summary** — frameworks, config, existing patterns
    2. **Test Tier Matrix** — which tiers apply to which tasks
    3. **Holdout Scenarios** — 3-5 scenarios (SEALED — not shared with Actors)
    4. **Quality Requirements** — minimum bars for this feature
    5. **Test File Plan** — where new test files should go (follow existing conventions)
```

---

## Director Protocol for Phase 0.75

```text
1. Dispatch Test Strategy Designer subagent (single)
2. Receive test strategy document
3. Extract holdout scenarios → store in validation-criteria.md under:
   ## Holdout Scenarios (SEALED — Final Validator Only)
   [scenarios here]
4. Extract test tier requirements → include in Actor prompts:
   "Test Tiers Required: [list tiers from strategy]"
5. Extract quality requirements → include in Critic prompts:
   "Test Quality Requirements: [list quality bars]"
6. DO NOT include holdout scenarios in Actor or per-batch Critic prompts
7. Proceed to Phase 1+
```

---

## Holdout Scenario Execution (Final Validation)

During Final Validation, the Final SKEPTIC receives the sealed holdout scenarios:

```text
## Holdout Scenario Verification
For each HOLDOUT-N scenario:
1. Execute the scenario against the implemented code
2. Compare actual result to expected result
3. Report:
   - HOLDOUT-1: [PASS/FAIL] — [actual vs expected]
   - HOLDOUT-2: [PASS/FAIL] — [actual vs expected]
   ...

If ANY holdout scenario fails:
  - Flag as ❌ FAIL with specific gap
  - This indicates the implementation is superficial (passes stated tests but
    misses real edge cases)
  - Recommend additional test cases to cover the gap
```

---

## Anti-Gaming Constraints

These rules prevent Actors from optimizing for stated criteria while missing real quality:

1. **Information barrier** — Holdout scenarios are NEVER included in Actor prompts,
   task acceptance criteria, or per-batch Critic prompts
2. **Scenario diversity** — At least one holdout must test each of: error paths,
   boundary conditions, and cross-module interactions (where applicable)
3. **No retroactive weakening** — Once holdout scenarios are sealed in
   validation-criteria.md, they cannot be modified or removed during execution
4. **Failure triggers rework** — A holdout failure is treated as a Final Validator
   FAIL, requiring a fix cycle before completion
