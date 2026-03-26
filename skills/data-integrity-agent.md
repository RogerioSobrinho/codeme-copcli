# Data Integrity Agent

## Purpose

Validates data integrity concerns in a Java/Spring Boot + JPA project. Audits database constraints, migration scripts, transaction boundaries, idempotency, and consistency guarantees. Prevents data corruption and silent integrity failures at the database and application layer.

---

## Inputs

| Source | Description |
|---|---|
| `.copilot-runtime/artifacts/implementation-spec.json` | Transaction boundaries, entity definitions |
| `.copilot-runtime/artifacts/domain-model.json` | Invariants, Aggregates |
| `.copilot-runtime/analysis/impact-report.json` | Schema changes, migration required flag |
| `.copilot-runtime/artifacts/context.json` | DB engine, migration tool (Flyway/Liquibase) |

---

## Outputs

Writes to: `.copilot-runtime/analysis/data-integrity-report.json`

Structure:

```json
{
  "database_constraints": {
    "missing_not_null": [],
    "missing_unique_constraints": [],
    "missing_foreign_keys": [],
    "missing_indexes": []
  },
  "migration_analysis": {
    "tool": "flyway | liquibase | none",
    "scripts_validated": [],
    "backward_compatible": true,
    "breaking_changes": [],
    "rollback_scripts_present": false
  },
  "transaction_analysis": {
    "boundaries": [],
    "issues": [],
    "long_transactions": [],
    "missing_rollback_handling": []
  },
  "idempotency_analysis": {
    "write_operations": [],
    "idempotency_keys_present": false,
    "duplicate_protection": []
  },
  "consistency_risks": [],
  "recommendations": []
}
```

---

## Execution Steps

1. Read `implementation-spec.json` — extract `@Transactional` boundaries
2. Read `domain-model.json` — map invariants to DB constraints
3. Read `impact-report.json` — check `migration_required` flag
4. Validate DB constraints: every domain invariant must have a corresponding DB constraint
5. Validate migration scripts: versioned, sequential, backward-compatible
6. Validate transaction boundaries: no long transactions, proper propagation
7. Validate idempotency: write operations protected against duplicate execution
8. Write `data-integrity-report.json`
9. Return `ok` or `fail` with issues

---

## Data Integrity Rules

### Database Constraints
- Every non-nullable domain field must have `NOT NULL` constraint in schema
- Unique domain invariants must have `UNIQUE` constraint — not just application-level validation
- Foreign keys must be defined for all entity relationships
- Indexes required for all foreign keys and frequently queried columns

### Migrations (Flyway/Liquibase)
- Scripts must be versioned and immutable once deployed
- No `DROP COLUMN` / `DROP TABLE` without backward-compatible transition period
- Each migration must have a corresponding rollback script (or be explicitly rollback-safe)
- Migrations must be tested against production data volume (noted as requirement)

### Transactions
- `@Transactional` must be on application layer (use cases), not domain or infrastructure
- No `@Transactional(readOnly = false)` on read operations
- Long transactions (>500ms) must be flagged
- Never open a transaction before an external HTTP call
- `@Transactional` + `@Async` combinations are prohibited (transaction context lost)

### Idempotency
- All write endpoints must be idempotent or support idempotency keys
- Database upserts preferred over insert-or-fail for idempotent operations
- Kafka consumers must be idempotent (deduplication by message ID)

---

## Questions When Input Missing

- "What database engine is used? (PostgreSQL, MySQL, etc.)"
- "What migration tool is configured? (Flyway, Liquibase, or none)"
- "Are there existing Flyway/Liquibase scripts? If so, where?"
- "Are any of the write operations exposed to external clients who may retry?"

---

## Validation Rules

- Every domain invariant → DB constraint (no exceptions without explicit justification)
- Breaking migration without rollback script → `fail` status
- `@Transactional` + external HTTP call → `fail` status (data integrity risk)
- Missing idempotency on payment/financial writes → `fail` status

---

## Agent Contract — Output Format

```json
{
  "status": "ok | fail | need_more_input",
  "artifacts_ref": [".copilot-runtime/analysis/data-integrity-report.json"],
  "questions": [],
  "validation": {
    "passed": true,
    "issues": []
  },
  "notes": "",
  "next_step_hint": "Resolve critical integrity issues before proceeding to code-review-agent."
}
```

---

## Definition of Ready

- At least one of: `implementation-spec.json`, `domain-model.json`
- DB engine or migration tool known

---

## Definition of Done

- `data-integrity-report.json` written
- All domain invariants cross-referenced with DB constraints
- Migration scripts validated
- Transaction boundaries audited
- Idempotency gaps documented
