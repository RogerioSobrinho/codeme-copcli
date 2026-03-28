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

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ProblemDetail handleValidation(MethodArgumentNotValidException ex) {
        String detail = ex.getBindingResult().getFieldErrors().stream()
            .map(e -> e.getField() + ": " + e.getDefaultMessage())
            .collect(Collectors.joining(", "));
        ProblemDetail pd = ProblemDetail.forStatusAndDetail(HttpStatus.BAD_REQUEST, detail);
        pd.setTitle("Validation Failed");
        return pd;
    }

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

---

## 11. Request Logging Filter

```java
@Component
public class RequestLoggingFilter extends OncePerRequestFilter {
    private static final Logger log = LoggerFactory.getLogger(RequestLoggingFilter.class);

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
        FilterChain filterChain) throws ServletException, IOException {
        long start = System.currentTimeMillis();
        try {
            filterChain.doFilter(request, response);
        } finally {
            long duration = System.currentTimeMillis() - start;
            log.info("req method={} uri={} status={} durationMs={}",
                request.getMethod(), request.getRequestURI(), response.getStatus(), duration);
        }
    }
}
```

---

## 12. Error-Resilient External Calls

For calls to downstream services, use exponential backoff with a bounded retry ceiling. Prefer Resilience4j `@Retry` in Spring apps; use the manual pattern only when the library is unavailable.

```java
public <T> T withRetry(Supplier<T> supplier, int maxRetries) {
    int attempts = 0;
    while (true) {
        try {
            return supplier.get();
        } catch (Exception ex) {
            attempts++;
            if (attempts >= maxRetries) throw ex;
            try {
                Thread.sleep((long) Math.pow(2, attempts) * 100L); // exponential backoff
            } catch (InterruptedException ie) {
                Thread.currentThread().interrupt();
                throw ex;
            }
        }
    }
}
```

**Pitfalls:** Never retry non-idempotent writes without an idempotency key. Always set a max-retry ceiling. Prefer Resilience4j `@Retry` for production — it handles jitter, fallback, and metrics automatically.

---

## 13. Rate Limiting (Bucket4j)

**Security Note:** `X-Forwarded-For` is untrusted by default — clients can spoof it. Only read forwarded headers after configuring `server.forward-headers-strategy=FRAMEWORK` (or `NATIVE`) **and** registering `ForwardedHeaderFilter`. Without this, use `request.getRemoteAddr()` directly.

```java
@Component
public class RateLimitFilter extends OncePerRequestFilter {
    private final Map<String, Bucket> buckets = new ConcurrentHashMap<>();

    /*
     * SECURITY: configure server.forward-headers-strategy=FRAMEWORK and register
     * ForwardedHeaderFilter if this service sits behind a reverse proxy (nginx, ALB, etc.).
     * Then getRemoteAddr() returns the real client IP from trusted forwarded headers.
     * Do NOT read X-Forwarded-For directly — it is trivially spoofable.
     */
    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
        FilterChain filterChain) throws ServletException, IOException {
        String clientIp = request.getRemoteAddr();
        Bucket bucket = buckets.computeIfAbsent(clientIp, k ->
            Bucket.builder()
                .addLimit(Bandwidth.classic(100, Refill.greedy(100, Duration.ofMinutes(1))))
                .build());

        if (bucket.tryConsume(1)) {
            filterChain.doFilter(request, response);
        } else {
            response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
            response.getWriter().write("{\"error\": \"Rate limit exceeded\"}");
        }
    }
}
```

---

## 14. Production Defaults Checklist

- `spring.mvc.problemdetails.enabled=true` — RFC 7807 ProblemDetail responses (Spring Boot 3+)
- HikariCP: configure `maximum-pool-size`, `connection-timeout`, `idle-timeout` for workload
- `@Transactional(readOnly = true)` on all read-only service methods
- `@Async` methods always return `CompletableFuture<T>` and chain `.exceptionally()`
- Structured JSON logging via Logback encoder (never plain string concatenation)
- Metrics: Micrometer + Prometheus/OTel; trace IDs in every MDC context
- Cache DTOs only — never cache JPA entities (lazy proxies will serialize incorrectly)
```
