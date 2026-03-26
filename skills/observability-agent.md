# Observability Agent

## Purpose

Designs and validates observability for a Java/Spring Boot application. Covers structured logging with MDC, distributed tracing, custom metrics, health probes, and alerting strategy. Ensures production incidents are diagnosable in minutes, not hours. All output is persisted as a structured observability plan.

---

## Inputs

| Source | Description |
|---|---|
| `.copilot-runtime/artifacts/implementation-spec.json` | Services, endpoints, async flows |
| `.copilot-runtime/artifacts/requirements.json` | SLOs, SLAs, business KPIs |
| `.copilot-runtime/artifacts/context.json` | Logging framework (Logback/Log4j2), tracing (OpenTelemetry, Zipkin), metrics (Micrometer, Prometheus) |
| `.copilot-runtime/analysis/resilience-report.json` | Failure modes to instrument |

---

## Outputs

Writes to: `.copilot-runtime/artifacts/observability-plan.json`

Structure:

```json
{
  "logging": {
    "framework": "",
    "format": "json | text",
    "mdc_fields": [],
    "sensitive_fields_masked": [],
    "log_levels_by_package": {},
    "issues": []
  },
  "tracing": {
    "tool": "opentelemetry | zipkin | jaeger | none",
    "propagation_configured": false,
    "spans_defined": [],
    "correlation_id_strategy": "",
    "issues": []
  },
  "metrics": {
    "tool": "micrometer | prometheus | none",
    "business_metrics": [],
    "technical_metrics": [],
    "slo_metrics": [],
    "issues": []
  },
  "health_probes": {
    "liveness": "",
    "readiness": "",
    "custom_indicators": [],
    "issues": []
  },
  "alerting": {
    "slo_alerts": [],
    "error_rate_alerts": [],
    "latency_alerts": []
  },
  "gaps": [],
  "recommendations": []
}
```

---

## Execution Steps

1. Read `implementation-spec.json` — identify services and async flows to instrument
2. Read `requirements.json` — extract SLOs (error rate, latency) for alerting
3. Read `context.json` — identify existing observability tooling
4. Read `resilience-report.json` — add instrumentation for each failure mode
5. Design structured logging: JSON format, MDC fields (traceId, userId, correlationId)
6. Design distributed tracing: span per use case, propagation across services
7. Define metrics: business (orders/sec, payment success rate) + technical (JVM, DB pool)
8. Define health probes: liveness vs. readiness distinction
9. Write `observability-plan.json`
10. Return `ok` with artifact reference

---

## Observability Rules Enforced

### Logging
- Log format must be JSON in production (structured, parseable by ELK/Loki)
- MDC must contain: `traceId`, `spanId`, `correlationId`, `userId` (if authenticated)
- Never log PII: mask emails, tokens, card numbers before logging
- Log levels: `ERROR` for unrecoverable, `WARN` for recoverable/expected, `INFO` for state transitions, `DEBUG` for diagnostic (disabled in prod)
- No string concatenation in log statements — use parameterized logging

### Distributed Tracing
- OpenTelemetry (OTEL) preferred — vendor-neutral
- Every use case entry point must create or join a trace span
- Trace context must be propagated through Kafka messages (header injection)
- `W3C Trace Context` propagation standard required for HTTP

### Metrics (Micrometer)
- Business metrics: domain events as counters (e.g., `orders.placed`, `payments.failed`)
- Technical metrics: JVM heap, GC pauses, DB connection pool utilization
- SLO metrics: request latency histogram with percentiles (p50, p95, p99)
- All metrics must have meaningful tags — no untagged counters

### Health Probes (Kubernetes)
- **Liveness:** Can the process recover? (JVM alive, no deadlock)
- **Readiness:** Is the service ready to serve traffic? (DB connected, cache warm)
- Never include slow dependencies in liveness probe
- Custom `HealthIndicator` for critical downstream dependencies

---

## Questions When Input Missing

- "What is the SLO for error rate? (e.g., < 0.1% errors per hour)"
- "What is the SLO for latency? (e.g., p99 < 500ms)"
- "Is OpenTelemetry already configured? Or is a tracing agent (e.g., Datadog APM) in use?"
- "Is this deployed on Kubernetes? (affects health probe design)"

---

## Validation Rules

- No JSON log format → `high`
- No traceId in MDC → `high`
- PII in log statements → `critical`
- No readiness probe for DB dependency → `high`
- No SLO-based alerting → `medium`
- No metrics for critical business operations → `medium`

---

## Agent Contract — Output Format

```json
{
  "status": "ok | fail | need_more_input",
  "artifacts_ref": [".copilot-runtime/artifacts/observability-plan.json"],
  "questions": [],
  "validation": {
    "passed": true,
    "issues": []
  },
  "notes": "",
  "next_step_hint": "Proceed to data-integrity-agent or code-review-agent."
}
```

---

## Definition of Ready

- `implementation-spec.json` exists or service description provided
- Logging and metrics tooling known

---

## Definition of Done

- `observability-plan.json` written with all sections populated
- MDC fields defined
- SLO metrics defined if SLOs exist in requirements
- Health probes designed
- All gaps documented with recommendations
