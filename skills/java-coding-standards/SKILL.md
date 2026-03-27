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
