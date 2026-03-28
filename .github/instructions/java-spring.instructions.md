# Java / Spring Boot Patterns

## Dependency Injection

- **Constructor injection only.** Never `@Autowired` on fields. Never setter injection.
- If a constructor has > 5 parameters, the class has too many responsibilities — split it.

```java
// GOOD
public class OrderService {
    private final OrderRepository orderRepository;
    private final PaymentGateway paymentGateway;

    public OrderService(OrderRepository orderRepository, PaymentGateway paymentGateway) {
        this.orderRepository = orderRepository;
        this.paymentGateway = paymentGateway;
    }
}
```

## Transactional Boundaries

- `@Transactional` belongs on the **service layer** only — never on controllers or repositories.
- Use `readOnly = true` for query-only methods — reduces lock overhead.
- Never call a `@Transactional` method from within the same class (self-invocation bypasses proxy).

## Controller Contracts

- Never expose JPA entities from controllers — always map to DTOs.
- Always annotate `@RequestBody` parameters with `@Valid`.
- Never put business logic in controllers — they only translate HTTP to service calls.

## JPA / Database

- Always specify `fetch = FetchType.LAZY` on `@ManyToOne` and `@OneToMany` — EAGER is a performance trap.
- Always use projections or DTOs for read-only queries — never load full entities for display.
- Never use `CascadeType.ALL` without explicit justification — it silently deletes children.
- Entities are not thread-safe — never share entity instances across threads.

## API Response Envelope

Use a consistent wrapper for all REST endpoints:

```java
public record ApiResponse<T>(boolean success, T data, String error) {
    public static <T> ApiResponse<T> ok(T data) {
        return new ApiResponse<>(true, data, null);
    }
    public static <T> ApiResponse<T> error(String message) {
        return new ApiResponse<>(false, null, message);
    }
}
```

## Exception Handling

- Never swallow checked exceptions with an empty catch block.
- Always preserve the root cause: `new ServiceException("message", cause)`.
- Use `@ControllerAdvice` for global exception handling — never try-catch in every controller.

## Naming & Packages

- Packages: `com.{company}.{domain}.{layer}` — e.g., `com.acme.orders.service`
- Classes: PascalCase noun phrases. No `Manager`, `Helper`, `Utils`.
- Methods: camelCase verbs. Booleans: `is*`, `has*`, `can*`.
