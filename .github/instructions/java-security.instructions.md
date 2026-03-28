# Java Security

## Secrets

```java
// BAD — hardcoded secret
private static final String API_KEY = "sk-abc123...";

// GOOD — environment variable, fail fast if missing
String apiKey = System.getenv("PAYMENT_API_KEY");
Objects.requireNonNull(apiKey, "PAYMENT_API_KEY must be set");
```

## SQL Injection Prevention

Always use parameterized queries — never concatenate user input into SQL:

```java
// BAD
String sql = "SELECT * FROM orders WHERE name = '" + name + "'";

// GOOD — PreparedStatement
PreparedStatement ps = conn.prepareStatement("SELECT * FROM orders WHERE name = ?");
ps.setString(1, name);

// GOOD — JDBC template / JPA named parameter
jdbcTemplate.query("SELECT * FROM orders WHERE name = ?", mapper, name);
```

## Input Validation

- Validate all user input at controller boundaries with Bean Validation (`@Valid`, `@NotNull`, `@NotBlank`, `@Size`)
- Sanitize file paths and user-provided strings before use
- Reject invalid input with clear error messages — fail fast

## Authentication & Authorization

- Never implement custom auth crypto — use Spring Security or established libraries
- Store passwords with bcrypt or Argon2 — never MD5/SHA1
- Use `@PreAuthorize` for method-level security over inline `SecurityContextHolder` checks
- Enforce authorization checks at service boundaries, not just route level

## PII in Logs

- Never log passwords, tokens, credit card numbers, or PII
- Annotate sensitive DTO fields with `@JsonIgnore`
- Log sanitized representations (e.g., masked email: `a***@example.com`)

## Error Messages

```java
// Log detail, return generic client message
try {
    return orderService.findById(id);
} catch (OrderNotFoundException ex) {
    log.warn("Order not found: id={}", id);
    return ApiResponse.error("Resource not found");  // no internals leaked
} catch (Exception ex) {
    log.error("Unexpected error: id={}", id, ex);
    return ApiResponse.error("Internal server error");
}
```

## Dependency Security

- Run `mvn dependency:check` or `./gradlew dependencyCheckAnalyze` (OWASP) regularly
- Keep dependencies updated — set up Dependabot or Renovate
