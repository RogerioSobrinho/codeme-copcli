---
name: continuous-learning
description: Knowledge capture and evolution protocol for this agent system. Covers the three-time rule for pattern promotion, pattern/anti-pattern templates, end-of-session review protocol, ADR template, and storage locations. Load when capturing a new reusable pattern or at the end of a coding session.
---

# Continuous Learning

## Three-Time Rule for Pattern Promotion

A solution becomes a **pattern** (worth generalizing) when the same approach is applied successfully three or more times in distinct contexts.

| Occurrence | Action |
|---|---|
| 1st | Implement the solution; note it in session memory |
| 2nd | Recognize the repetition; evaluate generalizability |
| 3rd | Promote to a named pattern; document in SKILL.md |

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
