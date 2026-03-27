---
name: strategic-compact
description: >
  Load when a session is running long (context window approaching 50%), when the conversation
  is cycling through the same problems without progress (decision fatigue or circular reasoning),
  before switching to a new major task within the same session, or when asked to "summarize
  where we are", "compact the context", "save our progress", or "what have we decided so far".
---

# Strategic Compact

A strategic compact is a deliberate context reduction operation. The goal: discard the reasoning history while preserving every decision, open question, and file reference needed to continue effectively.

## When to Compact

Compact proactively when any of these are true:

| Signal | Threshold |
|---|---|
| Context window usage | > 50% full |
| Circular reasoning | Same problem discussed 3+ times without resolution |
| Topic switch | Moving from one major task to a distinctly different one |
| Session length | > 1 hour of active work on a complex feature |
| Decision fatigue | Unable to make progress on a question that was simple an hour ago |

Do NOT wait until context is > 80% — compaction quality degrades when context is already too full.

---

## What to Preserve

```
✅ KEEP                              ❌ DISCARD
─────────────────────────────────    ─────────────────────────────────
Every architectural decision made    The reasoning chain that led there
Every file path created or modified  The line-by-line discussion of each change
Open questions still unresolved      Resolved questions and their debate
Current task and next step           Previous tasks already completed
Error messages seen and their fixes  The full exploration of why the error happened
Constraints discovered               How the constraints were discovered
```

---

## Compact Protocol

When compacting, produce this exact structure:

```markdown
# Session Compact — {date}

## Decisions Made
- [Architecture/approach decisions, each in one sentence]
- [Technology choices with rationale in ≤ 15 words]
- [Rejected alternatives with one-word reason: "rejected: performance"]

## Files Created / Modified
- `path/to/File.java` — what it does in one line
- `src/main/resources/application.yml` — what was changed

## Open Questions
- [ ] {Unresolved question} — context: {what do we need to decide}
- [ ] {Unresolved question} — options: {Option A} vs {Option B}

## Current Task
{What are we implementing right now, one sentence}

## Next Step
{Exactly what to do next, specific enough to resume without re-reading history}

## Constraints Discovered
- {Technical or domain constraint that limits solution space}
- {Constraint with implication: "X must be idempotent because..."}

## Errors Seen + Fixes Applied
- `ErrorMessage` → fix: {what was changed to resolve it}
```

---

## How to Use the Compact

After producing a compact:

1. **Store it** — paste into a file (`session-compact.md`) or keep it as the first message of the resumed session
2. **Start new context** — begin the next turn with: "Resuming from compact: [paste compact]"
3. **Verify continuity** — the first action after resuming should be "Given the compact, the next step is X. Proceeding."

The compact is the contract between your current session and the next one.

---

## Compact for Multi-Phase Features

When working on a feature that spans multiple sessions, maintain a running compact:

```markdown
# Feature: {Name} — Running Compact

## Phase 1 ✅ — {What was built}
Key decisions: ...
Files: ...

## Phase 2 🔄 — {Current phase}
In progress: ...
Open questions: ...
Next step: ...

## Phase 3 ⏳ — {Upcoming}
Planned approach: ...
Dependencies: Phase 2 must complete X first
```

---

## Anti-Patterns

**Too much preserved:**
```markdown
# BAD compact
We discussed whether to use Flyway or Liquibase. The reasoning was:
1. Flyway is simpler because...
2. Liquibase supports rollbacks but...
3. We considered the team's experience level...
# This is not a compact — it's a summary. Discard the reasoning, keep the decision.
```

**Too little preserved:**
```markdown
# BAD compact
We made some database decisions and wrote some files.
# Useless — no decisions, no files, no next step.
```

**Good compact:**
```markdown
## Decisions Made
- Database migrations: Flyway (rejected Liquibase: over-engineered for current scale)
- Migration naming: V{n}__{description}.sql in src/main/resources/db/migration

## Files Created / Modified
- `src/main/resources/db/migration/V1__create_orders_table.sql` — orders schema with indexes

## Next Step
Write V2 migration for order_items table. Schema: order_id FK, product_id, quantity, unit_price.
```

---

## Token Budget Rule

Apply the compact when you notice you're re-reading or re-explaining earlier parts of the conversation to make a decision. That's the clearest signal that the reasoning history is consuming budget needed for implementation.

The measure of a good compact: can you close this session, open a new one with just the compact as input, and continue without losing momentum? If yes, the compact is complete.
