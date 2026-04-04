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

- Prefer profiling before optimizing — measure with JFR, async-profiler, or `jstack` before assuming the bottleneck.
- Cache reads, not writes. Invalidation is harder than it looks — prefer short TTLs over complex eviction logic.
- Use connection pool metrics (`HikariCP`, `pool.size`, `pool.pending`) to detect saturation before it becomes an outage.
- For Spring Boot: `spring-boot-actuator` + Micrometer exposes JVM metrics (heap, GC, threads) at `/actuator/metrics`.

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
- **Auto-compaction:** The CLI automatically compresses history at 95% token limit — no action needed. `/compact` is for proactive compression before that threshold.

## Phased Execution (Large Tasks)

When a task touches more than 5 files or spans multiple modules:
1. **Phase the work** — break into batches of 5–8 files max per context window
2. **Use sub-agents** — each agent gets its own fresh ~167K-token context; use `/fleet` for independent subtasks
3. **Clean before refactoring** — delete dead code and unused imports FIRST; reduces context churn and prevents the agent from reasoning about obsolete code
4. **Re-read critical files** after 15+ turns — auto-compaction may have compressed your memory of earlier reads

## Context Decay Warning

After a long conversation (15+ turns) or after `/compact` fires:
- Do NOT assume you remember the file contents you read earlier
- Re-read any file you're about to edit if it was last read more than 10 turns ago
- Re-run key searches if you're unsure whether results are still accurate

## Quota Management

- Use `/usage` to check premium requests consumed in the current session (quota, duration, lines edited, tokens per model).
- Check `/context` before starting large tasks — if usage is above 50%, run `/compact` first.
- **Autopilot mode** (`Shift+Tab` to cycle, requires `/experimental` to enable) runs multi-step tasks autonomously. Use with `--allow-all` to skip per-tool approvals in trusted sessions. Combine with `/fleet` for parallel autonomous agents.
- `COPILOT_HOME` env var changes the config directory from `~/.copilot` to any path. Set in `~/.bashrc` before launching if you want isolated configs per environment.

## Model Selection

- **Fast/cheap models** (Haiku): lightweight agents, frequent invocations, simple lookups
- **Standard models** (Sonnet): main development work, orchestration, complex coding
- **Premium models** (Opus): complex architectural decisions, deep reasoning, security audits
