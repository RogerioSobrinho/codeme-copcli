---
name: iterative-retrieval
description: Progressive context refinement pattern for working with large Java/Spring Boot codebases. Start narrow, expand context only when needed, avoid loading the entire codebase upfront.
tools: ["Read", "Bash", "Grep", "Glob"]
model: claude-sonnet-4-5
activation: ["large codebase", "context retrieval", "progressive search", "iterative context", "too many files"]
---

# Iterative Retrieval

## Purpose

Progressive context refinement strategy for working with large Java/Spring Boot codebases. Defines a layered approach to context loading: start with the minimum required context (failing test, error message, or user story), expand only when current context is insufficient, and stop when the change can be made. Prevents context window exhaustion and irrelevant-file noise.

---

## The Problem

Loading an entire codebase upfront:
- Exceeds context window limits for large projects (100k+ tokens)
- Buries the relevant signal in irrelevant code
- Slows down responses with noise from unrelated modules
- Causes false conclusions from unrelated code patterns

**The solution is progressive, demand-driven context loading.**

---

## Layer 1 — Entry Point Only

### What to Load
Start with exactly ONE of:
- The failing test and its assertion error
- The error message and stack trace (first 20 lines only)
- The user story or acceptance criterion
- The single file where the change is required

### How
```bash
# If starting from a failing test
mvn test -Dtest=OrderServiceTest#shouldProcessOrder 2>&1 | tail -40

# If starting from an error
grep -r "NullPointerException\|OrderNotFoundException" src --include="*.java" -l | head -3

# If starting from a user story
# Read only the acceptance criteria — no code yet
```

### What to Ask
"Can I make the required change with only this information?"
- YES → make the change
- NO → expand to Layer 2

### Pitfalls
- Do NOT load the entire service class when only one method is relevant
- Do NOT load test fixtures when you don't know if they're related yet

---

## Layer 2 — Direct Dependencies

### What to Load
Expand to files **directly imported or referenced** by the Layer 1 entry point.

### How
```bash
# Find all imports in the Layer 1 file
grep "^import" src/main/java/com/example/OrderService.java

# Find all files that reference the failing class
grep -r "OrderService\b" src/main --include="*.java" -l

# Find the interface a class implements
grep "implements\|extends" src/main/java/com/example/OrderService.java
```

### What to Load
- The interface that the failing class implements
- The direct collaborators (injected dependencies) referenced in the failing method
- The DTO/entity involved in the failing assertion

### What NOT to Load Yet
- Base classes unless the error references them
- Configuration files unless the error is a startup failure
- Utility classes unless explicitly called in the failing code path

### What to Ask
"Can I make the required change with Layer 1 + Layer 2?"
- YES → make the change
- NO → expand to Layer 3

---

## Layer 3 — Indirect Context

### What to Load
Load ONLY what Layer 2 is missing to complete the picture:
- Base classes and abstract methods
- Interfaces that define contracts
- Configuration classes if behavior depends on beans
- Related test utilities if writing tests

### How
```bash
# Find base classes
grep "extends Abstract\|extends Base" src/main --include="*.java" -l

# Find Spring configuration for a bean
grep -r "@Bean\|@Configuration" src/main --include="*.java" -l | xargs grep -l "OrderRepository\|PaymentService"

# Find related test utilities
find src/test -name "*Builder*" -o -name "*Factory*" -o -name "*TestBase*"
```

### What to Ask
"Can I make the required change with Layer 1 + Layer 2 + Layer 3?"
- YES → make the change
- NO → escalate: the change may require broader architectural understanding (use `codebase-explorer-agent`)

---

## Stop Condition

Stop expanding context when:
1. The required change is **fully understood** (what to change and why)
2. The impact scope is **bounded** (known which files will be affected)
3. The test to verify the change is **identifiable**

**Never load more context after the stop condition is met.** Additional context introduces risk of confusion, not additional clarity.

---

## Search Patterns — Grep Before Read

### Rule
Always search for the relevant symbol first. Read the file only after confirming it contains the relevant code.

### Pattern: Find Before Read
```bash
# WRONG: read a 500-line file hoping it contains the answer
cat src/main/java/com/example/service/OrderService.java

# RIGHT: search first, then read only the relevant section
grep -n "calculateDiscount\|applyPromotion" src/main/java/com/example/service/OrderService.java
# → Found at lines 142-167. Read only those lines.
```

### Common Search Patterns
```bash
# Find where a class is defined
grep -r "class OrderService\b" src/main --include="*.java"

# Find where a method is called
grep -rn "\.calculateDiscount(" src/main --include="*.java"

# Find all implementations of an interface
grep -r "implements OrderRepository\b" src/main --include="*.java"

# Find annotation usage
grep -r "@EventListener\|@TransactionalEventListener" src/main --include="*.java" -l

# Find configuration for a property
grep -r "spring.datasource\|hikari" src/main/resources

# Find test for a specific class
find src/test -name "OrderService*Test*" -o -name "*OrderService*Test*"
```

---

## Token Budget Awareness

### Estimate Before Loading
| File Type | Typical Token Cost |
|---|---|
| Single Java class (100-200 lines) | ~1,000–2,000 tokens |
| Large service (500+ lines) | ~5,000+ tokens |
| Full pom.xml | ~2,000 tokens |
| Single SQL migration | ~500 tokens |
| application.yml | ~500–2,000 tokens |
| Full test class (300 lines) | ~3,000 tokens |

### Budget Rules
- Layer 1: ≤ 3,000 tokens
- Layer 2: ≤ 10,000 tokens (cumulative)
- Layer 3: ≤ 25,000 tokens (cumulative)
- Beyond Layer 3: invoke `codebase-explorer-agent` with a specific question instead

### Prefer Grep Over Full File Read
```bash
# Cost: ~50 tokens for grep output
grep -n "findByCustomerId\|findByStatus" src/main/java/com/example/OrderRepository.java

# Cost: ~3,000 tokens for full file read
cat src/main/java/com/example/OrderRepository.java
```

---

## Context Pruning

### After Finding the Answer
Release irrelevant context from the working set:
- If Layer 1 was sufficient: discard Layer 2 and 3 candidates entirely
- If a file was searched but the answer was NOT in it: mark it as "checked, not relevant"
- If the failing test is fixed: the stack trace and error message are no longer relevant

### Pruning Checklist Before Making a Change
- [ ] Do I know exactly which file(s) to edit?
- [ ] Do I know the exact lines to change?
- [ ] Do I know the test that will verify the fix?
- [ ] Have I identified any side effects on other files?

If all YES: make the change. Context beyond this is noise.

---

## Iterative Loop Summary

```
START: Entry point (test / error / story)
  │
  ▼
Layer 1: Load entry point only
  │
  ├── Sufficient? ──YES──► MAKE CHANGE
  │
  ▼ NO
Layer 2: Load direct dependencies
  │
  ├── Sufficient? ──YES──► MAKE CHANGE
  │
  ▼ NO
Layer 3: Load indirect context (base classes, config, test utils)
  │
  ├── Sufficient? ──YES──► MAKE CHANGE
  │
  ▼ NO
ESCALATE: Invoke codebase-explorer-agent with specific question
  │
  ▼
Resume with enriched context
```

---

## Standalone Invocation (No Orchestrator)

This agent can be invoked directly without the orchestrator. When `.copilot-runtime/artifacts/context.json` is absent, three options are available:

**Option 1 — Run Diagnostic Commands Directly**
Execute targeted commands to gather context on the fly:
- `git --no-pager diff --name-only HEAD~1` — files changed recently (narrow search scope)
- `mvn test 2>&1 | grep -E "FAILED|ERROR" | head -10` — entry point for failing tests
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
