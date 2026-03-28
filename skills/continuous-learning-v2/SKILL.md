---
name: continuous-learning-v2
description: Instinct-based learning system with project scoping. Creates atomic instincts with confidence scoring and evolves them into skills, commands, or agents. v2 adds project-scoped instincts to prevent cross-project contamination. Use when tracking a heuristic specific to one project, promoting a project instinct to global scope, or reviewing project-specific patterns.
---

# Continuous Learning v2 — Project-Scoped Instincts

Extends the base continuous-learning skill with **project isolation**: React patterns stay in your React project, Java conventions stay in your Java project. Universal patterns (always validate input, grep before edit) are shared globally.

---

## What's Different from v1

| Feature | v1 | v2 |
|---|---|---|
| Scope | All instincts are global | Project-scoped by default, promotable to global |
| Storage | One flat file per pattern | Separate dirs per project |
| Cross-project | Contamination risk | Isolated by default |
| Promotion | Manual | Explicit `/promote` step |

---

## Instinct Model (same as v1 + scope field)

```markdown
## Instinct: {Name}

**Heuristic:** [One sentence — what does the instinct say?]

**Confidence:** {1-5} / 5

**Scope:** project | global

**Project:** {project name, or "all projects" if global}

**Evidence log:**
| # | Context | Outcome | Score delta |
|---|---|---|---|
| 1 | {Where this was applied} | {Worked/Failed/Partial} | +1 |

**Promoted to pattern:** [Link to pattern, or "pending"]
**Contradictions:** [What evidence challenged this?]
```

---

## Storage Layout

Create these directories manually — they are conventions, not managed by Copilot CLI.

```
~/.copilot/
├── instincts/
│   ├── global/                    # Apply in all projects
│   │   ├── grep-before-edit.md
│   │   └── always-validate-input.md
│   └── projects/
│       ├── my-spring-api/         # Project-specific
│       │   ├── avoid-eager-fetch.md
│       │   └── use-record-dtos.md
│       └── my-react-app/
│           └── prefer-signals.md
└── evolved/                       # Promoted to skills/agents/commands
    ├── skills/
    ├── agents/
    └── commands/
```

**Naming:** Use the git repository name (or any consistent short name) as the project folder name.

---

## Scope Decision Guide

| Pattern Type | Scope |
|---|---|
| Language/framework conventions | **project** |
| File structure preferences | **project** |
| Code style choices | **project** |
| Error handling strategy | **project** |
| Security practices | **global** |
| General best practices | **global** |
| Tool workflow preferences (grep before edit) | **global** |
| Git practices (conventional commits) | **global** |

**Rule of thumb:** If the pattern would be wrong or confusing in a different project, make it **project-scoped**.

---

## Three-Time Rule (same as v1, now with scope awareness)

| Occurrence | Action |
|---|---|
| 1st | Note as project-scoped instinct (confidence: 2) |
| 2nd | Update instinct (confidence: 3–4); note whether it's project-specific |
| 3rd in **same project** | Promote to named pattern in that project's SKILL.md section |
| 3rd across **different projects** | Promote to **global** instinct (confidence: 4–5); candidate for a new SKILL.md |

---

## Promotion: Project → Global

When the same instinct appears in 2+ projects with confidence ≥ 4, promote it to global scope.

**How:**
1. Move the instinct file from `~/.copilot/instincts/projects/{project}/` to `~/.copilot/instincts/global/`
2. Update the `Scope` field to `global` and remove the `Project` field
3. If confidence is 5 and it's been validated in 3+ contexts, promote further to a proper SKILL.md entry

---

## Review Protocol (end of session)

Ask four questions:

1. **What worked surprisingly well?** → New project instinct (confidence: 2)
2. **What required multiple attempts?** → Anti-pattern for this project
3. **What knowledge was missing?** → Gap in project-specific SKILL.md
4. **What assumption proved false?** → Update instinct or reduce confidence

If the answer to any question is project-specific → store under `projects/{name}/`.
If it applies universally → store under `global/`.

---

## ADR Storage

Architecture decisions belong in the project, not in the user's home:

```
{repo-root}/
└── docs/
    └── adr/
        ├── ADR-001-choose-flyway-over-liquibase.md
        └── ADR-002-use-record-dtos.md
```

Use the ADR template from the `continuous-learning` skill (v1).

---

## Migration from v1

v1 instincts stored in `.copilot-runtime/` can be migrated manually:
1. Move files from `.copilot-runtime/decisions/` → `docs/adr/` (project ADRs)
2. Move general patterns → `~/.copilot/instincts/global/`
3. Move project-specific patterns → `~/.copilot/instincts/projects/{name}/`
