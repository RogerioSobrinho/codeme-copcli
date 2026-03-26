# Performance Agent

## Purpose

Identifies and analyzes performance bottlenecks in a Java/Spring Boot application. Covers database query optimization, caching strategy, N+1 problems, JVM tuning considerations, connection pool sizing, and Big-O complexity. Produces a prioritized performance report with actionable recommendations.

---

## Inputs

| Source | Description |
|---|---|
| `.copilot-runtime/artifacts/implementation-spec.json` | Query patterns, data access layer |
| `.copilot-runtime/artifacts/requirements.json` | NFRs: throughput, latency targets |
| `.copilot-runtime/analysis/impact-report.json` | Affected endpoints, data volume estimates |
| `.copilot-runtime/artifacts/context.json` | Tech stack, existing caching (Redis, Caffeine) |

---

## Outputs

Writes to: `.copilot-runtime/analysis/performance-report.json`

Structure:

```json
{
  "latency_targets": {},
  "throughput_targets": {},
  "bottlenecks": [
    {
      "category": "database | cache | cpu | memory | io | network",
      "description": "",
      "severity": "critical | high | medium | low",
      "location": "",
      "evidence": "",
      "options": []
    }
  ],
  "n_plus_one_risks": [],
  "caching_opportunities": [],
  "query_analysis": [],
  "jvm_considerations": [],
  "connection_pool_recommendations": {},
  "complexity_analysis": []
}
```

---

## Execution Steps

1. Read `requirements.json` — extract performance NFRs (p99, throughput)
2. Read `implementation-spec.json` — identify data access patterns
3. Read `impact-report.json` — note data volume and traffic estimates
4. Scan for N+1 query risks: `@OneToMany` without `LAZY` + fetch strategy, loops calling repositories
5. Identify missing indexes from query patterns
6. Assess caching opportunities: read-heavy, low-volatility data
7. Review connection pool settings vs. concurrency requirements
8. Analyze algorithmic complexity for collection operations
9. Write `performance-report.json`
10. Return `ok` or `fail` with issues

---

## Performance Rules Enforced

### Database / JPA
- `@OneToMany` must be `LAZY` by default — `EAGER` requires explicit justification
- Collections in queries must use `@EntityGraph` or DTO projections — no in-memory joins
- Bulk operations must use `@Modifying` + JPQL/native query — never load-all-then-save
- Pagination is mandatory for any query returning unbounded collections
- Missing index on foreign key columns → `high` severity

### Caching
- Cache candidates: read-heavy + update-infrequent + tolerable staleness
- Cache keys must be deterministic and specific — no over-broad cache entries
- Cache TTL must be defined — no indefinite caching
- `@CacheEvict` must be coordinated with writes — no stale reads after mutations
- Distributed cache (Redis) required for multi-instance deployments

### JVM / Memory
- Large in-memory collections should use streaming (`Stream`, `Flux`) over full materialization
- Avoid autoboxing in hot paths (use primitive arrays/maps where critical)
- `String.format` in hot paths → use `StringBuilder` or structured logging

### Connection Pool (HikariCP)
- `maximumPoolSize` must be tuned to: `(num_cores * 2) + effective_spindle_count`
- `connectionTimeout` must be set (default 30s is too high for most APIs)
- `leakDetectionThreshold` must be enabled in development

---

## Questions When Input Missing

- "What are the latency targets? (e.g., p99 < 200ms)"
- "What is the expected data volume for the affected queries? (rows, growth rate)"
- "Is Redis or another distributed cache already available?"
- "What is the expected concurrent user load?"

---

## Validation Rules

- Unbounded collection query without pagination → `critical`
- N+1 identified in hot path → `critical`
- Missing cache for read-heavy endpoint exceeding latency target → `high`
- No connection pool configuration → `medium`
- `EAGER` fetch without justification → `high`

---

## Agent Contract — Output Format

```json
{
  "status": "ok | fail | need_more_input",
  "artifacts_ref": [".copilot-runtime/analysis/performance-report.json"],
  "questions": [],
  "validation": {
    "passed": true,
    "issues": []
  },
  "notes": "",
  "next_step_hint": "Resolve critical and high bottlenecks before proceeding to security-agent."
}
```

---

## Definition of Ready

- At least one of: `implementation-spec.json`, `requirements.json`
- Data access patterns known

---

## Definition of Done

- `performance-report.json` written
- All N+1 risks identified
- Caching opportunities assessed
- NFR targets referenced in recommendations
- All critical issues have 3-option remediation
