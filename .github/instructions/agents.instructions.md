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

## Skills

Load relevant skills for domain-specific context:
- `/skills` — browse and toggle available skills
- Skills are loaded on demand — they add depth without bloating the base context
