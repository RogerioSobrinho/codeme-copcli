# Engineering Principles

## Defensive Programming

- **Input Validation:** Trust no one. Validate all inputs at system boundaries (API, UI, Database).
- **Fail-Fast:** Detect errors early and stop execution to prevent corrupted states.
- **Null Safety:** Strictly avoid null pointer risks. Use Optionals, Null Objects, or Sound Null Safety.

## State & Idempotency

- **Immutability:** Default to `final`, `readonly`, or `const`. Return defensive copies from public APIs. Create new objects instead of mutating existing ones.
- **Idempotency:** Ensure operations (especially API/DB writes) are safe for retries.
- **Pure Functions:** Minimize side effects; favor deterministic logic.

## Error Handling & Resiliency

- **No Silent Failures:** Catch, log, and handle. Never swallow exceptions.
- **Resiliency Patterns:** Suggest `Retry`, `Timeout`, or `Circuit Breaker` for external calls.
- **Stack Traces:** Always preserve the root cause when wrapping or re-throwing.

## API & Contract Design

- **Backward Compatibility:** Never break an existing contract unless explicitly requested.
- **Consistency:** Follow REST/GraphQL/gRPC standards strictly.
- **Status Codes:** Use correct, semantic HTTP/Error codes.

## Patterns

- **Repository Pattern:** Encapsulate data access behind a consistent interface.
- **Service Layer:** Business logic in service classes; keep controllers and repositories thin.
- **DTO Mapping:** Map entities to DTOs at service/controller boundaries. Never expose persistence objects directly.

## Deployment & CI/CD Readiness

- **Environment Aware:** Use config/env variables; never hardcode environment-specific values.
- **Portability:** Code must be portable across Dev, Staging, and Production environments.

## Technical Debt

- **Explicit TODOs:** `// TODO: [Context] - What/Why it needs adjustment.`
- **Marked Mocks:** Clearly separate temporary logic from production code.

## Dependency Management

- **Minimalist:** Do not suggest new packages unless the benefit outweighs the maintenance cost.
- **Stability:** Prefer established, well-maintained libraries over experimental ones.
