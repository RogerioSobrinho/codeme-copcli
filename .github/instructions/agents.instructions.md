# Available Agents

Use `/agent` to browse and select from all available agents. You can also invoke any agent by mentioning its name in your prompt — the CLI will delegate automatically.

**Three ways to invoke an agent:**
1. `/agent` → select from the list interactively
2. Mention in prompt: *"Use the planner agent to..."*, *"Run the security audit agent"*
3. `copilot --agent=planner --prompt "Plan this feature"`

| Agent | Purpose |
|-------|---------|
| `new-feature` | Full lifecycle: explore → plan → TDD → implement → self-review |
| `explore` | Map an unfamiliar codebase, answer "where is X", "how does Y work" |
| `fix` | Diagnose and fix broken builds, failing tests, runtime errors |
| `refactor` | Clean up and restructure code while preserving behavior |
| `code-review` | Review staged/unstaged changes for bugs, security, logic errors |
| `secure` | Security audit: Spring Security, auth, input validation, OWASP |
| `doc-writer` | Generate Javadoc, README, ADRs, OpenAPI annotations |
| `write-a-commit` | Generate a conventional commit message from staged changes |
| `init-project` | Generate `.github/copilot-instructions.md` for a new project |
| `planner` | Requirements → risks → step plan → waits for confirmation before coding |
| `tdd-guide` | Enforce RED→GREEN→REFACTOR, scaffold tests first, verify coverage |
| `new-project` | Bootstrap a new Spring Boot project from scratch |

## Repository Structure

```
agents/       Custom agent profiles (.agent.md) — each has YAML frontmatter + prose instructions
skills/       Knowledge reference bases — loaded on demand via /skills
.github/
  instructions/  Modular instruction files — loaded automatically, toggle via /instructions
```

## Native Copilot CLI Workflow Commands

Use these native commands to improve speed, context, and parallelism:

| Command | When to use |
|---------|-------------|
| `/fleet` | Enable **parallel subagent mode** — multiple agents run simultaneously on independent tasks (equivalent to Claude Code git worktrees). Use for large features with separable backend/frontend/tests work. |
| `/tasks` | View all **background tasks** (running subagents, shell sessions). Use to monitor parallel work in progress. |
| `/plan` | Enter **plan mode** (also: `Shift+Tab`) — constrains the current session to not write code until you approve. Uses the default model with no custom logic. **Prefer the `planner` agent (via `/agent`) for real planning work.** |
| `/compact` | **Summarize context history** to free up the context window. Use when `/context` shows > 50% usage or when cycling on the same problem. |
| `/delegate` | **Send session to Copilot Agent** — creates a GitHub PR from the current session. Use when you want the work landed as a PR without staying in the terminal. |
| `/context` | Show **current context window usage** as a visual chart. Check before starting large tasks. |
| `/diff` | Review **all changes made** in the current session before committing. |
| `/research` | Run **deep research** using GitHub search + web sources. Use before implementing unfamiliar APIs or libraries. |

### Parallelization with `/fleet`

When a task has independent subtasks (e.g., "build auth API + build auth UI + write auth tests"), use `/fleet` to execute them simultaneously rather than sequentially. Each fleet agent gets its own context window.

## Skills

Load relevant skills for domain-specific context:
- `/skills` — browse and toggle available skills
- Skills are loaded on demand — they add depth without bloating the base context

## MCP Tools

Two MCP servers are always active. Use them explicitly — they will not fire automatically.

### `sequential-thinking` — structured reasoning

Call `sequential-thinking-sequentialthinking` when the problem requires multi-step reasoning that benefits from explicit intermediate steps:

- Designing a non-trivial architecture (choosing between patterns, evaluating trade-offs)
- Debugging a non-obvious failure (multiple hypotheses, elimination process)
- Planning a refactor with many dependencies and blast radius analysis
- Any task where you would otherwise write a long chain-of-thought inline

**Do NOT use** for straightforward lookups, simple edits, or tasks where the answer is already clear.

### `memory` — persistent knowledge graph

The `memory-*` tools write to `~/.copilot/memory.jsonl` and persist **across sessions**. Use them to avoid re-discovering the same facts in every session.

**Store with `memory-create_entities` / `memory-add_observations`:**
- Architectural decisions that shaped the codebase ("uses hexagonal architecture — ports in `domain/port/`")
- Team conventions discovered from code ("all DTOs are records, never classes")
- Known gotchas or constraints ("Kafka consumer must use manual ack — auto-ack causes duplicates under load")
- Recurring patterns the user explicitly approves ("user prefers `@Nested` groups for related test cases")

**Retrieve with `memory-search_nodes` before starting work on a project:**
```
memory-search_nodes: "{project name}" or "{technology}" to surface stored context
```

**Do NOT store:** session-specific task tracking (use `sql` tool instead), ephemeral notes, or anything that changes frequently.
