# Testing Requirements

## Minimum Coverage: 80%

Required test types:
1. **Unit Tests** — Individual functions, services, components in isolation
2. **Integration Tests** — API endpoints, database operations, cross-layer behavior
3. **E2E Tests** — Critical user flows (use framework appropriate for the stack)

100% coverage required for: financial calculations, auth logic, security-critical code, core business rules.

## TDD Workflow (Mandatory for New Features)

```
RED → GREEN → REFACTOR → REPEAT
```

1. Write a failing test (RED) — run it, verify it fails for the right reason
2. Write minimal code to make it pass (GREEN)
3. Refactor while keeping tests green (REFACTOR)
4. Verify coverage — add more tests if below 80%

**Never write implementation before tests.** Never skip the RED phase.

## AAA Pattern

Organize all tests with Arrange, Act, Assert:

```
// Arrange — set up state and dependencies
// Act — invoke the subject under test
// Assert — verify the outcome
```

## Edge Case Coverage (Mandatory)

Every test suite must cover:
- Null / undefined / empty inputs
- Boundary values (min, max, zero)
- Timeout and network failure scenarios
- Unauthorized access attempts

## Testable Design

- If it is hard to test, refactor it — tightly coupled code is a design smell.
- Prefer constructor injection over static calls — makes mocking trivial.
- Avoid `Thread.sleep()` / `delay()` in tests — use retry libraries (Awaitility, fake_async, etc.).

## Troubleshooting Test Failures

1. Use the **fix** agent for systematic diagnosis
2. Check test isolation — ensure no shared mutable state between tests
3. Verify mocks return expected values
4. Fix implementation, not tests (unless the test is wrong)
