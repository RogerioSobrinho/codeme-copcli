---
name: resilience-patterns
description: >
  Load when adding @CircuitBreaker, @Retry, @Bulkhead, @RateLimiter, or @TimeLimiter from
  Resilience4j, configuring WebClient or RestClient with retry operators, writing fallback
  methods, handling CircuitBreakerOpenException or BulkheadFullException, configuring
  resilience4j in application.yml (slidingWindowType, failureRateThreshold, waitDurationInOpenState),
  or testing circuit breaker state transitions with @SpringBootTest.
---

# Resilience Patterns for Spring Boot (Resilience4j)

## Dependency
```xml
<dependency>
    <groupId>io.github.resilience4j</groupId>
    <artifactId>resilience4j-spring-boot3</artifactId>
</dependency>
<!-- AOP required for annotations -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-aop</artifactId>
</dependency>
```

---

## Circuit Breaker

Prevents cascading failures by short-circuiting calls to a failing dependency.

### Configuration
```yaml
resilience4j:
  circuitbreaker:
    instances:
      payment-gateway:
        register-health-indicator: true
        sliding-window-type: COUNT_BASED
        sliding-window-size: 10            # number of calls to evaluate
        failure-rate-threshold: 50         # % failures to open the circuit
        slow-call-rate-threshold: 50       # % slow calls to open the circuit
        slow-call-duration-threshold: 2s
        wait-duration-in-open-state: 30s   # how long to stay OPEN before HALF_OPEN
        permitted-number-of-calls-in-half-open-state: 5
        automatic-transition-from-open-to-half-open-enabled: true
        record-exceptions:
          - java.io.IOException
          - java.util.concurrent.TimeoutException
        ignore-exceptions:
          - com.example.order.exception.BusinessValidationException
```

### Usage
```java
@Service
@RequiredArgsConstructor
public class PaymentService {

    @CircuitBreaker(name = "payment-gateway", fallbackMethod = "paymentFallback")
    public PaymentResult charge(ChargeRequest request) {
        return externalPaymentGateway.charge(request);
    }

    // Fallback — same return type, extra Throwable parameter
    private PaymentResult paymentFallback(ChargeRequest request, Exception ex) {
        log.warn("Payment gateway unavailable, queuing for retry chargeId={}", request.id(), ex);
        pendingChargeQueue.enqueue(request);
        return PaymentResult.queued(request.id());
    }
}
```

### States

```
CLOSED → (failure rate ≥ threshold) → OPEN → (waitDuration elapsed) → HALF_OPEN → (test calls succeed) → CLOSED
                                                                                 → (test calls fail)    → OPEN
```

**CLOSED**: Normal operation, all calls pass through.  
**OPEN**: All calls fail immediately with `CallNotPermittedException`. Fallback is invoked.  
**HALF_OPEN**: Limited test calls allowed. Determines if the dependency recovered.

---

## Retry

Automatic retry with backoff for transient failures.

### Configuration
```yaml
resilience4j:
  retry:
    instances:
      inventory-service:
        max-attempts: 3
        wait-duration: 500ms
        enable-exponential-backoff: true
        exponential-backoff-multiplier: 2      # 500ms, 1000ms, 2000ms
        exponential-max-wait-duration: 10s
        retry-exceptions:
          - java.io.IOException
          - org.springframework.web.client.ResourceAccessException
        ignore-exceptions:
          - com.example.exception.InvalidRequestException
```

**Critical: Always add jitter to prevent thundering herd.**
```yaml
resilience4j:
  retry:
    instances:
      inventory-service:
        wait-duration: 500ms
        enable-exponential-backoff: true
        exponential-backoff-multiplier: 2
        randomized-wait-factor: 0.5   # ±50% jitter applied to wait duration
```

### Usage
```java
@Retry(name = "inventory-service", fallbackMethod = "inventoryFallback")
@CircuitBreaker(name = "inventory-service")  // Combine retry + circuit breaker
public InventoryStatus checkStock(String productId) {
    return inventoryClient.getStock(productId);
}

private InventoryStatus inventoryFallback(String productId, Exception ex) {
    log.warn("Inventory service unavailable, returning optimistic stock productId={}", productId, ex);
    return InventoryStatus.assumeAvailable(productId);
}
```

**Order matters:** `@Retry` wraps `@CircuitBreaker`. Retry fires first; if the circuit is open, retries immediately fail.

---

## Bulkhead — Concurrency Limiter

Limits the number of concurrent calls to a dependency. Prevents a slow service from consuming all threads.

### Semaphore Bulkhead (default — blocks calling thread)
```yaml
resilience4j:
  bulkhead:
    instances:
      payment-gateway:
        max-concurrent-calls: 20      # max simultaneous in-flight calls
        max-wait-duration: 100ms      # how long to wait for a permit before BulkheadFullException
```

```java
@Bulkhead(name = "payment-gateway", type = Bulkhead.Type.SEMAPHORE,
          fallbackMethod = "bulkheadFallback")
public PaymentResult charge(ChargeRequest request) { ... }

private PaymentResult bulkheadFallback(ChargeRequest request, BulkheadFullException ex) {
    return PaymentResult.rejected("System is busy — please retry shortly");
}
```

### Thread Pool Bulkhead (non-blocking reactive)
```yaml
resilience4j:
  thread-pool-bulkhead:
    instances:
      email-service:
        max-thread-pool-size: 10
        core-thread-pool-size: 5
        queue-capacity: 50
```

```java
@Bulkhead(name = "email-service", type = Bulkhead.Type.THREADPOOL)
public CompletableFuture<Void> sendEmail(EmailRequest request) {
    return CompletableFuture.runAsync(() -> emailClient.send(request));
}
```

---

## Rate Limiter

Limits calls per time period. Protects external APIs with rate limits.

```yaml
resilience4j:
  ratelimiter:
    instances:
      sendgrid-api:
        limit-for-period: 100          # 100 calls per refresh period
        limit-refresh-period: 1s
        timeout-duration: 200ms        # wait at most 200ms for a permit
```

```java
@RateLimiter(name = "sendgrid-api", fallbackMethod = "rateLimitFallback")
public void sendEmail(EmailRequest request) {
    sendgridClient.send(request);
}

private void rateLimitFallback(EmailRequest request, RequestNotPermitted ex) {
    log.warn("Rate limit exceeded, queuing email recipient={}", request.to());
    emailQueue.enqueue(request);
}
```

---

## Time Limiter — Async Timeouts

Enforces a timeout on `CompletableFuture` or reactive operations. Use with `@Bulkhead(THREADPOOL)`.

```yaml
resilience4j:
  timelimiter:
    instances:
      slow-report-service:
        timeout-duration: 3s
        cancel-running-future: true
```

```java
@TimeLimiter(name = "slow-report-service", fallbackMethod = "reportTimeout")
@Bulkhead(name = "slow-report-service", type = Bulkhead.Type.THREADPOOL)
public CompletableFuture<Report> generateReport(ReportRequest request) {
    return CompletableFuture.supplyAsync(() -> reportService.generate(request));
}

private CompletableFuture<Report> reportTimeout(ReportRequest request, TimeoutException ex) {
    return CompletableFuture.completedFuture(Report.partial(request.id(), "Report is taking longer than expected"));
}
```

---

## WebClient Retry (Reactive)

For reactive stacks — retry at the HTTP client level:

```java
@Bean
public WebClient paymentWebClient() {
    return WebClient.builder()
        .baseUrl(paymentGatewayUrl)
        .build();
}

public Mono<PaymentResponse> chargeReactive(ChargeRequest request) {
    return webClient.post()
        .uri("/charge")
        .bodyValue(request)
        .retrieve()
        .onStatus(HttpStatusCode::is5xxServerError,
            response -> Mono.error(new RetryableException("Gateway 5xx")))
        .bodyToMono(PaymentResponse.class)
        .retryWhen(Retry.backoff(3, Duration.ofMillis(500))
            .maxBackoff(Duration.ofSeconds(5))
            .jitter(0.5)                             // ±50% jitter
            .filter(ex -> ex instanceof RetryableException)
            .onRetryExhaustedThrow((spec, signal) ->
                new PaymentGatewayException("All retries exhausted", signal.failure())));
}
```

---

## Combining Patterns

Recommended combination for an external HTTP dependency:

```java
@CircuitBreaker(name = "payment-gateway", fallbackMethod = "chargeFallback")
@Retry(name = "payment-gateway")
@Bulkhead(name = "payment-gateway")
public PaymentResult charge(ChargeRequest request) {
    return externalGateway.charge(request);
}
```

Execution order (outer → inner): `Bulkhead → CircuitBreaker → Retry → Method`

---

## Testing Circuit Breaker State

```java
@SpringBootTest
class PaymentServiceResilienceTest {

    @Autowired PaymentService paymentService;
    @Autowired CircuitBreakerRegistry registry;

    @MockBean ExternalPaymentGateway externalGateway;

    @Test
    void shouldOpenCircuitAfterFailureThreshold() {
        // Arrange — configure gateway to always fail
        given(externalGateway.charge(any())).willThrow(new IOException("gateway down"));

        CircuitBreaker cb = registry.circuitBreaker("payment-gateway");
        assertThat(cb.getState()).isEqualTo(CircuitBreaker.State.CLOSED);

        // Act — trigger failures to exceed threshold (10 calls, 50% threshold = 5 failures)
        for (int i = 0; i < 10; i++) {
            try { paymentService.charge(aRequest()); } catch (Exception ignored) {}
        }

        // Assert — circuit opened
        assertThat(cb.getState()).isEqualTo(CircuitBreaker.State.OPEN);
    }

    @Test
    void shouldCallFallbackWhenCircuitOpen() {
        CircuitBreaker cb = registry.circuitBreaker("payment-gateway");
        cb.transitionToOpenState();  // force open for test

        PaymentResult result = paymentService.charge(aRequest());

        assertThat(result.status()).isEqualTo(PaymentStatus.QUEUED);
    }
}
```

---

## Pitfalls

| Pitfall | Fix |
|---|---|
| No jitter on retry backoff | Add `randomized-wait-factor: 0.5` — prevents thundering herd at recovery |
| Retrying non-retryable exceptions | Whitelist retryable exceptions; ignore business errors (validation, 400s) |
| Circuit breaker wrapping circuit breaker | One CB per external dependency; do not nest CB annotations |
| Bulkhead maxWaitDuration=0 | At 0, any concurrent call beyond max-concurrent-calls immediately fails — set a small timeout for queuing |
| Fallback with different semantics | Fallback must return a valid (possibly degraded) result — never throw from fallback |
| TimeLimiter without THREADPOOL bulkhead | `@TimeLimiter` requires async execution — always pair with THREADPOOL bulkhead |
| Missing `@EnableAspectJAutoProxy` | Resilience4j annotations require Spring AOP — `spring-boot-starter-aop` must be on classpath |
