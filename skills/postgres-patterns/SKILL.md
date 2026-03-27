---
name: postgres-patterns
description: >
  Load when analyzing slow PostgreSQL queries with EXPLAIN (ANALYZE, BUFFERS), tuning HikariCP
  (maximumPoolSize, connectionTimeout, idleTimeout, keepaliveTime), creating B-tree, GIN, or
  partial indexes, using JSONB operators (@>, ?, #>>), diagnosing pg_stat_activity blocking or
  long-running transactions, partitioning large tables (PARTITION BY RANGE), or planning
  zero-downtime DDL on large PostgreSQL tables (concurrent index creation, lock timeouts).
---

# PostgreSQL Patterns

## Index Strategy

### B-tree (Default)
```sql
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_status_created ON orders(status, created_at DESC);
```
Use for: equality (`=`), range (`>`, `<`, `BETWEEN`), sorting.

### GIN — Full-Text & JSONB
```sql
CREATE INDEX idx_products_attributes_gin ON products USING GIN(attributes);
CREATE INDEX idx_documents_content ON documents USING GIN(to_tsvector('english', content));
```

### Partial Index
```sql
CREATE INDEX idx_orders_pending ON orders(created_at) WHERE status = 'PENDING';
```
Smaller, faster, lower maintenance for queries with a fixed predicate.

### Composite Index — Column Order Rule
Highest-cardinality equality column first, then range:
```sql
CREATE INDEX idx_orders_customer_created ON orders(customer_id, created_at DESC);
```

---

## EXPLAIN ANALYZE

```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) SELECT ...;
```

| Plan Node | Meaning | Action |
|---|---|---|
| `Seq Scan` on large table | No index used | Add index or check WHERE clause |
| `Index Scan` | Index used | Good |
| `Bitmap Heap Scan` | Index for many rows | Acceptable for moderate cardinality |
| `Nested Loop` on large outer | N iterations × inner cost | Check for missing FK index |
| High `rows=` vs actual | Stale statistics | `ANALYZE table_name` |

Find slow queries:
```sql
SELECT query, calls, total_exec_time / calls AS avg_ms, rows
FROM pg_stat_statements ORDER BY avg_ms DESC LIMIT 20;
```

---

## HikariCP Tuning

```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 10          # DO NOT set > DB max_connections / num_instances
      minimum-idle: 5
      connection-timeout: 30000      # ms — fail fast
      idle-timeout: 600000           # ms — release idle after 10 min
      max-lifetime: 1800000          # ms — recycle connections every 30 min
      leak-detection-threshold: 60000 # ms — log if connection held > 1 min
      validation-timeout: 5000
```

Pool sizing formula:
```
pool_size = (core_count × 2) + effective_spindle_count
```

**Pitfall:** High `maximumPoolSize` does NOT improve throughput — PostgreSQL context switching on 200+ connections degrades performance. Use PgBouncer for scale.

---

## Partitioning (Range by date)

```sql
CREATE TABLE orders (
    id BIGSERIAL,
    created_at TIMESTAMPTZ NOT NULL,
    ...
) PARTITION BY RANGE (created_at);

CREATE TABLE orders_2024_q1 PARTITION OF orders
    FOR VALUES FROM ('2024-01-01') TO ('2024-04-01');
```

**Pitfall:** Queries must include the partition key in WHERE, or Postgres scans all partitions.

---

## JSONB Patterns

```sql
ALTER TABLE products ADD COLUMN attributes JSONB;
CREATE INDEX idx_products_attributes ON products USING GIN(attributes);

-- Containment query (uses GIN index)
SELECT * FROM products WHERE attributes @> '{"color": "red"}';

-- Key existence
SELECT * FROM products WHERE attributes ? 'warranty';

-- Extract value
SELECT attributes->>'color' FROM products WHERE id = 1;
```

Spring Data with Hibernate:
```java
@Column(columnDefinition = "jsonb")
@Type(JsonBinaryType.class)  // from hypersistence-utils
private Map<String, Object> attributes;
```

---

## Locking — SELECT FOR UPDATE SKIP LOCKED

Queue processing pattern (safe for concurrent workers):
```sql
SELECT * FROM jobs
WHERE status = 'PENDING'
ORDER BY created_at
LIMIT 10
FOR UPDATE SKIP LOCKED;
```
`SKIP LOCKED` means each worker gets a different batch without blocking others.

---

## Vacuuming

```sql
-- Check tables that need vacuuming
SELECT schemaname, tablename, n_dead_tup, last_autovacuum
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC LIMIT 20;

-- Manual vacuum on a specific table
VACUUM (ANALYZE, VERBOSE) orders;
```

High dead tuple count on frequently-updated tables = autovacuum not keeping up → increase `autovacuum_vacuum_scale_factor` or run manual VACUUM.

---

## Zero-Downtime DDL Patterns

### Safe: Add Nullable Column
```sql
-- Step 1: Add nullable (instant, no lock)
ALTER TABLE orders ADD COLUMN discount_amount NUMERIC(10,2);

-- Step 2: Backfill in batches (separate migration)
UPDATE orders SET discount_amount = 0.00 WHERE discount_amount IS NULL;

-- Step 3: Set NOT NULL after backfill (separate migration)
ALTER TABLE orders ALTER COLUMN discount_amount SET NOT NULL;
```

### Safe: Add Index Concurrently
```sql
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_orders_customer_id ON orders(customer_id);
```
`CONCURRENTLY` avoids table lock but cannot run inside a transaction. Configure Flyway: `flyway.postgresql.transactional.lock=false` per-migration.

### Never Do
```sql
-- Locks entire table
ALTER TABLE orders RENAME COLUMN amount TO total_amount;

-- Rewrites entire table (if changing type)
ALTER TABLE orders ALTER COLUMN description TYPE TEXT USING description::TEXT;
```

Safe rename pattern: add new column → dual-write in app → backfill → remove old reads → drop old column.
