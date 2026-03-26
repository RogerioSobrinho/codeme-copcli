---
name: continuous-learning
description: Pattern extraction and skill evolution workflow. After each coding session, extract reusable patterns, anti-patterns, and decisions into skill files for institutional memory.
tools: ["Read", "Write", "Bash", "Grep"]
model: claude-sonnet-4-5
activation: ["extract patterns", "learn from session", "save patterns", "continuous learning", "session patterns", "instinct"]
---

# Continuous Learning

## Purpose

Pattern extraction and institutional memory workflow. Defines when and how to capture reusable patterns, anti-patterns, and architectural decisions from coding sessions into durable skill files. Prevents the same mistakes from being repeated, accumulates project-specific knowledge, and evolves the agent skill set as the codebase matures.

---

## When to Extract

### Extract After
- Fixing a bug that appeared in similar form before → anti-pattern candidate
- Making an architectural decision with long-term consequences → ADR candidate
- Completing a complex refactor that reveals a better structure → pattern candidate
- Discovering that a library/framework feature solves a problem more elegantly → best-practice candidate
- A code review surfaces a recurring issue → lint rule or anti-pattern candidate

### Do NOT Extract
- One-off hacks specific to a single ticket
- Configuration that is environment-specific
- Business logic that has no general applicability

### The Three-Time Rule
If the same pattern or mistake appears **3 or more times**, it is ready to be promoted to a skill file. One occurrence is an incident. Two is a coincidence. Three is a pattern.

---

## Pattern Template

A good pattern has:

```markdown
### Pattern: <Concise Name>

**Context:**
When/where does this pattern apply? What problem does it solve?

**Problem:**
What goes wrong without this pattern?

**Solution:**
The concrete, actionable implementation or decision.

**Example:**
```code
// Minimal code or config snippet
```

**Trade-offs:**
- Pro: ...
- Con: ...

**When NOT to use:**
...
```

### Example: Pattern — Repository Layer Abstraction
```markdown
### Pattern: Repository Interface Behind Service

**Context:**
Service classes in Spring Boot that need to interact with persistence.

**Problem:**
Services directly calling JPA repositories creates tight coupling and makes unit testing impossible without a database.

**Solution:**
Define a domain-level repository interface in the domain layer. Implement it in the infrastructure layer with JPA. The service depends only on the interface.

**Example:**
```java
// Domain
public interface OrderRepository {
    Optional<Order> findById(UUID id);
    Order save(Order order);
}

// Infrastructure
@Repository
public class JpaOrderRepository implements OrderRepository { ... }
```

**Trade-offs:**
- Pro: Domain stays framework-agnostic; easy to mock in unit tests
- Con: Extra interface file per aggregate root

**When NOT to use:**
CRUD-only services with no domain logic — the indirection adds no value.
```

---

## Anti-pattern Template

```markdown
### Anti-pattern: <Concise Name>

**What it looks like:**
```code
// The problematic code
```

**Why it's wrong:**
Concrete consequence (performance degradation, bug, maintenance cost).

**What to do instead:**
```code
// The correct code
```

**Detection:**
How to find this in the codebase:
`grep -r "<pattern>" src/main --include="*.java"`
```

### Example: Anti-pattern — Eager Fetch on Collections
```markdown
### Anti-pattern: FetchType.EAGER on @OneToMany

**What it looks like:**
```java
@OneToMany(fetch = FetchType.EAGER)
private List<OrderItem> items;
```

**Why it's wrong:**
Every Order query loads all items unconditionally, causing N+1 problems and loading data that is never used in most call sites.

**What to do instead:**
```java
@OneToMany(fetch = FetchType.LAZY)
private List<OrderItem> items;
// Use @EntityGraph or JOIN FETCH only when items are explicitly needed
```

**Detection:**
`grep -r "FetchType.EAGER" src/main --include="*.java"`
```

---

## Session Review — End-of-Session Protocol

At the end of each coding session, answer these four questions:

### Q1: What problem did I solve today that I've solved before?
→ If yes: there is a pattern to extract. Write it now.

### Q2: What bug or issue wasted time that could have been prevented by a rule?
→ If yes: there is an anti-pattern to document. Write it now.

### Q3: What architectural decision did I make that has long-term impact?
→ If yes: write an ADR (see below) and store it in `.copilot-runtime/decisions/`.

### Q4: What did I learn about the codebase that future-me will need?
→ If yes: add it to the relevant skill file or create a new one.

### Review Command
```bash
# List files changed in this session (helps trigger review)
git --no-pager diff --name-only HEAD~1..HEAD

# Show recent commits for context
git --no-pager log --oneline -10
```

---

## Skill Evolution

### Promote to Skill: Criteria
- Pattern used 3+ times in different contexts
- Pattern is generalizable (not project-specific)
- Pattern is actionable (reader can implement it without further research)
- Pattern has been tested in production (or staging at minimum)

### Deprecate a Skill: Criteria
- Underlying library/framework version changed and the pattern no longer applies
- Better alternative identified and validated
- Pattern caused more harm than good in production

### Deprecation Process
1. Add `> **DEPRECATED as of <date>:** Reason. Use <new-skill> instead.` at the top of the skill file.
2. Keep the file for 30 days for reference.
3. Delete after the deprecation period.

---

## Storage — Where Patterns Live

| Artifact | Location | Format |
|---|---|---|
| Reusable patterns by domain | `~/.copilot/skills/<domain>-patterns.md` | Markdown with template above |
| Project-specific anti-patterns | `.copilot-runtime/patterns/anti-patterns.md` | Markdown |
| Architectural decisions (ADRs) | `.copilot-runtime/decisions/ADR-<NNN>-<title>.md` | ADR template |
| Session learnings (ephemeral) | `.copilot-runtime/session-notes.md` | Free-form; reviewed at session end |

### ADR Template
```markdown
# ADR-001: <Title>

**Date:** YYYY-MM-DD
**Status:** Accepted | Superseded by ADR-XXX

## Context
What situation led to this decision?

## Decision
What was decided?

## Consequences
What are the positive and negative outcomes?

## Alternatives Considered
What other options were evaluated and why were they rejected?
```

---

## Quality Bar — What Makes a Good Pattern

A pattern entry is ready for the skill file when:

1. **Generalizable:** Applies to more than one class or feature in the codebase
2. **Actionable:** The reader can apply it without asking follow-up questions
3. **Tested:** The pattern has been applied and verified to work
4. **Concise:** The example fits in < 30 lines of code
5. **Honest about trade-offs:** Lists both pros and cons; no pattern is universally superior

A pattern entry is NOT ready if:
- It only applies to one specific class
- It requires reading 5 other documents to understand
- It is aspirational ("we should eventually...")

---

## Standalone Invocation (No Orchestrator)

This agent can be invoked directly without the orchestrator. When `.copilot-runtime/artifacts/context.json` is absent, three options are available:

**Option 1 — Run Diagnostic Commands Directly**
Execute targeted commands to gather context on the fly:
- `git --no-pager log --oneline -20` — recent commits to trigger pattern review
- `ls ~/.copilot/skills/ 2>/dev/null` — list existing skill files
- Pros: Fast, zero extra agent invocations
- Cons: Partial context; may miss cross-cutting concerns

**Option 2 — Invoke `codebase-explorer-agent` First**
Ask the user to run `codebase-explorer-agent`, wait for `.copilot-runtime/artifacts/context.json`, then re-run this agent.
- Pros: Richer, consistent context shared with all downstream agents
- Cons: Extra manual step; slightly slower

**Option 3 (RECOMMENDED) — Auto-Bootstrap then Proceed**
Invoke `codebase-explorer-agent` automatically, consume the resulting `context.json`, then continue execution without user intervention.
- Pros: Fully autonomous; deterministic context; no coordination overhead
- Cons: Slightly longer cold start
- **Why recommended:** Eliminates user coordination overhead and guarantees all agents share the same project baseline.

After context is available via any option, resume normal execution flow.
