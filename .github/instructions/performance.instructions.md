# Performance & Observability

## Parallel Tool Execution (CRITICAL)

**Always parallelize independent operations.** Sequential tool calls where there is no dependency is a performance bug.

### ✅ PARALLEL — call in one response:
- Reading multiple files (no dependency between them)
- Editing different files (no dependency between edits)
- Launching multiple explore/search agents for different questions
- Running grep + glob + view simultaneously
- Creating multiple new files

```
# CORRECT — one response, 3 parallel tool calls:
[read FileA] [read FileB] [read FileC]

# CORRECT — one response, 2 parallel edits:
[edit README.md] [edit install.sh]
```

### ❌ SEQUENTIAL — must wait for previous result:
- Read file A → then use A's content to edit file B
- Run build → then read the error output to fix code
- Ask user a question → then act on the answer
- Launch agent → then pass its output to the next agent

```
# CORRECT — sequential because B depends on A:
[read FileA]  →  [edit FileB using A's content]
```

### Key principle
> If you can describe two operations without mentioning each other, they can run in parallel.

When exploring a codebase: grep, glob, and view multiple files simultaneously — do not read one file, then decide to read the next.

## Performance

## Structured Logging

- Use JSON or Key-Value pair format — no string concatenation.
- Log state transitions and failures — not line-by-line flow.
- Include correlation/trace IDs to track requests across services.
- Never log sensitive fields (passwords, tokens, PII).

## Context Window Management

When working in large codebases:
- Avoid loading the full codebase — use `grep`, `glob`, and targeted reads.
- Stop when you have enough context to act — do not over-explore.
- For context-heavy tasks (large refactors, multi-file features), use `/compact` to summarize history before continuing.

## Model Selection

- **Fast/cheap models** (Haiku): lightweight agents, frequent invocations, simple lookups
- **Standard models** (Sonnet): main development work, orchestration, complex coding
- **Premium models** (Opus): complex architectural decisions, deep reasoning, security audits
