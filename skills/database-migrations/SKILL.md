---
name: database-migrations
description: >
  Load when creating Flyway migration scripts (V{n}__{description}.sql, naming conventions,
  flyway.locations), writing Liquibase changesets (databaseChangeLog, addColumn, createIndex),
  planning zero-downtime DDL (expand-contract pattern, ADD COLUMN nullable first, backfill,
  then NOT NULL), multi-tenant schema routing, testing migrations with @FlywayTest, or
  diagnosing FlywayException / migration checksum mismatch errors.
---

# Database Migrations

## Flyway vs Liquibase

| Criterion | Flyway | Liquibase |
|---|---|---|
| Format | SQL-first | XML/YAML/JSON/SQL |
| Learning curve | Low | Moderate |
| SQL transparency | Full | Abstracted |
| Rollback | Manual undo scripts | Built-in (fragile in practice) |
| Best for | Most Spring Boot services | Multi-DB dialect support required |

**Recommendation:** Use Flyway for most projects. SQL is explicit, readable, auditable.

---

## Flyway Naming Conventions

```
V{version}__{description}.sql    Versioned migration (always increasing)
R__{description}.sql             Repeatable (re-runs on content change)
U{version}__{description}.sql    Undo migration (Flyway Teams)
```

Examples:
```
V1__create_orders_table.sql
V2__add_customer_id_to_orders.sql
V10__add_index_orders_status.sql
R__create_order_summary_view.sql
U2__undo_add_customer_id_to_orders.sql
```

**Rule:** Never modify a migration file after it has been applied — Flyway validates checksums.

---

## Zero-Downtime DDL Patterns

### Safe: Add Nullable Column (3-migration approach)
```sql
-- V5__add_discount_amount_to_orders.sql
ALTER TABLE orders ADD COLUMN discount_amount NUMERIC(10,2);

-- V6__backfill_discount_amount.sql
UPDATE orders SET discount_amount = 0.00 WHERE discount_amount IS NULL;

-- V7__make_discount_amount_not_null.sql
ALTER TABLE orders ALTER COLUMN discount_amount SET NOT NULL;
ALTER TABLE orders ALTER COLUMN discount_amount SET DEFAULT 0.00;
```

### Safe: Add Index (PostgreSQL)
```sql
-- CONCURRENTLY avoids table lock; requires no transaction
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_customer_id ON orders(customer_id);
```

Configure Flyway: `spring.flyway.postgresql.transactional.lock=false` for this migration.

### Safe Column Rename (5-step)
1. Add new column
2. Dual-write both columns in application code
3. Backfill new column from old
4. Remove old column reads from application
5. Drop old column

### Never Do
```sql
-- Locks entire table
ALTER TABLE orders RENAME COLUMN amount TO total_amount;

-- Rewrites entire table
ALTER TABLE orders ALTER COLUMN description TYPE TEXT USING description::TEXT;
```

---

## Data Migrations — DDL vs DML Separation

Separate schema changes (DDL) from data changes (DML). DDL is fast; DML on large tables is slow.

### Idempotent DML
```sql
INSERT INTO order_statuses (code, label)
VALUES ('PENDING', 'Pending'), ('APPROVED', 'Approved')
ON CONFLICT (code) DO NOTHING;
```

### Large Table Backfill — Batched
```sql
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

Never run a single `UPDATE` on millions of rows — it holds a lock for the duration.

---

## Rollback Strategy

### Why Auto-Rollback Is Dangerous
Reverting a migration after data was written = data loss. Liquibase's built-in rollback only works safely for DDL.

### Manual Undo Scripts
```sql
-- U5__undo_add_discount_amount_to_orders.sql
ALTER TABLE orders DROP COLUMN IF EXISTS discount_amount;
```

### Emergency Rollback Decision
```
1. Is new code deployed?
   → NO: Deploy old code, skip migration.
   → YES: Is migration reversible without data loss?

2. Reversible without data loss?
   → YES: Run undo script, deploy old code.
   → NO: Fix forward (new migration to correct the state).
```

**Rule:** Always fix forward in production. Rollback is for pre-production.

---

## Testing Migrations

```java
@SpringBootTest
@Testcontainers
class FlywayMigrationTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    JdbcTemplate jdbcTemplate;

    @Test
    void allMigrationsApplySuccessfully() {
        // If the context loads, all migrations ran without error
        var count = jdbcTemplate.queryForObject("SELECT COUNT(*) FROM flyway_schema_history", Integer.class);
        assertThat(count).isGreaterThan(0);
    }
}
```

---

## Spring Boot Flyway Config

```yaml
spring:
  flyway:
    enabled: true
    baseline-on-migrate: false    # true only for migrating an existing DB
    out-of-order: false           # never apply out-of-order migrations
    locations: classpath:db/migration
    schemas: public
    table: flyway_schema_history  # default
```

---

## Liquibase (when needed)

```yaml
spring:
  liquibase:
    change-log: classpath:db/changelog/db.changelog-master.xml
    enabled: true
```

```xml
<!-- V1_create_orders.xml -->
<changeSet id="1" author="dev">
    <createTable tableName="orders">
        <column name="id" type="BIGINT" autoIncrement="true"><constraints primaryKey="true"/></column>
        <column name="status" type="VARCHAR(50)"><constraints nullable="false"/></column>
    </createTable>
</changeSet>
```
