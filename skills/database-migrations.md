---
name: database-migrations
description: Database migration patterns for Java/Spring Boot using Flyway and Liquibase. Covers naming conventions, rollback strategies, data migrations, multi-tenant schemas, and zero-downtime DDL.
tools: ["Read", "Bash", "Grep", "Glob"]
model: claude-sonnet-4-5
activation: ["flyway", "liquibase", "database migration", "schema migration", "ddl migration", "db migration"]
---

# Database Migrations

## Purpose

Migration management reference for Java/Spring Boot applications using Flyway and Liquibase. Covers tool selection, naming conventions, zero-downtime DDL patterns, data migration safety, rollback strategy, multi-tenant schema management, and migration testing. Use this skill when designing schema changes, auditing migration files, or planning backward-compatible DDL for zero-downtime deployments.

---

## Flyway vs Liquibase — Decision Guide

| Criterion | Flyway | Liquibase |
|---|---|---|
| Format | SQL-first (native SQL) | XML/YAML/JSON/SQL |
| Learning curve | Low | Moderate |
| SQL transparency | Full — you write exact SQL | Medium — abstracted in changelogs |
| Rollback | Manual undo scripts | Built-in `rollback` tag (fragile in practice) |
| Multi-DB support | Good | Excellent (abstracts dialects) |
| Spring Boot integration | `spring.flyway.*` — first-class | `spring.liquibase.*` — first-class |
| Best for | Most Spring Boot services | When multi-database dialect support is required |

### Recommendation
**Use Flyway** for most Spring Boot projects. SQL is explicit, readable, and auditable. Liquibase adds value only when targeting multiple database vendors from the same codebase.

---

## Flyway Naming Conventions

### Versioned Migration
```
V{version}__{description}.sql
```
Examples:
```
V1__create_orders_table.sql
V2__add_customer_id_to_orders.sql
V10__add_index_orders_status.sql
```

### Rules
- Version must be increasing: `V1`, `V2`, `V10` (not `V1.1`, `V1.2`)
- Double underscore (`__`) separates version from description
- Description: lowercase, underscores, no spaces
- NEVER modify a migration file after it has been applied — Flyway validates checksums

### Repeatable Migration
```
R__{description}.sql
```
Re-runs whenever the file content changes. Use for views, stored procedures.
```
R__create_order_summary_view.sql
```

### Undo Migration (Flyway Teams)
```
U{version}__{description}.sql
```
```
U2__undo_add_customer_id_to_orders.sql
```

---

## Zero-Downtime DDL Patterns

### Safe: Add Nullable Column
```sql
-- V5__add_discount_amount_to_orders.sql
-- Step 1 (this migration): Add nullable — instant, no lock
ALTER TABLE orders ADD COLUMN discount_amount NUMERIC(10,2);
```
```sql
-- V6__backfill_discount_amount.sql
-- Step 2: Backfill in batches via application job or migration
UPDATE orders SET discount_amount = 0.00 WHERE discount_amount IS NULL;
```
```sql
-- V7__make_discount_amount_not_null.sql
-- Step 3: Set NOT NULL after backfill completes
ALTER TABLE orders ALTER COLUMN discount_amount SET NOT NULL;
ALTER TABLE orders ALTER COLUMN discount_amount SET DEFAULT 0.00;
```

### Safe: Add Index Concurrently (PostgreSQL)
```sql
-- V8__add_index_orders_customer_id.sql
-- CONCURRENTLY avoids table lock; cannot run inside a transaction
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_customer_id ON orders(customer_id);
```
**Note:** Flyway wraps migrations in transactions by default. For `CONCURRENTLY`, configure:
```java
// In FlywayMigrationStrategy or annotation
@Flyway(outOfOrder = false, mixed = false)
```
Or use `flyway.postgresql.transactional.lock=false` per-migration.

### Unsafe — Never Do
```sql
-- NEVER: locks entire table, blocks reads/writes
ALTER TABLE orders RENAME COLUMN amount TO total_amount;

-- NEVER: rewrites entire table
ALTER TABLE orders ALTER COLUMN description TYPE TEXT USING description::TEXT;  -- if changing type
```

### Safe Column Rename Pattern
1. `V10__add_total_amount_column.sql` — add new column
2. Application writes to BOTH columns (dual-write)
3. `V11__backfill_total_amount.sql` — copy data from old to new
4. Remove old column read from application code
5. `V12__drop_amount_column.sql` — drop old column

---

## Data Migrations — DDL vs DML Separation

### Rule
Separate schema changes (DDL) from data changes (DML) into different migration files.

**Why:** DDL is usually fast (metadata only). DML on large tables can be slow and should be batched.

### Idempotent DML
```sql
-- V9__seed_order_statuses.sql
INSERT INTO order_statuses (code, label)
VALUES ('PENDING', 'Pending'), ('APPROVED', 'Approved'), ('CANCELLED', 'Cancelled')
ON CONFLICT (code) DO NOTHING;
```

### Large Table Backfill — Never in a Single Statement
```sql
-- BAD: locks table for duration on 10M rows
UPDATE orders SET migrated_status = NEW_STATUS_MAP[status];

-- GOOD: batched via a loop or separate application job
-- V10__backfill_migrated_status_batch.sql
DO $$
DECLARE
  batch_size INT := 10000;
  rows_updated INT;
BEGIN
  LOOP
    UPDATE orders SET migrated_status = 'APPROVED'
    WHERE migrated_status IS NULL AND status = 'DONE'
    LIMIT batch_size;
    GET DIAGNOSTICS rows_updated = ROW_COUNT;
    EXIT WHEN rows_updated = 0;
    PERFORM pg_sleep(0.1);
  END LOOP;
END $$;
```

---

## Rollback Strategy

### Why Auto-Rollback Is Dangerous
- Reverting a migration that added a column and then the application wrote data to it = data loss.
- Reverting a migration that dropped a column = cannot restore already-deleted data.
- Liquibase's built-in `rollback` only works safely for DDL; DML rollbacks are data-lossy.

### Manual Undo Scripts Pattern
Write explicit undo scripts tested before deployment:

```sql
-- U5__undo_add_discount_amount_to_orders.sql
ALTER TABLE orders DROP COLUMN IF EXISTS discount_amount;
```

### Emergency Rollback Decision Tree
```
1. Is the new code version deployed?
   → If NO: Do not run migration. Deploy old code.
   → If YES: Check if migration is reversible without data loss.

2. Is the migration reversible without data loss?
   → If YES: Run undo script, deploy old code.
   → If NO: Fix forward (new migration to correct the state).
```

**Rule:** Always fix forward on production. Rollback is for pre-production environments.

---

## Multi-tenant — Schema-per-Tenant

### Flyway Config
```yaml
spring:
  flyway:
    schemas: tenant_a, tenant_b, tenant_c
    default-schema: public
```

### FlywayMigrationStrategy Bean
```java
@Bean
FlywayMigrationStrategy tenantMigrationStrategy(TenantRepository tenantRepository) {
    return flyway -> {
        tenantRepository.findAll().forEach(tenant -> {
            Flyway.configure()
                .dataSource(flyway.getConfiguration().getDataSource())
                .schemas(tenant.getSchemaName())
                .locations("classpath:db/migration/tenant")
                .load()
                .migrate();
        });
    };
}
```

### Pitfalls
- Schema-per-tenant requires each tenant schema to be pre-created before migration runs.
- Never share migration history tables across tenants — each schema has its own `flyway_schema_history`.

---

## Testing — `@FlywayTest` + Testcontainers

### Testcontainers Migration Verification
```java
@SpringBootTest
@Testcontainers
class MigrationIntegrityTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired Flyway flyway;

    @Test
    void allMigrationsApplyCleanly() {
        flyway.clean();  // only in test profile!
        var result = flyway.migrate();
        assertThat(result.success).isTrue();
        assertThat(result.warnings).isEmpty();
    }
}
```

### `flyway.clean-disabled=true` in Production
```yaml
# application-production.yml
spring:
  flyway:
    clean-disabled: true  # NEVER allow flyway.clean() in production
```

---

## Baseline — Legacy Databases

When applying Flyway to an existing database:
```yaml
spring:
  flyway:
    baseline-on-migrate: true
    baseline-version: 0
    baseline-description: "Existing schema before Flyway"
```

This marks all existing migrations as applied and starts tracking from the baseline. Run `baseline-on-migrate` ONCE; disable afterward.

---

## Common Mistakes

| Mistake | Problem | Fix |
|---|---|---|
| Modifying an applied migration | Flyway checksum mismatch → startup failure | Never modify; create a new migration |
| Renaming column in one migration | Table lock in production | Use dual-write pattern across 3 migrations |
| Missing `ON CONFLICT` on seed data | Migration fails on re-run | Always use idempotent DML |
| Column type change without data migration | Data truncation or conversion error | Migrate data first, then change type |
| Running `CONCURRENTLY` inside transaction | PostgreSQL error | Mark migration as non-transactional |
| No `baseline-on-migrate=false` after baselining | Baseline re-applies on clean DB | Disable after initial setup |

---

## Standalone Invocation (No Orchestrator)

This agent can be invoked directly without the orchestrator. When `.copilot-runtime/artifacts/context.json` is absent, three options are available:

**Option 1 — Run Diagnostic Commands Directly**
Execute targeted commands to gather context on the fly:
- `find src/main/resources/db/migration -name "*.sql" | sort` — list existing migrations
- `grep -r "flyway\|liquibase" pom.xml` — check which tool is used
- Pros: Fast, zero extra agent invocations
- Cons: Partial context; may miss cross-cutting concerns

**Option 2 — Invoke `codebase-explorer-agent` First**
Ask the user to run `codebase-explorer-agent`, wait for `.copilot-runtime/artifacts/context.json`, then re-run this agent.
- Pros: Richer, consistent context shared with all downstream agents
- Cons: Extra manual step; slightly slower

**Option 3 (RECOMMENDED) — Auto-Bootstrap then Proceed**
Invoke `codebase-explorer-agent` automatically, consume the resulting `context.json`, then continue execution without user intervention.
- Pros: Fully autonomous; deterministic context; no coordination overhead
- Cons: Slightly longer cold start
- **Why recommended:** Eliminates user coordination overhead and guarantees all agents share the same project baseline.

After context is available via any option, resume normal execution flow.
