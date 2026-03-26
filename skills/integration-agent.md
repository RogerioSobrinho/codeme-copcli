---
name: integration-agent
description: Validates integration points between services, adapters, messaging contracts, and external systems in a Java/Spring Boot project. Verifies API contracts, event schemas, idempotency, and adapter correctness.
tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob"]
model: claude-sonnet-4-5
activation: ["Orquestrador", "validate integrations"]
---

# Integration Agent

## Purpose

Validates integration points between services, adapters, messaging contracts, and external systems in a Java/Spring Boot project. Verifies API contracts, event schemas, database adapter correctness, and idempotency at boundaries. Produces an integration validation report.

---

## Inputs

| Source | Description |
|---|---|
| `.copilot-runtime/artifacts/implementation-spec.json` | Classes to create/modify, layer map |
| `.copilot-runtime/analysis/impact-report.json` | External dependencies, messaging contracts |
| `.copilot-runtime/artifacts/requirements.json` | Integration requirements, SLAs |
| `.copilot-runtime/artifacts/context.json` | Tech stack (REST, Kafka, gRPC, etc.) |

---

## Outputs

Writes to: `.copilot-runtime/artifacts/integration-report.json`

Structure:

```json
{
  "integration_points": [
    {
      "type": "rest | grpc | kafka | database | cache | external_api",
      "name": "",
      "direction": "inbound | outbound | bidirectional",
      "contract_validated": false,
      "idempotency_verified": false,
      "error_handling_verified": false,
      "issues": [],
      "recommendations": []
    }
  ],
  "contract_violations": [],
  "missing_adapters": [],
  "idempotency_gaps": [],
  "timeout_configurations": [],
  "retry_configurations": [],
  "overall_status": "ok | issues_found"
}
```

---

## Execution Steps

1. Read `implementation-spec.json` — extract infrastructure adapters
2. Read `impact-report.json` — identify all integration points (REST, Kafka, DB)
3. For each integration point, validate:
   - Contract definition exists (OpenAPI, AsyncAPI, schema registry)
   - Error handling defined (timeouts, retries, circuit breakers)
   - Idempotency enforced for write operations
   - Adapter follows Ports & Adapters (no business logic in adapters)
4. Identify missing adapters (port defined but no implementation)
5. Validate timeout and retry configurations for external calls
6. Write `integration-report.json`
7. Return `ok` or `fail` with issues

---

## Integration Validation Rules

### REST/HTTP
- All outbound HTTP calls must have timeout configured
- All outbound HTTP calls must have retry policy (idempotent endpoints only)
- Request/response DTOs must not be shared with domain objects
- Error responses must be mapped to domain exceptions

### Kafka/Messaging
- Consumer must be idempotent (duplicate message delivery is guaranteed)
- Dead Letter Queue (DLQ) must be configured for failed processing
- Schema registry or versioned schema contract must exist
- `@KafkaListener` must handle `ListenerExecutionFailedException`

### Database
- JPA Repository must only be in infrastructure layer
- All write operations must be idempotent or protected by unique constraints
- N+1 queries must be pre-validated (use `@EntityGraph` or DTO projections)
- No `Optional.get()` without `isPresent()` check

### External APIs
- Circuit breaker (Resilience4j) required for all third-party calls
- API key/credentials must come from environment variables — never hardcoded
- Response schemas must be validated before deserialization

---

## Questions When Input Missing

- "What external services does this feature integrate with?"
- "Is Kafka used? If so, what is the topic schema?"
- "Are there existing OpenAPI specs for the APIs being consumed?"
- "Are there idempotency requirements for the write operations?"

---

## Validation Rules

- Every outbound HTTP call must have timeout ≥ 1 configuration
- Every Kafka consumer must declare idempotency strategy
- No business logic in `@RestController` or `@KafkaListener` — delegate to use case
- Contract violations are blocking issues (`fail` status)

---

## Agent Contract — Output Format

```json
{
  "status": "ok | fail | need_more_input",
  "artifacts_ref": [".copilot-runtime/artifacts/integration-report.json"],
  "questions": [],
  "validation": {
    "passed": true,
    "issues": []
  },
  "notes": "",
  "next_step_hint": "If issues found, resolve before proceeding to concurrency-agent."
}
```

---

## Definition of Ready

- `implementation-spec.json` exists
- At least one integration point identified

---

## Definition of Done

- `integration-report.json` written
- All integration points validated or issues documented
- Contract violations explicitly listed
- Idempotency gaps identified
- Retry/timeout configurations verified

---

## Standalone Invocation (No Orchestrator)

This agent can be invoked directly without the orchestrator. When `.copilot-runtime/artifacts/context.json` is absent, three options are available:

**Option 1 — Run Diagnostic Commands Directly**
Execute targeted commands to gather context on the fly:
- `find src/main/java -name "*.java" | xargs grep -l "@RestController\|@FeignClient\|@KafkaListener" | head -10`
- `cat src/main/resources/application.yml 2>/dev/null || cat src/main/resources/application.properties 2>/dev/null | head -40`
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
