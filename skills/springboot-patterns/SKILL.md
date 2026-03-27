---
name: springboot-patterns
description: >
  Load when structuring Spring Boot packages (Controller/Service/Repository/Domain), writing
  @Service use-case classes, configuring @Async thread pools, applying @Cacheable/@CacheEvict
  with Redis, writing @RestControllerAdvice exception handlers, defining @Transactional
  propagation boundaries (REQUIRED/REQUIRES_NEW/readOnly), adding @Valid Bean Validation,
  configuring MDC structured logging, or setting up @KafkaListener idempotent consumers.
---

# Spring Boot Patterns

## 1. Layered Architecture

Standard Spring Boot projects use a four-layer structure with a strict dependency direction: Controller → Service → Repository → Domain.

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

**Pitfalls:** Never expose JPA entities from controllers. Never put business logic in controllers. Domain layer must have zero Spring or JPA imports.

---

## 2. JPA Patterns

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
```

**Pitfalls:** `FetchType.EAGER` on `@OneToMany` is always wrong. `findAll()` on large tables without Pageable causes memory exhaustion. Use `orElseThrow()` instead of `get()`.

---

## 3. Spring Security (Spring Boot 3 / Spring Security 6)

```java
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        return http
            .csrf(AbstractHttpConfigurer::disable)
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

Method security: `@PreAuthorize("hasRole('ADMIN')")` and `@PreAuthorize("hasRole('USER') and #userId == authentication.principal.id")`.

---

## 4. Async Patterns

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
```

**Pitfalls:** `@Async` on a method called from within the same bean bypasses the proxy. `@Transactional` + `@Async` — transaction is lost in the new thread. Always chain `.exceptionally()` on `CompletableFuture`.

---

## 5. Caching Patterns

```java
@Cacheable(value = "products", key = "#id", unless = "#result == null")
public ProductResponse findById(Long id) { ... }

@CacheEvict(value = "products", key = "#id")
public void update(Long id, UpdateProductRequest request) { ... }
```

Redis config: always define TTL, use `GenericJackson2JsonRedisSerializer`, disable caching null values.

**Pitfalls:** No TTL → stale data. Missing `@CacheEvict` on writes. Caching JPA entities (includes lazy proxies) — cache DTOs only.

---

## 6. Exception Handling — @ControllerAdvice + ProblemDetail (Spring Boot 3)

```java
@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(EntityNotFoundException.class)
    public ProblemDetail handleNotFound(EntityNotFoundException ex) {
        ProblemDetail pd = ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.getMessage());
        pd.setTitle("Resource Not Found");
        return pd;
    }

    @ExceptionHandler(Exception.class)
    public ProblemDetail handleUnexpected(Exception ex) {
        log.error("Unhandled exception", ex);
        return ProblemDetail.forStatusAndDetail(HttpStatus.INTERNAL_SERVER_ERROR, "An unexpected error occurred");
    }
}
```

---

## 7. Transaction Boundaries

```java
@Service
public class TransferUseCase {

    @Transactional
    public TransferResult execute(TransferCommand command) {
        Account source = accountRepository.findById(command.sourceId()).orElseThrow();
        Account target = accountRepository.findById(command.targetId()).orElseThrow();
        source.debit(command.amount());
        target.credit(command.amount());
        accountRepository.save(source);
        accountRepository.save(target);
        return TransferResult.success();
    }

    @Transactional(readOnly = true)
    public AccountBalance getBalance(Long accountId) { ... }
}
```

**Propagation reference:** `REQUIRED` (default) = join existing or create new. `REQUIRES_NEW` = audit log. `NOT_SUPPORTED` = read-only reporting. `MANDATORY` = assert caller has transaction.

---

## 8. Bean Validation

```java
public record CreateUserRequest(
    @NotBlank @Size(min = 2, max = 100) String name,
    @NotBlank @Email String email,
    @NotNull @Min(18) Integer age
) {}

@PostMapping("/users")
public ResponseEntity<UserResponse> create(@Valid @RequestBody CreateUserRequest request) { ... }
```

**Pitfalls:** Missing `@Valid` silently skips validation. Use `@NotBlank` (not `@NotEmpty`) for strings. Validate at the boundary, not in the service.

---

## 9. Observability — Structured Logging + Micrometer

```java
@Component
public class MdcLoggingFilter implements Filter {
    @Override
    public void doFilter(ServletRequest req, ServletResponse res, FilterChain chain) throws IOException, ServletException {
        MDC.put("traceId", UUID.randomUUID().toString());
        MDC.put("userId", extractUserId((HttpServletRequest) req));
        try {
            chain.doFilter(req, res);
        } finally {
            MDC.clear(); // critical — prevent MDC leakage in thread pools
        }
    }
}
```

```java
@Timed(value = "orders.create", description = "Order creation latency")
@PostMapping("/orders")
public ResponseEntity<OrderResponse> create(@Valid @RequestBody CreateOrderRequest req) { ... }
```

---

## 10. Messaging — Idempotent Kafka Consumer

```java
@KafkaListener(topics = "orders.placed", groupId = "payment-service")
public void onOrderPlaced(@Payload OrderPlacedEvent event, Acknowledgment ack) {
    if (idempotencyService.alreadyProcessed(event.eventId())) {
        ack.acknowledge();
        return;
    }
    try {
        paymentUseCase.initiatePayment(event);
        idempotencyService.markProcessed(event.eventId());
        ack.acknowledge();
    } catch (NonRetryableException e) {
        log.error("Non-retryable error processing event {}", event.eventId(), e);
        ack.acknowledge(); // send to DLQ via error handler config
    }
    // Retryable exceptions: do NOT ack, Kafka will redeliver
}
```
