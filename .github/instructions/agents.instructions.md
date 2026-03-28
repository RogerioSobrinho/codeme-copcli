# Available Agents

Invoke agents by name to delegate specialized work. Use `/agent` to browse all available agents.

| Agent | When to use |
|-------|-------------|
| `/new-feature` | Full lifecycle: explore → plan → TDD → implement → self-review |
| `/explore` | Map an unfamiliar codebase, answer "where is X", "how does Y work" |
| `/fix` | Diagnose and fix broken builds, failing tests, runtime errors |
| `/refactor` | Clean up and restructure code while preserving behavior |
| `/code-review` | Review staged/unstaged changes for bugs, security, logic errors |
| `/secure` | Security audit: Spring Security, auth, input validation, OWASP |
| `/doc-writer` | Generate Javadoc, README, ADRs, OpenAPI annotations |
| `/write-a-commit` | Generate a conventional commit message from staged changes |
| `/init-project` | Generate `.github/copilot-instructions.md` for a new project |
| `/planner` | Requirements → risks → step plan → waits for confirmation before coding |
| `/tdd-guide` | Enforce RED→GREEN→REFACTOR, scaffold tests first, verify coverage |

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
| `/plan` | Enter **plan mode** (also: `Shift+Tab`) — agent writes a plan and waits for approval before writing any code. Equivalent to our `/planner` agent but lighter. |
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
