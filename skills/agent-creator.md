# Agent Creator

## Purpose

Generates new Copilot CLI skill files for the agent-based workflow system. Collects requirements through structured questions, creates the skill at `~/.copilot/skills/<name>.md`, and optionally integrates it into `~/.copilot/workflows.json`. Validates all inputs before writing.

---

## Inputs

| Source | Description |
|---|---|
| User message | Agent purpose, domain, constraints |
| `~/.copilot/workflows.json` | Existing workflows for integration |
| `~/.copilot/skills/` | Existing skills (to avoid name collisions) |

---

## Required Information Collection

Ask the following before generating. If any is missing → return `need_more_input` with specific questions.

### 1. Agent Identity
- **Name:** kebab-case, descriptive (e.g., `payment-validation-agent`)
- **Purpose:** One sentence — what problem does this agent solve?
- **Domain context:** Which bounded context or subsystem does it operate in?

### 2. Inputs & Outputs
- **Input files:** Which `.copilot-runtime/` paths does it read?
- **Output files:** Which `.copilot-runtime/` subdirectory does it write to? (`artifacts/`, `analysis/`, `decisions/`, `tests/`)
- **Output file name:** e.g., `payment-validation-report.json`

### 3. Constraints
- Any technologies required (Spring Boot, Kafka, JPA, etc.)?
- Any quality bars (OWASP compliance, specific test coverage %)?
- Any agents it depends on (must run after)?

---

## Workflow Integration (MANDATORY DECISION)

After collecting agent identity, ask:

```
How should this agent be integrated?

Option 1: Standalone
- Not added to any workflow
- Invoked directly by name
- Pros: No impact on existing workflows
- Cons: Not part of automated sequences

Option 2: Add to workflow at manual position
- User specifies exact position in chosen workflow
- Pros: Full control over placement
- Cons: Requires knowledge of workflow structure

Option 3 (RECOMMENDED): Add to workflow at auto-inferred position
- Position inferred from agent phase (analysis → design → implementation → validation → release)
- Pros: Consistent ordering, no manual position management
- Cons: Inferred position may need adjustment
```

If Option 2 or 3:

Ask:
```
Which workflow(s)?

Option 1: refactoring
Option 2: new_feature
Option 3 (RECOMMENDED): Both new_feature and new_project
```

If Option 3 (auto-infer), determine phase from agent name/purpose:
- `analysis` phase: agents that read existing code/state (order: after impact-analysis-agent)
- `design` phase: agents that produce specs/decisions (order: after architecture-decision-agent)
- `implementation` phase: agents that guide code changes (order: after implementation-agent)
- `validation` phase: agents that verify quality (order: before code-review-agent)
- `release` phase: agents that assess release readiness (order: before release-risk-agent)

---

## Confirmation Gate

Before writing any file, output:

```json
{
  "status": "awaiting_plan_approval",
  "artifacts_ref": [],
  "questions": [
    "About to create ~/.copilot/skills/<name>.md and update workflows.json. Confirm? (yes/no)"
  ],
  "validation": { "passed": true, "issues": [] },
  "notes": "Skill definition preview written to .copilot-runtime/artifacts/new-agent-preview.json",
  "next_step_hint": "Respond 'yes' to confirm creation."
}
```

**STOP. Do not write files until confirmed.**

---

## Skill File Generation Template

Generate the new skill file using this structure:

```markdown
# <Agent Name>

## Purpose
<one paragraph>

## Inputs
| Source | Description |
|---|---|
| `.copilot-runtime/...` | ... |

## Outputs
Writes to `.copilot-runtime/<subdir>/<filename>.json`

## Execution Steps
1. ...

## Agent Contract — Output Format
{json contract}

## Validation Rules
- ...

## Definition of Ready
- ...

## Definition of Done
- ...

## Questions When Input Missing
- ...
```

---

## File I/O Rules

- **Read:** `~/.copilot/workflows.json`, `~/.copilot/skills/` (list only, no content)
- **Write:** `~/.copilot/skills/<name>.md`, `~/.copilot/workflows.json`
- Preview written to: `.copilot-runtime/artifacts/new-agent-preview.json`
- **Never** overwrite an existing skill without explicit user confirmation

---

## Validation Rules

- Agent name must be unique (check `~/.copilot/skills/`)
- Name must be kebab-case
- Output directory must be one of: `artifacts/`, `analysis/`, `decisions/`, `tests/`, `summaries/`
- If adding to workflow, validate resulting workflow has no duplicates
- Validate `workflows.json` is valid JSON after update

---

## Agent Contract — Output Format

```json
{
  "status": "ok | fail | need_more_input | awaiting_plan_approval",
  "artifacts_ref": [".copilot-runtime/artifacts/new-agent-preview.json"],
  "questions": [],
  "validation": {
    "passed": true,
    "issues": []
  },
  "notes": "",
  "next_step_hint": ""
}
```

---

## Definition of Ready

- Agent name provided
- Purpose provided
- Input/output paths provided
- Workflow integration decision made

If any missing → `need_more_input`.

---

## Definition of Done

- Skill file exists at `~/.copilot/skills/<name>.md`
- If integration chosen: `workflows.json` updated and validated
- Preview artifact written
- No existing files overwritten without confirmation
