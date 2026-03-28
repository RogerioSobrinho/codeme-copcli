---
name: java-coding-standards
description: >
  Load when reviewing or writing Java 17+ code for idiom compliance: records, sealed classes,
  pattern matching instanceof, switch expressions, text blocks, var keyword, Stream API chains,
  Optional usage, immutability with final fields or Unmodifiable collections, or when
  naming conventions, method length, or class responsibility are under discussion.
---

# Java Coding Standards (Java 17+)

## Immutability First

Default to `final` for fields, parameters, and local variables. Mutability must be justified.

```java
// Fields — final unless mutation is necessary
public class OrderService {
    private final OrderRepository orderRepository;
    private final PaymentGateway paymentGateway;

    public OrderService(OrderRepository orderRepository, PaymentGateway paymentGateway) {
        this.orderRepository = orderRepository;
        this.paymentGateway = paymentGateway;
    }
}

// Collections — Unmodifiable by default
private final List<OrderItem> items = new ArrayList<>();

public List<OrderItem> getItems() {
    return Collections.unmodifiableList(items);  // or List.copyOf(items)
}
```

---

## Records — Value Objects and DTOs

Use `record` for any class that is purely a data carrier with no identity semantics.

```java
// DTO (replaces class + constructor + getters + equals + hashCode + toString)
public record CreateOrderRequest(
    @NotBlank String customerId,
    @NotBlank String currency,
    @NotEmpty List<@Valid OrderItemRequest> items
) {}

// Value object in domain
public record Money(BigDecimal amount, Currency currency) {

    // Compact constructor for validation
    public Money {
        Objects.requireNonNull(amount, "amount must not be null");
        Objects.requireNonNull(currency, "currency must not be null");
        if (amount.compareTo(BigDecimal.ZERO) < 0) {
            throw new IllegalArgumentException("amount must be non-negative");
        }
    }

    public Money add(Money other) {
        if (!this.currency.equals(other.currency)) {
            throw new IllegalArgumentException("Cannot add different currencies");
        }
        return new Money(this.amount.add(other.amount), this.currency);
    }
}
```

Do NOT use records for:
- JPA `@Entity` classes (no default constructor, proxy issues)
- Classes that accumulate state over time
- Classes extended by subclasses

---

## Sealed Classes — Closed Hierarchies

Use `sealed` when a type has a fixed set of subtypes known at compile time.

```java
// Domain result type — exhaustive switch is enforced by compiler
public sealed interface PaymentResult
    permits PaymentResult.Success, PaymentResult.Declined, PaymentResult.Error {

    record Success(String transactionId, Money amount) implements PaymentResult {}
    record Declined(String reason) implements PaymentResult {}
    record Error(String message, Throwable cause) implements PaymentResult {}
}

// Exhaustive switch — compiler warns if a case is missing
PaymentResult result = paymentGateway.charge(order);
String message = switch (result) {
    case PaymentResult.Success s  -> "Charged " + s.amount();
    case PaymentResult.Declined d -> "Declined: " + d.reason();
    case PaymentResult.Error e    -> "Error: " + e.message();
};
```

---

## Pattern Matching instanceof

Eliminate the explicit cast:

```java
// BAD — explicit cast after instanceof
if (event instanceof OrderPlacedEvent) {
    OrderPlacedEvent placed = (OrderPlacedEvent) event;
    notifyCustomer(placed.customerId());
}

// GOOD — pattern matching (Java 16+)
if (event instanceof OrderPlacedEvent placed) {
    notifyCustomer(placed.customerId());
}

// With guards (Java 21+)
if (event instanceof OrderPlacedEvent placed && placed.amount().isPositive()) {
    notifyCustomer(placed.customerId());
}
```

---

## Switch Expressions

Use switch **expressions** (not statements) when every branch produces a value.

```java
// OLD — switch statement with side effects
String label;
switch (status) {
    case PENDING: label = "Waiting"; break;
    case ACTIVE:  label = "Running"; break;
    default:      label = "Unknown";
}

// GOOD — switch expression
String label = switch (status) {
    case PENDING -> "Waiting";
    case ACTIVE  -> "Running";
    default      -> "Unknown";
};

// With complex block
BigDecimal discount = switch (tier) {
    case GOLD     -> { yield price.multiply(new BigDecimal("0.20")); }
    case SILVER   -> price.multiply(new BigDecimal("0.10"));
    case STANDARD -> BigDecimal.ZERO;
};
```

---

## Text Blocks

Use text blocks for multi-line strings (SQL, JSON, HTML, GraphQL):

```java
// BAD
String sql = "SELECT o.id, o.status, c.name " +
             "FROM orders o " +
             "JOIN customers c ON c.id = o.customer_id " +
             "WHERE o.status = :status";

// GOOD — text block (Java 15+)
String sql = """
        SELECT o.id, o.status, c.name
        FROM orders o
        JOIN customers c ON c.id = o.customer_id
        WHERE o.status = :status
        """;
```

---

## `var` Keyword

Use `var` when the type is obvious from the right-hand side:

```java
// GOOD — type obvious from constructor
var executor = new ThreadPoolTaskExecutor();
var items = new ArrayList<OrderItem>();
var result = orderRepository.findById(id);  // type is Optional<Order>

// BAD — type not obvious from RHS
var x = getProcessor();       // what type does getProcessor() return?
var config = buildConfig();   // unclear
```

Never use `var` for:
- `null` initializers: `var thing = null;` — won't compile
- Primitive types where boxing confusion would arise
- Return types of public methods

---

## Optional Usage

`Optional` is for return types only. Never use it as a field or parameter type.

```java
// GOOD — return type signals possible absence
public Optional<Order> findByExternalId(UUID externalId) {
    return orderRepository.findByExternalId(externalId);
}

// Consumer patterns
service.findByExternalId(id)
    .ifPresent(order -> log.info("Found order {}", order.id()));

Order order = service.findByExternalId(id)
    .orElseThrow(() -> new OrderNotFoundException(id));

Order order = service.findByExternalId(id)
    .orElseGet(() -> Order.createDraft(id));

// BAD — Optional as field
private Optional<Customer> cachedCustomer;   // use null + null check instead

// BAD — Optional as parameter
public void process(Optional<Filter> filter) { ... }  // use overload or @Nullable
```

---

## Stream API Best Practices

```java
// Terminal operation, not intermediate, for side effects
orders.stream()
    .filter(o -> o.status() == PENDING)
    .map(Order::customerId)
    .distinct()
    .forEach(this::notifyCustomer);   // forEach is terminal — OK for side effects

// Collect idioms
List<OrderId> ids = orders.stream()
    .map(Order::id)
    .toList();                        // Java 16+, unmodifiable — prefer over Collectors.toList()

Map<OrderStatus, List<Order>> byStatus = orders.stream()
    .collect(Collectors.groupingBy(Order::status));

// Short-circuit for existence checks
boolean hasPending = orders.stream()
    .anyMatch(o -> o.status() == PENDING);  // do NOT use .filter(...).count() > 0
```

**Pitfalls:**
- Never mutate shared state from `forEach` or `map` — use `reduce` or `collect`
- Avoid `Stream.of(null)` — produces a stream with one null element, not empty
- Use `Stream.ofNullable(value)` for null-safe single-element streams (Java 9+)

---

## Naming Conventions

| Element | Convention | Example |
|---|---|---|
| Class | UpperCamelCase, noun | `OrderService`, `PaymentGateway` |
| Interface | UpperCamelCase, noun or adjective | `Repository`, `Auditable` |
| Method | lowerCamelCase, verb | `calculateTotal()`, `findByStatus()` |
| Constant | UPPER_SNAKE_CASE | `MAX_RETRY_COUNT` |
| Package | lowercase, singular | `com.example.order.domain` |
| Generic type | Single uppercase letter or descriptive | `T`, `K`, `V`, `EntityType` |

**Domain terms over technical terms:**
```java
// BAD — technical
List<Object> dataList = getData();
void processItem(Object item) { ... }

// GOOD — domain
List<Order> pendingOrders = findPendingOrders();
void confirmOrder(Order order) { ... }
```

---

## Method and Class Size

- Methods: ≤ 20 lines for 90% of cases. If longer, extract to named private methods.
- Classes: single responsibility — if you can't describe it in one sentence without "and", split it.
- Constructor: if > 3 parameters, use Builder pattern or extract a config record.

```java
// BAD — constructor parameter explosion
new PaymentService(gateway, repository, notifier, validator, logger, retryPolicy, clock);

// GOOD — config record or Builder
public record PaymentServiceConfig(
    int maxRetries,
    Duration timeout,
    String gatewayEndpoint
) {}

new PaymentService(gateway, repository, notifier, new PaymentServiceConfig(3, Duration.ofSeconds(5), url));
```

---

## Anti-Patterns to Eliminate

| Anti-pattern | Replace with |
|---|---|
| `instanceof` check + explicit cast | Pattern matching `instanceof` |
| `if-else` chain on type/status | `switch` expression |
| Mutable DTO with setters | `record` |
| `null` return from service | `Optional<T>` |
| Static utility class | Instance class with DI, or private methods |
| `public static` mutable field | Inject via constructor, use constants |
| Raw `new` in business logic | Factory or domain method |
| Checked exception wrapping without re-throw | Preserve root cause with `throw new X("msg", cause)` |

---

## Exceptions

Use unchecked exceptions for domain errors. Wrap technical exceptions with domain context and always preserve the root cause.

```java
// Domain-specific exception — named after what went wrong in the domain
public class OrderNotFoundException extends RuntimeException {
    public OrderNotFoundException(UUID orderId) {
        super("Order not found: " + orderId);
    }
}

// Wrapping a technical exception — preserve root cause
try {
    return objectMapper.readValue(json, Order.class);
} catch (JsonProcessingException ex) {
    throw new OrderDeserializationException("Failed to parse order payload", ex); // cause preserved
}
```

**Rules:**
- Never use `catch (Exception ex) {}` (silent swallow)
- Broad `catch (Exception ex)` only at boundary handlers (`@ControllerAdvice`)
- Use `throw new X("msg", cause)` — never discard the original stack trace
- Prefer `IllegalArgumentException` / `IllegalStateException` for programming errors
- Prefer domain exceptions (`OrderNotFoundException`) for business errors

---

## Generics and Type Safety

Avoid raw types. Declare generic parameters to prevent unchecked casts and runtime `ClassCastException`.

```java
// BAD — raw type; compiler cannot check
List items = new ArrayList();
items.add("hello");
items.add(42);  // no error; ClassCastException later

// GOOD — parameterized
List<String> names = new ArrayList<>();

// Bounded generics for reusable utilities
public <T extends Comparable<T>> T max(List<T> items) {
    return items.stream().max(Comparator.naturalOrder()).orElseThrow();
}

// Wildcard for read-only consumption
public void printAll(List<? extends Printable> items) {
    items.forEach(Printable::print);
}
```

**Pitfalls:** Never cast `(List<SomeType>)` a raw list — use proper type tokens. Avoid `@SuppressWarnings("unchecked")` without an inline justification comment.

---

## Project Structure

Standard Maven/Gradle layout for a Spring Boot service:

```
src/main/java/com/example/app/
  config/          // @Configuration, @Bean definitions
  controller/      // @RestController — HTTP boundary only
  service/         // @Service — use-case orchestration
  repository/      // Spring Data interfaces
  domain/          // Entities, value objects, domain exceptions
  dto/             // Records for request/response (no JPA dependency)
  util/            // Stateless helpers (use sparingly)
src/main/resources/
  application.yml
src/test/java/...  // Mirrors main; unit tests alongside integration tests
```

**Member ordering within a class:**
1. `static final` constants
2. Non-static final fields (injected dependencies)
3. Constructor(s)
4. Public methods
5. Package-private / protected methods
6. Private methods

---

## Null Handling

```java
// ✅ Annotate parameters that may be null
public void process(@Nullable Filter filter) { ... }

// ✅ Assert non-null at constructor boundary
public OrderService(@NonNull OrderRepository repository) {
    this.repository = Objects.requireNonNull(repository, "repository must not be null");
}

// ✅ Return Optional — never null — from find* methods
public Optional<Order> findById(UUID id) { ... }

// BAD — returning null forces null-checks on callers
public Order findById(UUID id) {
    return null; // caller has no contract to defend against
}
```

**Rule:** Prefer `@NonNull` / `@Nullable` (JSR-305 or JSpecify) on all public API boundaries. Use `Objects.requireNonNull()` in constructors for fast-fail detection. Avoid `null` returns from service methods — use `Optional<T>`.

---

## Testing Expectations

```java
// Test method naming: methodName_givenContext_expectedBehavior
@Test
void createOrder_givenValidRequest_returnsCreatedOrder() { ... }

@Test
void createOrder_givenExpiredItem_throwsItemExpiredException() { ... }
```

- **JUnit 5 + AssertJ** for fluent, readable assertions (`assertThat(order).isNotNull()`)
- **Mockito** for mocking — prefer `@ExtendWith(MockitoExtension.class)` over `@SpringBootTest` in unit tests
- No `Thread.sleep()` — use Awaitility for async assertions
- Test one behaviour per test method; use `@Nested` to group related cases
- Favour deterministic data over random values in tests
