# Phase 5: PR Review Cycle

**Runs:** After Final Validator passes, before Retrospective.

**Purpose:** Create a pull request, ingest external code review feedback (human reviewers, CodeRabbit, etc.), address comments systematically, and classify gaps for retrospective input.

---

## Phase 5 Protocol

### 5.1 Create PR

```text
1. Create branch: pdlc/{feature-name} (from current HEAD)
2. Stage all implementation files
3. Filter sensitive files — NEVER commit:
   - .env, .env.*, credentials.*, secrets.*
   - **/node_modules/**, **/.venv/**
   - Any file matching patterns in .gitignore
4. Create PR via `gh pr create`:
   - Title: concise (<70 chars), prefixed with feature area
   - Body: Summary (FR-* covered), test plan, files changed
   - Labels: from product-context.md tier (e.g., "tier-0", "tier-1")
5. Record PR URL in progress.md
```

### 5.2 Wait for External Review

```text
1. Check for external review tools:
   - CodeRabbit: check if .coderabbit.yaml exists or PR gets auto-review
   - Human reviewers: check CODEOWNERS or repo settings
2. Poll for review completion:
   - `gh pr checks {pr_number}` — wait for CI to pass
   - `gh pr view {pr_number} --json reviews` — wait for at least one review
3. Configurable timeout: default 5 minutes for automated reviews
   - If no automated review after timeout, proceed with human-only flow
   - If waiting for human review, notify user and pause
```

### 5.3 Ingest Review Comments

```text
1. Fetch all review comments:
   - `gh api repos/{owner}/{repo}/pulls/{pr}/comments`
   - `gh api repos/{owner}/{repo}/pulls/{pr}/reviews`
2. Parse each comment into structured format:
   {
     "id": "comment_id",
     "file": "path/to/file",
     "line": 42,
     "body": "comment text",
     "author": "reviewer_name",
     "severity": "critical|major|minor|suggestion|nitpick",
     "category": "bug|style|performance|security|docs|test"
   }
3. Classify severity:
   - CRITICAL: Bugs, security issues, data loss risks
   - MAJOR: Logic errors, missing error handling, test gaps
   - MINOR: Style issues, naming, minor improvements
   - SUGGESTION: Alternative approaches, nice-to-haves
   - NITPICK: Whitespace, formatting, personal preference
4. Filter false positives (see False Positive Detection below)
```

### 5.4 Address Comments

```text
1. Group comments by file → create fix batches
2. For each batch:
   a. Dispatch Actor with:
      - Original task context (from tasks.md)
      - Review comments for this file
      - Design context (relevant design.md sections)
   b. Actor addresses CRITICAL and MAJOR comments (mandatory)
   c. Actor addresses MINOR comments (best effort)
   d. Actor may skip SUGGESTION/NITPICK with justification
3. PROC-2 applies: dispatch Critics for each fix batch
4. Record which comments were addressed vs. skipped in progress.md
```

### 5.5 Reply to Reviewer Comments

```text
For each addressed comment:
  - Reply on PR explaining the fix:
    "Fixed in {commit_sha}: {1-line explanation}"
  - Reference the specific change (file:line)

For each skipped comment:
  - Reply explaining why:
    "Acknowledged — skipping because: {reason}"
    Valid skip reasons:
    - False positive (see classification below)
    - Contradicts spec (cite requirement)
    - Style preference (not a bug)
    - Deferred to future iteration
```

### 5.6 Push Fixes + Re-request Review

```text
1. Push fix commits to PR branch
2. Re-request review if significant changes made:
   - `gh pr edit {pr} --add-reviewer {reviewer}`
3. Max 2 review cycles total
   - If still getting CRITICAL comments after 2 cycles → escalate to user
4. Update progress.md with cycle count
```

### 5.7 Gap Classification → Retrospective Input

```text
After all review comments are processed, classify each into a gap category.
This feeds directly into the retrospective (Phase: Retrospective).

Gap categories:
  PROMPT_GAP      — Our Actor/Critic prompts should have caught this but didn't
  CALLSITE_GAP    — New entity not registered everywhere (feeds SKEPTIC item 9)
  TOOLING_GAP     — Linter/formatter should have caught this but wasn't configured
  ARCH_GAP        — Architectural pattern violation not in ARCH-* constraints
  COVERAGE_GAP    — Test coverage insufficient for this code path
  HUMAN_ONLY      — Requires domain expertise or subjective judgment only humans have

Record in progress.md:
  ## Review Gap Classification
  | Comment ID | Gap Type | Description | Action |
  |-----------|----------|-------------|--------|
  | C-123 | PROMPT_GAP | SKEPTIC missed timezone mixing | Add to SKEPTIC item 12 |
  | C-456 | TOOLING_GAP | ESLint not configured for X | Add .eslintrc rule |
  | C-789 | HUMAN_ONLY | Architecture preference | No process change |
```

---

## Review Agent Context Protocol

Review comment Actors receive loaded context to make informed fix decisions:

```text
Context Loading (for each fix Actor):
1. Read {project}/.claude/product-context.md — understand product tier and principles
2. Read {spec_dir}/design.md — understand architectural decisions
3. Read {spec_dir}/validation-criteria.md — understand quality bars
4. Read {spec_dir}/requirements.md — understand FR-* requirements

This prevents fix Actors from:
- Making changes that violate architectural constraints
- Implementing reviewer suggestions that contradict the spec
- Over-engineering fixes beyond what the product tier warrants
```

---

## CodeRabbit Knowledge Base

### Severity Mapping

Map CodeRabbit's comment format to PDLC severity:

| CodeRabbit Signal | PDLC Severity |
|-------------------|---------------|
| `[critical]`, `bug`, `security` | CRITICAL |
| `[major]`, `error handling`, `logic` | MAJOR |
| `[minor]`, `style`, `naming` | MINOR |
| `[suggestion]`, `consider`, `could` | SUGGESTION |
| `[nitpick]`, `nit`, `formatting` | NITPICK |

### Comment Structure

CodeRabbit comments follow patterns the Director can parse:

```text
Typical CodeRabbit comment structure:
- Summary line (first sentence = the issue)
- Code suggestion (```suggestion block)
- Explanation (why this matters)
- Sometimes: link to relevant docs/rules

Extract: summary + suggestion block + file:line for Actor context.
```

### False Positive Patterns

Common CodeRabbit false positives to auto-filter:

1. **Stale context** — Comment references code that was already changed in a later commit
2. **Framework convention** — Flags patterns that are idiomatic for the framework in use
3. **Intentional design** — Flags something explicitly documented as a design decision
4. **Test code** — Applies production rules to test utilities/fixtures

---

## Spec-Based False Positive Detection

When a reviewer suggests a change, check it against the spec before implementing:

```text
For each review comment:
1. Does the suggestion CONTRADICT a requirement in requirements.md?
   → If yes: FALSE POSITIVE — reply citing the requirement
   → "This is intentional per FR-7: [requirement text]"

2. Does the suggestion CONTRADICT an architectural decision in design.md?
   → If yes: FALSE POSITIVE — reply citing the design decision
   → "This follows ARCH-3: [constraint text] (design.md §section)"

3. Does the suggestion CONTRADICT a tenet in validation-criteria.md?
   → If yes: FALSE POSITIVE — reply citing the tenet
   → "This is governed by Tenet T4: [tenet text]"

4. Does the suggestion improve something OUTSIDE the spec scope?
   → If yes: DEFERRED — acknowledge but don't implement
   → "Good suggestion, deferring to a future iteration"

5. None of the above?
   → VALID comment — implement the fix
```

---

## Gap Classification Taxonomy

Used in Step 5.7 for retrospective input:

| Gap Type | Definition | Process Improvement |
|----------|-----------|-------------------|
| `PROMPT_GAP` | Actor or Critic prompt should catch this class of bug but doesn't | Add new SKEPTIC/Actor check item |
| `CALLSITE_GAP` | New entity not registered at all callsites | Strengthen SKEPTIC item 9 (Callsite Completeness) |
| `TOOLING_GAP` | A linter, formatter, or type-checker rule would prevent this | Add linting rule or enable stricter config |
| `ARCH_GAP` | Architectural pattern violated but not captured as ARCH-* | Add new ARCH-* constraint to validation-criteria |
| `COVERAGE_GAP` | Code path not tested | Add test tier requirement or holdout scenario |
| `HUMAN_ONLY` | Requires subjective judgment, domain expertise, or taste | No process change — acknowledge human value |

**Retrospective integration:** The gap classification table feeds the retrospective's
"What should we change?" question. `PROMPT_GAP` and `CALLSITE_GAP` items become
concrete improvements to the PDLC process itself (self-improvement loop).
