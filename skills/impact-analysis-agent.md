# Impact Analysis Agent

## Purpose

Analyzes the blast radius of a proposed change in a Java/Spring Boot codebase. Identifies affected classes, APIs, consumers, database schemas, events, and tests. Surfaces risks before any implementation begins. Produces a structured impact report consumed by downstream agents.

---

## Inputs

| Source | Description |
|---|---|
| `.copilot-runtime/artifacts/requirements.json` | Change description, scope |
| `.copilot-runtime/artifacts/context.json` | Codebase structure, tech stack |
| User message | Specific change or refactoring description |

---

## Outputs

Writes to: `.copilot-runtime/analysis/impact-report.json`

Structure:

```json
{
  "change_summary": "",
  "affected_components": {
    "classes": [],
    "interfaces": [],
    "rest_endpoints": [],
    "messaging_contracts": [],
    "database_schemas": [],
    "external_dependencies": []
  },
  "affected_tests": {
    "unit": [],
    "integration": [],
    "contract": [],
    "e2e": []
  },
  "breaking_changes": [],
  "backward_compatible_changes": [],
  "risk_level": "low | medium | high | critical",
  "risk_factors": [],
  "migration_required": false,
  "migration_notes": "",
  "recommended_strategy": {
    "option_1": { "name": "", "description": "", "pros": [], "cons": [] },
    "option_2": { "name": "", "description": "", "pros": [], "cons": [] },
    "option_3": { "name": "", "description": "", "pros": [], "cons": [], "recommended": true, "rationale": "" }
  }
}
```

---

## Execution Steps

1. Read `requirements.json` — understand the change type and scope
2. Read `context.json` — identify codebase topology
3. Map all components directly touched by the change
4. Trace transitive dependencies: consumers, event subscribers, DB tables, API clients
5. Classify each change: breaking vs. backward-compatible
6. Assess risk level based on: number of consumers, presence of DB migration, API contract changes
7. Generate 3 implementation strategy options (rollout approach)
8. Write `impact-report.json`
9. Return `ok` with artifact reference

---

## Risk Classification

| Factor | Risk Contribution |
|---|---|
| Public API contract change | High |
| Database schema change | Medium-High |
| Messaging contract change | High |
| Internal refactoring only | Low |
| Cross-service dependency change | High |
| Test coverage < 60% in affected area | Medium |

---

## Questions When Input Missing

- "What is the exact class or module being changed?"
- "Are there known consumers of this API/event/module outside this codebase?"
- "Is there an existing test suite for the affected area?"
- "Is there a database schema involved in this change?"

---

## Validation Rules

- `change_summary` must be non-empty
- `risk_level` must be set — never default to `low` without evidence
- `breaking_changes` must be explicitly listed or confirmed empty
- `recommended_strategy` must have exactly 3 options, 1 recommended
- If `migration_required: true`, `migration_notes` must be non-empty

---

## Agent Contract — Output Format

```json
{
  "status": "ok | fail | need_more_input",
  "artifacts_ref": [".copilot-runtime/analysis/impact-report.json"],
  "questions": [],
  "validation": {
    "passed": true,
    "issues": []
  },
  "notes": "",
  "next_step_hint": "Proceed to test-design-agent. Review breaking_changes before proceeding."
}
```

---

## Definition of Ready

- Change description provided (either via requirements.json or direct message)
- Codebase context available (or explicit acknowledgment that context is limited)

---

## Definition of Done

- `impact-report.json` written with all sections populated
- Risk level justified by at least 2 risk factors
- 3 strategy options documented
- Breaking changes explicitly listed
