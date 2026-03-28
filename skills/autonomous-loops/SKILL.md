---
name: autonomous-loops
description: >
  Load when using /fleet for parallel agents, enabling autopilot mode, running multi-step tasks
  autonomously, orchestrating independent subtasks in parallel, or when asked "how do I run multiple
  agents in parallel", "how do I use autopilot", "how do I run this without approving every step",
  "how do I set up an autonomous pipeline", "should I use /fleet or run sequentially".
---

# Autonomous Loops with Copilot CLI

Patterns for running multi-step tasks with maximum autonomy using native Copilot CLI features.

## The Two Autonomy Primitives

| Feature | What it does | Enables |
|---------|-------------|---------|
| **Autopilot mode** | Agent completes multi-step tasks without per-step approval | Sequential autonomy |
| **`/fleet`** | Multiple agents run simultaneously in parallel contexts | Parallel autonomy |

Combine both for maximum throughput on large, separable tasks.

---

## Autopilot Mode

### Setup (one-time)

```
/experimental     ← enables experimental features, setting persists
```

### Activate

Press `Shift+Tab` twice to cycle: `interactive → plan → autopilot`

Or launch directly from terminal:

```bash
copilot --allow-all --prompt "Implement the user authentication module per @docs/auth-spec.md"
```

`--allow-all` (alias: `--yolo`) skips all tool permission prompts. Use only in repos you trust.

### When to use autopilot

✅ **Good candidates:**
- Well-scoped tasks with a clear acceptance criterion (`"Add pagination to all endpoints that return lists"`)
- Tasks where you've already validated the approach manually
- Repetitive changes across many files (`"Add `@Valid` to all `@RequestBody` parameters in controllers"`)
- Running after a `planner` agent has produced a confirmed plan

❌ **Avoid autopilot for:**
- Tasks with significant design decisions mid-way (agent may choose wrong)
- Production-critical code without review
- Anything touching auth, payments, or data migrations

### Autopilot + `/delegate` workflow

```
1. copilot --allow-all --prompt "Implement X per @docs/spec.md"
2. Agent works autonomously, commits to local branch
3. /delegate   ← creates GitHub PR with full session context
4. Review the PR on GitHub before merging
```

---

## `/fleet` — Parallel Agents

`/fleet` spins up multiple agent instances that each run in their own context window simultaneously. Use when the task has truly independent subtasks.

### Activate

```
/fleet
```

Then describe the parallel work:

```
Run 3 agents in parallel:
- Agent 1: implement OrderService with unit tests
- Agent 2: implement PaymentGateway with unit tests
- Agent 3: write integration tests for the checkout flow
```

Monitor with `/tasks`.

### When subtasks are truly independent

A subtask is independent when:
- It touches different files than the other subtasks
- Its output doesn't depend on another subtask's output
- It can be reviewed and merged separately

```
# PARALLELIZABLE — different files, no shared state
Agent A: Migrate UserController to use UserResponse DTO
Agent B: Migrate OrderController to use OrderResponse DTO
Agent C: Migrate ProductController to use ProductResponse DTO

# NOT PARALLELIZABLE — B depends on A's output
Agent A: Create the Order entity
Agent B: Create OrderRepository using the Order entity from Agent A
```

### `/fleet` + autopilot combined

```bash
# Terminal 1 — backend
copilot --allow-all --prompt "Implement REST API for orders: CRUD endpoints, service, repository, tests"

# Terminal 2 — frontend (separate terminal, same repo)
copilot --allow-all --prompt "Implement order list UI: fetch from /api/orders, show table, handle loading/error states"
```

Each terminal runs a fully autonomous agent. Both merge into the same branch.

---

## Pipeline Pattern

For sequential pipelines where each step feeds the next, use the main session with `/compact` between steps:

```
Step 1: "Explore the codebase and generate a feature spec for X. Output to @docs/spec.md"
         ↓ (review spec.md)
/compact
         ↓
Step 2: "Implement X per @docs/spec.md. Write tests first."
         ↓ (review changes with /diff)
/compact
         ↓
Step 3: "Run the tests and fix any failures"
         ↓
/delegate
```

`/compact` between phases prevents context overflow on long pipelines.

---

## Verification Loop

Run a verification loop after autonomous work to confirm correctness:

```bash
# After autonomous implementation
/diff              # see all changes
/review            # native AI review of changes

# Or use the code-review agent for deep inspection
copilot --agent=code-review --prompt "Review all staged changes in this session"
```

---

## `--allow-all` Safety Checklist

Before running `--allow-all`:

- [ ] You trust all files in the current directory
- [ ] The repo has no uncommitted secrets
- [ ] You have a git commit to roll back to (`git stash` or clean commit)
- [ ] The task scope is well-defined — not open-ended exploration
- [ ] You'll review with `/diff` before committing anything

```bash
# Safe rollback pattern
git stash     # save clean state before autonomous run
copilot --allow-all --prompt "..."
git diff      # review changes
git stash pop # if you want to discard
```

---

## `/tasks` — Monitor Running Agents

```
/tasks
```

Shows all active background agents and shell sessions. Use to:
- Check if fleet agents are still running
- See which agent is working on which subtask
- Kill a runaway agent if needed
