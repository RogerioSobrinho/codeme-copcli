# Performance & Observability

## Performance

- **Big O Awareness:** Optimize time/space complexity for collections and algorithms. Identify O(n²) loops before they hit production.
- **Resource Leaks:** Explicitly close streams, connections, and listeners. Use try-with-resources or `using` blocks.
- **Efficiency:** Be mindful of CPU/Memory allocations in hot paths.

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
