---
name: postgres-patterns
description: PostgreSQL optimization patterns for Java/Spring Boot applications. Covers indexing strategies, query analysis, connection pooling (HikariCP), partitioning, and JSON column patterns.
tools: ["Read", "Bash", "Grep"]
model: claude-sonnet-4-5
activation: ["postgres", "postgresql", "database optimization", "slow query", "index", "explain analyze", "hikari"]
---

# PostgreSQL Patterns

## Purpose

PostgreSQL optimization reference for Java/Spring Boot applications. Covers index strategy, query plan analysis with EXPLAIN ANALYZE, HikariCP connection pool tuning, table partitioning, JSONB patterns, locking for queue processing, vacuuming, and zero-downtime DDL migrations. Use this skill to diagnose and resolve database performance issues.

---

## Index Strategy

### B-tree (Default)
```sql
CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_status_created ON orders(status, created_at DESC);
```
**Use when:** Equality (`=`), range (`>`, `<`, `BETWEEN`), sorting (`ORDER BY`).

### GIN — Full-Text & JSONB
```sql
CREATE INDEX idx_products_attributes_gin ON products USING GIN(attributes);
CREATE INDEX idx_documents_content_gin ON documents USING GIN(to_tsvector('english', content));
```
**Use when:** JSONB containment (`@>`), full-text search (`@@`), array overlap (`&&`).

### Partial Index
```sql
CREATE INDEX idx_orders_pending ON orders(created_at) WHERE status = 'PENDING';
```
**Use when:** Queries always filter by a fixed predicate. Smaller index = faster lookups + less maintenance.

### Composite Index — Column Order Rule
Put the highest-cardinality or equality-filtered column first:
```sql
-- Good: equality on customer_id, then range on created_at
CREATE INDEX idx_orders_customer_created ON orders(customer_id, created_at DESC);

-- Bad: range on created_at first makes customer_id lookup inefficient
CREATE INDEX idx_orders_bad ON orders(created_at, customer_id);
```

### Pitfalls
- Every index slows INSERT/UPDATE/DELETE. Add indexes only when query analysis justifies it.
- `LIKE '%term%'` cannot use a B-tree index. Use `pg_trgm` GIN index for `ILIKE` or prefix search.

---

## EXPLAIN ANALYZE — Reading Query Plans

### Command
```sql
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) SELECT ...;
```

### Key Indicators
| Plan Node | Meaning | Action |
|---|---|---|
| `Seq Scan` on large table | No index used | Add index or check WHERE clause |
| `Index Scan` | Index used | Good |
| `Bitmap Heap Scan` | Index for many rows | Acceptable for moderate cardinality |
| `Hash Join` | In-memory join | Good for large datasets |
| `Nested Loop` with large outer | N iterations × inner cost | Check for missing FK index |
| High `rows=` estimate vs actual | Stale statistics | Run `ANALYZE table_name` |

### Reading Cost
```
cost=0.00..8.27  → startup_cost..total_cost (arbitrary planner units)
rows=100         → estimated row count
actual time=0.1..5.3 ms  → real execution time
```

Large discrepancy between `rows=` estimated and actual = stale statistics → run `ANALYZE`.

### Finding Slow Queries
```sql
SELECT query, calls, total_exec_time / calls AS avg_ms, rows
FROM pg_stat_statements
ORDER BY avg_ms DESC
LIMIT 20;
```
Requires `pg_stat_statements` extension enabled.

---

## HikariCP Tuning — Spring Boot

### Core Properties
```yaml
spring:
  datasource:
    hikari:
      maximum-pool-size: 10          # DO NOT set > DB max_connections / num_instances
      minimum-idle: 5                # Keep warm connections ready
      connection-timeout: 30000      # ms — fail fast if no connection available
      idle-timeout: 600000           # ms — release idle connections after 10 min
      max-lifetime: 1800000          # ms — recycle connections every 30 min
      leak-detection-threshold: 60000 # ms — log if connection held > 1 min (catches missing close())
      connection-test-query: SELECT 1  # PostgreSQL: not needed, use isValid() instead
      validation-timeout: 5000
```

### Connection Pooling Math
```
pool_size = (core_count × 2) + effective_spindle_count

Example: 4-core server, SSD (1 spindle)
  pool_size = (4 × 2) + 1 = 9  → use 10

For 3 application instances:
  each instance pool = 10
  total DB connections = 30
  Ensure PostgreSQL max_connections ≥ 30 + headroom
```

### Pitfalls
- Setting `maximumPoolSize` too high does NOT improve throughput. PostgreSQL context switching on 200+ connections degrades performance. Use PgBouncer for connection multiplexing at scale.
- `leakDetectionThreshold` will trigger on legitimate long-running transactions. Set it to 2× your expected worst-case transaction time.

---

## Partitioning — Large Tables

### Range Partitioning (by date)
```sql
CREATE TABLE orders (
    id BIGSERIAL,
    created_at TIMESTAMPTZ NOT NULL,
    ...
) PARTITION BY RANGE (created_at);

CREATE TABLE orders_2024_q1 PARTITION OF orders
    FOR VALUES FROM ('2024-01-01') TO ('2024-04-01');

CREATE TABLE orders_2024_q2 PARTITION OF orders
    FOR VALUES FROM ('2024-04-01') TO ('2024-07-01');
```

### Flyway Migration for Partitioned Tables
```sql
-- V5__partition_orders.sql
-- Step 1: Create new partitioned table
CREATE TABLE orders_partitioned (LIKE orders INCLUDING ALL) PARTITION BY RANGE (created_at);
-- Step 2: Create initial partition
CREATE TABLE orders_2024 PARTITION OF orders_partitioned FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
-- Step 3: Migrate data (batch to avoid lock)
INSERT INTO orders_partitioned SELECT * FROM orders WHERE created_at >= '2024-01-01';
```

### Pitfalls
- Queries on partitioned tables MUST include the partition key in the WHERE clause, or Postgres scans all partitions.
- Create indexes on the parent table — they are automatically inherited by partitions.

---

## JSONB Patterns

### When to Use JSONB
- Truly schemaless attributes that vary per row (e.g., product metadata, event payloads)
- Do NOT use JSONB as a substitute for proper relational modeling of core domain data

### Column Definition
```sql
ALTER TABLE products ADD COLUMN attributes JSONB;
CREATE INDEX idx_products_attributes ON products USING GIN(attributes);
```

### Spring Data + Hibernate
```java
@Column(columnDefinition = "jsonb")
@Type(JsonBinaryType.class)  // from hypersistence-utils
private Map<String, Object> attributes;
```

### Querying JSONB
```sql
-- Containment: find products where attributes contains {"color": "red"}
SELECT * FROM products WHERE attributes @> '{"color": "red"}';

-- Key existence
SELECT * FROM products WHERE attributes ? 'warranty';

-- Extract value
SELECT attributes->>'color' FROM products WHERE id = 1;
```

### Pitfalls
- JSONB is stored as binary; updating a single key rewrites the entire column. Avoid large JSONB columns with frequent partial updates.
- Do NOT index individual JSONB paths unless query analysis proves it's needed.

---

## Locking — `SELECT FOR UPDATE` and `SKIP LOCKED`

### Queue Pattern with `SKIP LOCKED`
```sql
SELECT id, payload
FROM outbox_events
WHERE status = 'PENDING'
ORDER BY created_at
LIMIT 10
FOR UPDATE SKIP LOCKED;
```
**`SKIP LOCKED`** skips rows locked by another transaction, enabling multiple workers to process the queue concurrently without blocking.

### Spring Data JPA
```java
@Lock(LockModeType.PESSIMISTIC_WRITE)
@QueryHints(@QueryHint(name = "jakarta.persistence.lock.timeout", value = "-2"))  // SKIP_LOCKED
@Query("SELECT e FROM OutboxEvent e WHERE e.status = 'PENDING' ORDER BY e.createdAt LIMIT 10")
List<OutboxEvent> findAndLockPending();
```

### Pitfalls
- Long-held locks cause table bloat and contention. Keep transactions that hold locks short.
- `SELECT FOR UPDATE` on a large result set can block entire tables.

---

## Vacuuming & Bloat

### Why Vacuuming Matters
PostgreSQL uses MVCC: deleted/updated rows are not removed immediately. Without vacuum, table bloat accumulates and query performance degrades.

### Check Autovacuum Status
```sql
SELECT schemaname, tablename, last_vacuum, last_autovacuum, n_dead_tup, n_live_tup
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC
LIMIT 20;
```

### Manual VACUUM ANALYZE
```sql
VACUUM ANALYZE orders;
```
Run after large batch deletes/updates.

### Tuning Autovacuum for High-Write Tables
```sql
ALTER TABLE orders SET (
    autovacuum_vacuum_scale_factor = 0.01,  -- vacuum when 1% of rows are dead (default: 20%)
    autovacuum_analyze_scale_factor = 0.005
);
```

---

## Migration Safety — Zero-Downtime DDL

### Safe Pattern: Add Column
```sql
-- Step 1: Add nullable column (instant, no table rewrite)
ALTER TABLE orders ADD COLUMN discount_amount NUMERIC(10,2);

-- Step 2: Backfill in batches (outside migration, in application code or separate job)
UPDATE orders SET discount_amount = 0 WHERE discount_amount IS NULL AND id BETWEEN 1 AND 10000;

-- Step 3: Add NOT NULL constraint with DEFAULT (validates existing, fast in PG 11+)
ALTER TABLE orders ALTER COLUMN discount_amount SET DEFAULT 0;
ALTER TABLE orders ALTER COLUMN discount_amount SET NOT NULL;
```

### Never Do This
```sql
-- UNSAFE: Acquires ACCESS EXCLUSIVE lock, blocks all reads/writes during column rename
ALTER TABLE orders RENAME COLUMN amount TO total_amount;
```

### Safe Rename Pattern
1. Add new column with new name
2. Copy data from old column (application writes to both)
3. Drop old column when no references remain

---

## Standalone Invocation (No Orchestrator)

This agent can be invoked directly without the orchestrator. When `.copilot-runtime/artifacts/context.json` is absent, three options are available:

**Option 1 — Run Diagnostic Commands Directly**
Execute targeted commands to gather context on the fly:
- `psql -c "SELECT query, calls, total_exec_time/calls as avg_ms FROM pg_stat_statements ORDER BY avg_ms DESC LIMIT 10;"` — find slow queries
- `grep -r "HikariCP\|maximumPoolSize\|datasource.hikari" src/main/resources --include="*.yml" --include="*.properties"`
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
