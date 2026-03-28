# Java Coding Style

## Naming Conventions

- `PascalCase` for classes, interfaces, records, enums
- `camelCase` for methods, fields, parameters, local variables
- `SCREAMING_SNAKE_CASE` for `static final` constants
- Packages: all lowercase, reverse domain (`com.example.app.service`)
- No `Manager`, `Helper`, `Utils` class suffixes — use domain-specific names
- Boolean methods: `is*`, `has*`, `can*`

## Modern Java Features (Java 17+)

Use modern language features where they improve clarity:

```java
// Records for immutable value types (Java 16+)
public record OrderSummary(Long id, String customer, BigDecimal total) {}

// Sealed types for closed hierarchies (Java 17+)
public sealed interface PaymentResult permits PaymentSuccess, PaymentFailure {}

// Pattern matching instanceof — no explicit cast (Java 16+)
if (shape instanceof Circle c) { return Math.PI * c.radius() * c.radius(); }

// Switch expression (Java 14+)
String label = switch (status) {
    case ACTIVE   -> "Active";
    case SUSPENDED -> "Suspended";
    case CLOSED   -> "Closed";
};

// Text blocks for multi-line strings (Java 15+)
String sql = """
    SELECT id, name FROM orders
    WHERE status = :status
    ORDER BY created_at DESC
    """;
```

## Immutability

- Mark fields `final` by default — mutable state only when required
- Return defensive copies from public APIs: `List.copyOf()`, `Map.copyOf()`, `Set.copyOf()`
- Prefer `record` for DTOs and value objects
- Return new instances rather than mutating existing ones

## Optional Usage

```java
// GOOD — map, orElseThrow, never naked get()
return repository.findById(id)
    .map(ResponseDto::from)
    .orElseThrow(() -> new OrderNotFoundException(id));

// BAD — Optional as field or parameter
public void process(Optional<String> name) {}
```

## Code Quality Limits

- Maximum method length: **20 lines** — extract if longer
- Maximum class length: **300 lines** — split responsibilities if longer
- Maximum file length: **800 lines** absolute ceiling; target 200–400
- No magic numbers — use named constants or `enum` values
- No deep nesting (> 4 levels) — extract methods or invert conditions

## Streams

- Keep pipelines short (3–4 operations max)
- Prefer method references: `.map(Order::getTotal)`
- Avoid side effects in stream operations
- For complex logic, prefer a loop over a convoluted pipeline
