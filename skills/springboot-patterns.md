---
name: springboot-patterns
description: Reference knowledge base for Spring Boot best practices and patterns. Not a workflow agent — referenced by code-review-agent, implementation-agent, security-agent, performance-agent, and java-build-resolver-agent.
tools: ["Read"]
model: claude-haiku-4-5
activation: ["spring boot patterns", "spring boot reference", "spring patterns guide"]
---

# Spring Boot Patterns — Reference Knowledge Base

> **This is a knowledge base, not a workflow agent.** It produces no artifacts and runs no commands. It is referenced by: `code-review-agent`, `implementation-agent`, `security-agent`, `performance-agent`, `java-build-resolver-agent`.

---

## 1. Layered Architecture

### When to Use
Standard Spring Boot projects without strict hexagonal requirements. Three or four layers with clear dependency direction: Controller → Service → Repository → Domain.

### Pattern

```
presentation/
  UserController.java         // @RestController — HTTP boundary only
application/
  UserService.java            // @Service — orchestrates use cases
  dto/
    CreateUserRequest.java    // Input DTO (Bean Validation)
    UserResponse.java         // Output DTO (no JPA entity exposure)
domain/
  User.java                   // Business entity with invariants
  UserRepository.java         // Interface (no JPA dependency)
infrastructure/
  persistence/
    JpaUserRepository.java    // implements UserRepository
    UserJpaEntity.java        // @Entity — JPA mapping object
  web/
    UserMapper.java           // Domain ↔ DTO mapping
```

### Pitfalls
- **Leaking JPA entities to controllers** — always map to DTOs at the presentation boundary.
- **Business logic in controllers** — controllers must delegate immediately to a service.
- **Services calling other services directly** — prefer events or a use-case coordinator.
- **Bidirectional dependencies** — domain must never import from infrastructure.

### Referenced By
`implementation-agent`, `code-review-agent`

---

## 2. JPA Patterns

### When to Use
Any Spring Data JPA repository interaction. Apply all rules by default.

### N+1 Prevention

```java
// BAD — triggers N+1
List<Order> orders = orderRepository.findAll();
orders.forEach(o -> o.getItems().size()); // each call hits DB

// GOOD — fetch join
@Query("SELECT o FROM Order o LEFT JOIN FETCH o.items WHERE o.status = :status")
List<Order> findByStatusWithItems(@Param("status") OrderStatus status);

// GOOD — @EntityGraph (avoids JPQL)
@EntityGraph(attributePaths = {"items", "items.product"})
List<Order> findByStatus(OrderStatus status);
```

### Projections

```java
// Interface projection — only fetch required columns
public interface OrderSummary {
    Long getId();
    String getStatus();
    BigDecimal getTotalAmount();
}

List<OrderSummary> findByCustomerId(Long customerId);
```

### Pagination (Mandatory for unbounded queries)

```java
Page<Order> findByStatus(OrderStatus status, Pageable pageable);
// Call with: PageRequest.of(0, 20, Sort.by("createdAt").descending())
```

### Pitfalls
- `FetchType.EAGER` on `@OneToMany` — always use `LAZY`.
- Calling `findAll()` on large tables — always paginate.
- `Optional.get()` without `isPresent()` — use `orElseThrow()`.
- Saving entities in loops — use `saveAll()` with batching enabled.

### Referenced By
`performance-agent`, `implementation-agent`, `data-integrity-agent`

---

## 3. Spring Security Configuration Patterns

### When to Use
Any HTTP endpoint requiring authentication or authorization.

### JWT Security Config (Spring Boot 3 / Spring Security 6)

```java
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        return http
            .csrf(AbstractHttpConfigurer::disable)          // stateless JWT — CSRF not needed
            .sessionManagement(s -> s.sessionCreationPolicy(STATELESS))
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/api/v1/auth/**").permitAll()
                .requestMatchers("/actuator/health").permitAll()
                .anyRequest().authenticated()
            )
            .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()))
            .build();
    }
}
```

### Method Security

```java
@PreAuthorize("hasRole('ADMIN')")
public void deleteUser(Long id) { ... }

@PreAuthorize("hasRole('USER') and #userId == authentication.principal.id")
public UserResponse getUser(Long userId) { ... }
```

### Pitfalls
- `permitAll()` on non-public endpoints.
- `allowedOrigins("*")` in production CORS config.
- JWT secret shorter than 256 bits.
- Returning stack traces in error responses.
- `SecurityContext` passed as method parameter instead of using `SecurityContextHolder`.

### Referenced By
`security-agent`, `implementation-agent`

---

## 4. Async Patterns

### When to Use
Non-blocking operations: email sending, event publishing, background jobs.

### @Async

```java
@Configuration
@EnableAsync
public class AsyncConfig {
    @Bean("asyncExecutor")
    public Executor asyncExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(4);
        executor.setMaxPoolSize(10);
        executor.setQueueCapacity(100);
        executor.setThreadNamePrefix("async-");
        executor.initialize();
        return executor;
    }
}

@Service
public class NotificationService {
    @Async("asyncExecutor")
    public CompletableFuture<Void> sendEmail(EmailRequest request) {
        // Must NOT be called from within the same class (proxy bypass)
        return CompletableFuture.runAsync(() -> emailClient.send(request));
    }
}
```

### Spring Application Events

```java
// Publish
applicationEventPublisher.publishEvent(new OrderPlacedEvent(order.getId()));

// Listen (same transaction by default — use @TransactionalEventListener for post-commit)
@TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
public void onOrderPlaced(OrderPlacedEvent event) { ... }
```

### Pitfalls
- `@Async` on a method called from within the same bean — proxy is bypassed, runs synchronously.
- `@Transactional` + `@Async` — transaction context is lost in the new thread.
- Unhandled `CompletableFuture` exceptions — always chain `.exceptionally()` or `.handle()`.
- Virtual Threads (Java 21+): avoid `synchronized` blocks — use `ReentrantLock`.

### Referenced By
`concurrency-agent`, `implementation-agent`

---

## 5. Caching Patterns

### When to Use
Read-heavy data, low update frequency, tolerable staleness (reference data, user profiles, catalogs).

### @Cacheable / @CacheEvict

```java
@Service
public class ProductService {

    @Cacheable(value = "products", key = "#id", unless = "#result == null")
    public ProductResponse findById(Long id) {
        return productRepository.findById(id)
            .map(mapper::toResponse)
            .orElseThrow(() -> new ProductNotFoundException(id));
    }

    @CacheEvict(value = "products", key = "#id")
    public void update(Long id, UpdateProductRequest request) {
        // evict on write to prevent stale reads
    }

    @Caching(evict = {
        @CacheEvict(value = "products", key = "#result.id"),
        @CacheEvict(value = "product-list", allEntries = true)
    })
    public ProductResponse create(CreateProductRequest request) { ... }
}
```

### Redis Config (distributed — required for multi-instance)

```java
@Bean
public RedisCacheConfiguration cacheConfiguration() {
    return RedisCacheConfiguration.defaultCacheConfig()
        .entryTtl(Duration.ofMinutes(10))          // always define TTL
        .disableCachingNullValues()
        .serializeValuesWith(
            RedisSerializationContext.SerializationPair
                .fromSerializer(new GenericJackson2JsonRedisSerializer())
        );
}
```

### Pitfalls
- No TTL defined — cache grows unbounded, stale data never expires.
- Caching mutable, write-heavy data.
- Missing `@CacheEvict` on writes — stale reads after mutations.
- Using default Java serialization for Redis — not portable across restarts.
- Caching entities directly (includes lazy proxies) — always cache DTOs.

### Referenced By
`performance-agent`, `implementation-agent`

---

## 6. Exception Handling Patterns

### When to Use
All Spring Boot REST APIs. Centralized `@ControllerAdvice` is mandatory.

### @ControllerAdvice + ProblemDetail (Spring Boot 3)

```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(EntityNotFoundException.class)
    public ProblemDetail handleNotFound(EntityNotFoundException ex) {
        ProblemDetail pd = ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.getMessage());
        pd.setTitle("Resource Not Found");
        return pd;
    }

    @ExceptionHandler(ConstraintViolationException.class)
    public ProblemDetail handleValidation(ConstraintViolationException ex) {
        ProblemDetail pd = ProblemDetail.forStatus(HttpStatus.UNPROCESSABLE_ENTITY);
        pd.setTitle("Validation Failed");
        pd.setProperty("violations", ex.getConstraintViolations().stream()
            .map(v -> v.getPropertyPath() + ": " + v.getMessage())
            .toList());
        return pd;
    }

    @ExceptionHandler(Exception.class)
    public ProblemDetail handleUnexpected(Exception ex) {
        log.error("Unhandled exception", ex);
        return ProblemDetail.forStatusAndDetail(
            HttpStatus.INTERNAL_SERVER_ERROR,
            "An unexpected error occurred"   // never expose internal details
        );
    }
}
```

### Pitfalls
- Returning stack traces in production responses — always use `ProblemDetail` or a structured DTO.
- Swallowing exceptions with empty catch blocks.
- Using `RuntimeException` directly — define a domain exception hierarchy.
- Inconsistent HTTP status codes — 400 for client errors, 500 for server errors.

### Referenced By
`code-review-agent`, `implementation-agent`, `security-agent`

---

## 7. Transaction Boundary Patterns

### When to Use
Any operation that modifies state in the database. Default: read-only for queries.

### Correct Placement

```java
// Application layer (use case) owns the transaction
@Service
public class TransferUseCase {

    @Transactional  // transaction boundary at use-case level
    public TransferResult execute(TransferCommand command) {
        Account source = accountRepository.findById(command.sourceId())
            .orElseThrow();
        Account target = accountRepository.findById(command.targetId())
            .orElseThrow();

        source.debit(command.amount());   // domain logic — no transaction annotation here
        target.credit(command.amount());

        accountRepository.save(source);
        accountRepository.save(target);

        eventPublisher.publishEvent(new TransferCompletedEvent(command));
        return TransferResult.success();
    }

    @Transactional(readOnly = true)
    public AccountBalance getBalance(Long accountId) { ... }
}
```

### Propagation Reference

| Propagation | Use Case |
|---|---|
| `REQUIRED` (default) | Join existing or create new |
| `REQUIRES_NEW` | Audit log that must commit even if outer tx rolls back |
| `NOT_SUPPORTED` | Read-only reporting that must not join a write transaction |
| `MANDATORY` | Assert caller must have opened a transaction |

### Pitfalls
- `@Transactional` on domain objects — belongs in application layer only.
- Opening a transaction before an external HTTP call — hold locks across network I/O.
- `@Transactional` + `@Async` — transaction is not propagated to new thread.
- `self-invocation` — calling a `@Transactional` method from within the same bean bypasses the proxy.

### Referenced By
`data-integrity-agent`, `implementation-agent`, `concurrency-agent`

---

## 8. Validation Patterns

### When to Use
All incoming data at the API boundary (request DTOs, path variables, query params).

### Bean Validation

```java
public record CreateUserRequest(
    @NotBlank(message = "Name is required")
    @Size(min = 2, max = 100)
    String name,

    @NotBlank
    @Email(message = "Invalid email format")
    String email,

    @NotNull
    @Min(18)
    Integer age
) {}

// Controller — trigger validation
@PostMapping("/users")
public ResponseEntity<UserResponse> create(@Valid @RequestBody CreateUserRequest request) { ... }
```

### Custom Validator

```java
@Target(ElementType.FIELD)
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = CpfValidator.class)
public @interface ValidCpf {
    String message() default "Invalid CPF";
    Class<?>[] groups() default {};
    Class<? extends Payload>[] payload() default {};
}

public class CpfValidator implements ConstraintValidator<ValidCpf, String> {
    @Override
    public boolean isValid(String value, ConstraintValidatorContext ctx) {
        return value != null && CpfUtils.isValid(value);
    }
}
```

### Pitfalls
- Validating only at the service layer — validate at the boundary, fail fast.
- Missing `@Valid` on `@RequestBody` — Bean Validation silently skipped.
- Trusting client-supplied IDs in path variables — validate existence in the database.
- Using `@NotEmpty` where `@NotBlank` is needed (whitespace-only strings pass `@NotEmpty`).

### Referenced By
`implementation-agent`, `security-agent`, `code-review-agent`

---

## 9. Observability Patterns

### When to Use
All production services. Structured logging and metrics are non-negotiable.

### Structured Logging with MDC

```java
@Component
public class MdcLoggingFilter implements Filter {
    @Override
    public void doFilter(ServletRequest req, ServletResponse res, FilterChain chain)
        throws IOException, ServletException {
        MDC.put("traceId", UUID.randomUUID().toString());
        MDC.put("userId", extractUserId((HttpServletRequest) req));
        try {
            chain.doFilter(req, res);
        } finally {
            MDC.clear();   // critical — prevent MDC leakage in thread pools
        }
    }
}

// Logback pattern — include MDC fields
// %d{ISO8601} [%X{traceId}] [%X{userId}] %-5level %logger{36} - %msg%n
```

### Micrometer Metrics

```java
@Service
public class PaymentService {

    private final Counter paymentSuccessCounter;
    private final Timer paymentTimer;

    public PaymentService(MeterRegistry registry) {
        this.paymentSuccessCounter = Counter.builder("payments.success")
            .description("Successful payment count")
            .register(registry);
        this.paymentTimer = Timer.builder("payments.duration")
            .description("Payment processing latency")
            .register(registry);
    }

    public PaymentResult process(PaymentCommand command) {
        return paymentTimer.record(() -> {
            PaymentResult result = doProcess(command);
            if (result.isSuccessful()) paymentSuccessCounter.increment();
            return result;
        });
    }
}
```

### @Timed (declarative)

```java
@Timed(value = "orders.create", description = "Order creation latency")
@PostMapping("/orders")
public ResponseEntity<OrderResponse> create(@Valid @RequestBody CreateOrderRequest req) { ... }
```

### Pitfalls
- String concatenation in log messages instead of parameterized logging (`log.debug("x={}", x)`).
- Logging PII (email, SSN, card numbers) — always mask.
- Not clearing MDC after request — causes context leakage in thread pools.
- Missing metrics on critical business operations — latency and error rate are mandatory for SLO tracking.

### Referenced By
`observability-agent`, `security-agent`

---

## 10. Messaging Patterns

### When to Use
Event-driven communication between bounded contexts, async workloads, decoupled producers/consumers.

### @KafkaListener (Idempotent Consumer)

```java
@Component
public class OrderEventConsumer {

    @KafkaListener(topics = "orders.placed", groupId = "payment-service")
    public void onOrderPlaced(
        @Payload OrderPlacedEvent event,
        @Header(KafkaHeaders.RECEIVED_KEY) String key,
        Acknowledgment ack
    ) {
        if (idempotencyService.alreadyProcessed(event.eventId())) {
            ack.acknowledge();   // deduplicate — safe to skip
            return;
        }

        try {
            paymentUseCase.initiatePayment(event);
            idempotencyService.markProcessed(event.eventId());
            ack.acknowledge();
        } catch (NonRetryableException e) {
            log.error("Non-retryable error processing event {}", event.eventId(), e);
            ack.acknowledge();   // send to DLQ via error handler config
        }
        // Retryable exceptions — do NOT ack, Kafka will redeliver
    }
}
```

### Transactional Outbox Pattern

```java
// Within the same @Transactional boundary as business logic:
@Transactional
public Order placeOrder(PlaceOrderCommand command) {
    Order order = Order.place(command);
    orderRepository.save(order);

    // Write event to outbox table — same DB transaction
    outboxRepository.save(OutboxEvent.of("orders.placed", order.getId(), event));

    return order;
}
// Separate outbox poller publishes events to Kafka after commit
```

### Pitfalls
- Non-idempotent consumer — Kafka guarantees at-least-once delivery.
- Missing DLQ configuration — failed messages are silently lost.
- Publishing events directly in `@Transactional` method before commit — event may be published for a rolled-back transaction.
- `@KafkaListener` without error handler — unhandled exceptions block the consumer.

### Referenced By
`integration-agent`, `failure-chaos-agent`, `data-integrity-agent`
