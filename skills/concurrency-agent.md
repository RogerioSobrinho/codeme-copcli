# Concurrency Agent

## Purpose

Audits and designs concurrency safety for a Java/Spring Boot application. Identifies race conditions, thread safety violations, deadlock risks, and incorrect locking strategies. Recommends appropriate concurrency patterns (optimistic locking, pessimistic locking, async models) based on the domain context.

---

## Inputs

| Source | Description |
|---|---|
| `.copilot-runtime/artifacts/implementation-spec.json` | Classes, transaction boundaries |
| `.copilot-runtime/artifacts/domain-model.json` | Aggregates, mutable state |
| `.copilot-runtime/artifacts/context.json` | Threading model, async frameworks (WebFlux, Virtual Threads) |

---

## Outputs

Writes to: `.copilot-runtime/analysis/concurrency-report.json`

Structure:

```json
{
  "threading_model": "servlet | reactive | virtual_threads",
  "race_conditions": [],
  "thread_safety_violations": [],
  "locking_strategy": {
    "optimistic": [],
    "pessimistic": [],
    "issues": []
  },
  "deadlock_risks": [],
  "shared_mutable_state": [],
  "async_patterns": {
    "correct_usage": [],
    "violations": []
  },
  "recommendations": [
    {
      "severity": "critical | high | medium | low",
      "issue": "",
      "recommendation": "",
      "option_1": {},
      "option_2": {},
      "option_3_recommended": {}
    }
  ]
}
```

---

## Execution Steps

1. Read `implementation-spec.json` — identify mutable state and shared resources
2. Read `domain-model.json` — identify Aggregates with concurrent write risk
3. Read `context.json` — determine threading model
4. Scan for shared mutable state: `static` fields, singletons with mutable state, caches
5. Identify operations requiring atomic guarantees
6. Recommend locking strategy per Aggregate:
   - Optimistic (`@Version`) for low contention
   - Pessimistic for high contention / financial operations
7. Identify async misuses: `CompletableFuture` + `@Transactional`, lost context
8. Write `concurrency-report.json`
9. Return `ok` or `fail` with issues

---

## Concurrency Rules Enforced

### Thread Safety
- Spring `@Service`, `@Repository`, `@Component` beans are singletons — must be stateless
- Instance fields in Spring beans must be `final` or thread-safe types
- No `HashMap` in shared context — use `ConcurrentHashMap` or synchronize
- No `SimpleDateFormat` as instance field (not thread-safe)

### Optimistic Locking
- Use `@Version` on Aggregate roots exposed to concurrent writes
- Handle `OptimisticLockingFailureException` at application layer — retry or surface to user
- Never use optimistic locking for financial/high-contention operations

### Pessimistic Locking
- Use `@Lock(LockModeType.PESSIMISTIC_WRITE)` for financial operations
- Keep pessimistic lock scope minimal — lock only required rows
- Always set lock timeout to prevent indefinite blocking

### Async Patterns
- `@Async` methods must not be in the same class as the caller (proxy bypass)
- `CompletableFuture` chains must handle exceptions — no unhandled `CompletableFuture`
- `@Transactional` + `@Async` = transaction loss — flag as `critical`
- Virtual Threads (Java 21+): avoid `synchronized` — use `ReentrantLock`

---

## Questions When Input Missing

- "What Java version is this project using? (affects Virtual Thread consideration)"
- "Are there high-concurrency write scenarios? (e.g., inventory deduction, balance updates)"
- "Is this a reactive (WebFlux) or traditional (Servlet) application?"
- "Are there any `@Scheduled` jobs that share state with request threads?"

---

## Validation Rules

- Mutable singleton state → `critical`
- `@Transactional` + `@Async` → `critical`
- Financial Aggregate without locking strategy → `critical`
- `synchronized` with Virtual Threads → `high`
- Unhandled `OptimisticLockingFailureException` → `high`

---

## Agent Contract — Output Format

```json
{
  "status": "ok | fail | need_more_input",
  "artifacts_ref": [".copilot-runtime/analysis/concurrency-report.json"],
  "questions": [],
  "validation": {
    "passed": true,
    "issues": []
  },
  "notes": "",
  "next_step_hint": "Resolve critical concurrency issues before proceeding to performance-agent."
}
```

---

## Definition of Ready

- `implementation-spec.json` or `domain-model.json` exists
- Threading model known (or can be inferred from Spring Boot version)

---

## Definition of Done

- `concurrency-report.json` written
- All mutable shared state identified
- Locking strategy defined per Aggregate
- Async pattern violations listed
- All critical issues have 3-option remediation recommendations
