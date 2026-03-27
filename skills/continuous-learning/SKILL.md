---
name: continuous-learning
description: >
  Load when capturing a new architectural decision (ADR), documenting a discovered pattern or
  anti-pattern after solving a complex problem, applying the three-time-rule (promote to
  standard after solving the same problem 3 times), tracking an instinct with a confidence
  score, promoting a recurring instinct to an explicit standard, or at the end of a session
  to preserve reusable solutions. Triggers on: "document this", "remember this pattern",
  "write an ADR", "add to our standards", "this keeps coming up", "track this instinct",
  "I have a feeling about this approach".
---

# Continuous Learning v2

## Instinct System

An **instinct** is an informal heuristic — something you sense is right before you can fully justify it. The instinct system gives instincts a lifecycle: from suspicion to confirmed standard.

### Confidence Score (1–5)

| Score | Meaning |
|---|---|
| 1 | Gut feeling, no evidence yet |
| 2 | One confirming example |
| 3 | Two confirming examples, pattern forming |
| 4 | Three+ confirmations across distinct contexts |
| 5 | Battle-tested, ready for promotion to explicit rule |

**Promotion threshold:** Score ≥ 4 confirmed across **at least 3 distinct contexts** → promote to named pattern in SKILL.md.

**Decay rule:** If an instinct is contradicted by evidence, subtract 2 from the score. If score drops to 0, archive it with the contradiction noted.

### Instinct Template

```markdown
## Instinct: {Name}

**Heuristic:** [One sentence — what does the instinct say?]

**Confidence:** {1-5} / 5

**Evidence log:**
| # | Context | Outcome | Score delta |
|---|---|---|---|
| 1 | {Where this was applied} | {Worked/Failed/Partial} | +1 |

**Promoted to pattern:** [Link to pattern, or "pending"]
**Contradictions:** [What evidence challenged this?]
```

### Example Instinct

```markdown
## Instinct: Avoid @Transactional on controller layer

**Heuristic:** Controllers that call @Transactional service methods never need @Transactional themselves.

**Confidence:** 5 / 5

**Evidence log:**
| # | Context | Outcome | Score delta |
|---|---|---|---|
| 1 | REST controller calling OrderService.create() | Removing @Transactional from controller fixed unexpected rollback | +1 |
| 2 | WebMVC POST handler for payment | Controller @Transactional caused timeout extension across HTTP call | +1 |
| 3 | GraphQL mutation resolver | Field resolved in wrong transaction scope, removing from controller fixed it | +1 |

**Promoted to pattern:** See springboot-patterns.md: "Transactional boundaries"
```

---

## Three-Time Rule for Pattern Promotion

A solution becomes a **pattern** (worth generalizing) when the same approach is applied successfully three or more times in distinct contexts.

| Occurrence | Action |
|---|---|
| 1st | Implement the solution; note as instinct (score: 2) |
| 2nd | Recognize the repetition; update instinct (score: 3–4) |
| 3rd | Promote to a named pattern; document in SKILL.md (score: 5) |

**Trigger questions for promotion:**
1. Could a different developer use this in isolation?
2. Does it have a clear name and clear boundaries?
3. Is the trade-off explicit (when to use vs when not to)?

---

## Pattern Template

```markdown
## [Pattern Name]

**Context:** When is this pattern applicable?

**Problem:** What specific problem does it solve?

**Solution:**
[Code example or procedure]

**Consequences:**
- Benefit 1
- Benefit 2
- Trade-off or limitation

**Counter-indications:** When NOT to use this pattern.
```

---

## Anti-Pattern Template

```markdown
## [Anti-Pattern Name] — ❌ Avoid

**Symptom:** How does this manifest in code?

**Root Cause:** Why does this keep appearing?

**Example:**
[Code showing the problematic pattern]

**Correct Approach:**
[Code or procedure showing the fix]

**Detection:** How to find this in a codebase (grep pattern or static analysis rule).
```

---

## End-of-Session Review Protocol

Run at the end of every significant coding session (feature complete, PR ready, or task blocked).

**Four questions:**

1. **What worked surprisingly well?**
   → Candidate for a new pattern. Document with the pattern template above.

2. **What required multiple attempts to get right?**
   → Candidate for an anti-pattern. Document the wrong approach + correct approach.

3. **What knowledge was missing that would have saved time?**
   → Gap in existing SKILL.md files. Add the missing reference material.

4. **What assumption proved false?**
   → Update relevant SKILL.md with the correction or caveat.

**Threshold for action:** If answering any question takes < 5 minutes to document, document it now.

---

## ADR Template (Architecture Decision Record)

```markdown
# ADR-{number}: {title}

**Date:** YYYY-MM-DD  
**Status:** Proposed | Accepted | Deprecated | Superseded by ADR-{n}

## Context

[What is the situation driving this decision? What constraints exist?]

## Decision

[What is the decision? State it clearly and unambiguously.]

## Rationale

[Why this decision? Why not the alternatives?]

### Alternatives Considered

| Option | Pros | Cons | Rejected Because |
|---|---|---|---|
| Option A | ... | ... | ... |
| Option B | ... | ... | ... |

## Consequences

**Positive:**
- [What becomes easier or better?]

**Negative:**
- [What becomes harder or worse?]
- [What technical debt is accepted?]

## Implementation Notes

[Specific constraints or guidance for implementing this decision.]
```

---

## Storage Locations

| Artifact | Location |
|---|---|
| New pattern (general) | Relevant `skills/*/SKILL.md` section |
| New agent-specific behavior | `agents/*.agent.md` instructions |
| Architecture decisions | `.copilot-runtime/decisions/ADR-NNN.md` |
| Session-specific artifacts | `.copilot-runtime/artifacts/` |
| Test strategy notes | `.copilot-runtime/tests/test-plan.md` |

**Naming for ADRs:** `ADR-001-choose-flyway-over-liquibase.md`. Always zero-padded, always includes the decision topic in the filename.

---

## Skill Evolution Process

When a pattern in SKILL.md proves wrong or outdated:

1. Do not delete — mark as deprecated with a note pointing to the updated pattern
2. Add the correct pattern below with a "Supersedes the above" note
3. Remove the deprecated pattern only after confirming no agent relies on it

This prevents silent knowledge loss when a cached version of the SKILL.md is in use.
