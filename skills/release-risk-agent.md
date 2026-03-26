# Release Risk Agent

## Purpose

Assesses the risk of releasing a feature or change to production in a Java/Spring Boot project. Evaluates breaking changes, backward compatibility, rollback complexity, deployment dependencies, and feature flag strategy. Produces a release risk report and go/no-go recommendation.

---

## Inputs

| Source | Description |
|---|---|
| `.copilot-runtime/analysis/impact-report.json` | Breaking changes, migration requirements |
| `.copilot-runtime/artifacts/code-review-report.json` | Unresolved findings |
| `.copilot-runtime/analysis/data-integrity-report.json` | Schema migration status |
| `.copilot-runtime/analysis/security-report.json` | Open security findings |
| `.copilot-runtime/artifacts/requirements.json` | Acceptance criteria completion |

---

## Outputs

Writes to: `.copilot-runtime/artifacts/release-risk-report.json`

Structure:

```json
{
  "release_name": "",
  "risk_level": "low | medium | high | critical",
  "go_no_go": "go | no_go | conditional_go",
  "blocking_issues": [],
  "warnings": [],
  "breaking_changes": {
    "api_contracts": [],
    "database_schema": [],
    "messaging_contracts": [],
    "backward_compatible": true
  },
  "rollback_plan": {
    "feasible": true,
    "complexity": "low | medium | high",
    "steps": [],
    "irreversible_changes": []
  },
  "deployment_dependencies": [],
  "feature_flag_recommendation": {
    "required": false,
    "flag_name": "",
    "strategy": "trunk_based | canary | ring_deployment",
    "rationale": ""
  },
  "acceptance_criteria_coverage": {
    "total": 0,
    "verified": 0,
    "unverified": []
  },
  "release_options": {
    "option_1": {},
    "option_2": {},
    "option_3_recommended": {}
  }
}
```

---

## Execution Steps

1. Read `impact-report.json` — extract breaking changes list
2. Read `code-review-report.json` — count unresolved critical/high findings
3. Read `data-integrity-report.json` — verify migration status
4. Read `security-report.json` — verify all critical security findings resolved
5. Read `requirements.json` — verify acceptance criteria coverage
6. Assess rollback feasibility: is it reversible?
7. Assess deployment dependencies: DB migration before code, feature flags
8. Generate 3 release strategy options
9. Set `go_no_go` based on blocking issues
10. Write `release-risk-report.json`
11. Return `ok` (go/conditional_go) or `fail` (no_go)

---

## Go / No-Go Criteria

### Automatic NO-GO
- Any unresolved `critical` finding in code-review, security, or data-integrity reports
- Breaking API contract change without versioning strategy
- Irreversible DB migration without data backup confirmation
- Acceptance criteria < 80% verified

### Conditional GO (requires sign-off)
- `high` findings with accepted risk and documented justification
- Schema migration required (must run migration first)
- Performance NFR not fully met but within acceptable range

### GO
- All critical and high findings resolved
- All acceptance criteria verified
- Rollback plan documented
- No irreversible changes without backup

---

## Rollback Complexity Assessment

| Scenario | Complexity |
|---|---|
| Code-only change | Low |
| Code + backward-compatible DB migration | Medium |
| Code + breaking DB migration | High |
| Messaging contract change with consumers | High |
| Data transformation / backfill | High |
| External API contract change | High |

---

## Feature Flag Recommendation

Required when:
- Risk level is `high` or `critical`
- Rollback complexity is `high`
- Affecting > 10% of user traffic
- Experimental or A/B feature

Strategy options (present as 3 options):
1. **Trunk-based flag** — simple on/off toggle, minimal overhead
2. **Canary deployment** — gradual rollout by percentage
3. **Ring deployment (RECOMMENDED for high risk)** — internal → early adopters → general

---

## Questions When Input Missing

- "Has the code review been completed and approved?"
- "Are there downstream services or consumers that must be deployed first?"
- "Is a database migration part of this release?"
- "What is the rollback window? (time before rollback becomes infeasible)"

---

## Validation Rules

- Unresolved critical code-review finding → automatic `no_go`
- Irreversible migration without backup → `no_go`
- Acceptance criteria < 80% → `no_go`
- Release options must present exactly 3 strategies, 1 recommended

---

## Agent Contract — Output Format

```json
{
  "status": "ok | fail | need_more_input",
  "artifacts_ref": [".copilot-runtime/artifacts/release-risk-report.json"],
  "questions": [],
  "validation": {
    "passed": true,
    "issues": []
  },
  "notes": "",
  "next_step_hint": "If go or conditional_go, proceed to cicd-agent. If no_go, resolve blocking issues."
}
```

---

## Definition of Ready

- `code-review-report.json` exists (or explicitly skipped with justification)
- `impact-report.json` exists

---

## Definition of Done

- `release-risk-report.json` written
- `go_no_go` field set with justification
- Rollback plan documented
- 3 release strategy options provided
- All acceptance criteria verified or unverified list populated
