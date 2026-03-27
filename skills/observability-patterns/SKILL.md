---
name: observability-patterns
description: >
  Load when adding @Timed, @Counted, or MeterRegistry metrics, configuring Micrometer with
  Prometheus, setting up OpenTelemetry or Spring Boot distributed tracing (traceId/spanId
  in MDC), writing custom HealthIndicator or HealthContributor, configuring Actuator endpoints
  (management.endpoints.web.exposure), setting up log correlation across services, or
  diagnosing missing traces or metrics in Grafana/Prometheus dashboards.
---

# Observability Patterns for Spring Boot

## The Three Pillars

| Pillar | Tool | Purpose |
|---|---|---|
| **Metrics** | Micrometer + Prometheus | Quantitative signals (latency, error rate, throughput) |
| **Traces** | OpenTelemetry / Micrometer Tracing | Distributed request flow across services |
| **Logs** | Logback + MDC + JSON | Correlated, structured event records |

---

## Metrics — Micrometer

### Dependency (Spring Boot 3)
```xml
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>
```

### Auto-Instrumented via Annotations
```java
// Latency histogram — use on @Service or @RestController methods
@Timed(value = "orders.create", description = "Time to create an order",
       percentiles = {0.5, 0.95, 0.99})
public Order createOrder(CreateOrderCommand command) { ... }

// Counted — use for events, not timings
@Counted(value = "payment.retries", description = "Number of payment retry attempts")
public PaymentResult retryPayment(String orderId) { ... }
```

Enable the annotation processing bean:
```java
@Configuration
public class MetricsConfig {
    @Bean
    public TimedAspect timedAspect(MeterRegistry registry) {
        return new TimedAspect(registry);
    }
}
```

### Manual Metrics (Programmatic)
```java
@Component
@RequiredArgsConstructor
public class OrderMetrics {

    private final MeterRegistry registry;
    private final AtomicInteger pendingOrdersGauge;

    public OrderMetrics(MeterRegistry registry) {
        this.registry = registry;
        this.pendingOrdersGauge = registry.gauge(
            "orders.pending.count",
            Tags.of("region", "us-east"),
            new AtomicInteger(0)
        );
    }

    public void recordOrderCreated(OrderStatus status, String currency) {
        registry.counter("orders.created",
            "status", status.name(),
            "currency", currency
        ).increment();
    }

    public void recordProcessingTime(Duration duration, boolean success) {
        registry.timer("orders.processing.duration",
            "success", String.valueOf(success)
        ).record(duration);
    }

    public void updatePendingCount(int count) {
        pendingOrdersGauge.set(count);
    }
}
```

### Common Metric Types

| Type | Use case | API |
|---|---|---|
| `Counter` | Events that only go up (requests, errors) | `registry.counter("name", tags).increment()` |
| `Timer` | Latency + throughput | `registry.timer("name").record(duration)` |
| `Gauge` | Current state (queue depth, pool size) | `registry.gauge("name", ref, AtomicInteger::get)` |
| `DistributionSummary` | Sizes (payload bytes, batch sizes) | `registry.summary("name").record(value)` |

---

## Distributed Tracing — Micrometer Tracing

### Dependency (Spring Boot 3)
```xml
<!-- Auto-configures tracing via Micrometer Tracing -->
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-tracing-bridge-otel</artifactId>
</dependency>
<dependency>
    <groupId>io.opentelemetry</groupId>
    <artifactId>opentelemetry-exporter-otlp</artifactId>
</dependency>
```

### Configuration
```yaml
management:
  tracing:
    sampling:
      probability: 1.0  # 100% in dev; use 0.1 in production
  otlp:
    tracing:
      endpoint: http://otel-collector:4318/v1/traces

logging:
  pattern:
    level: "%5p [${spring.application.name:},%X{traceId:-},%X{spanId:-}]"
```

Spring Boot 3 automatically injects `traceId` and `spanId` into MDC for every request.

### Manual Span Creation
```java
@Component
@RequiredArgsConstructor
public class ExternalPaymentClient {

    private final Tracer tracer;
    private final WebClient webClient;

    public PaymentResponse charge(ChargeRequest request) {
        Span span = tracer.nextSpan().name("payment-gateway.charge")
            .tag("payment.amount", request.amount().toString())
            .tag("payment.currency", request.currency())
            .start();

        try (Tracer.SpanInScope scope = tracer.withSpan(span)) {
            return webClient.post()
                .uri("/charge")
                .bodyValue(request)
                .retrieve()
                .bodyToMono(PaymentResponse.class)
                .block();
        } catch (Exception e) {
            span.error(e);
            throw e;
        } finally {
            span.end();
        }
    }
}
```

### Propagate Trace Context Across Async Boundaries
```java
@Configuration
@EnableAsync
public class AsyncConfig {

    private final Tracer tracer;

    @Bean("tracingExecutor")
    public Executor tracingExecutor() {
        // Wraps the executor to propagate trace context
        return new ContextExecutorService(
            Executors.newFixedThreadPool(10),
            ContextSnapshot::captureAll
        );
    }
}
```

---

## Structured Logging + MDC

### Logback JSON Configuration (`logback-spring.xml`)
```xml
<configuration>
    <springProfile name="!local">
        <appender name="JSON" class="ch.qos.logback.core.ConsoleAppender">
            <encoder class="net.logstash.logback.encoder.LogstashEncoder">
                <includeMdcKeyName>traceId</includeMdcKeyName>
                <includeMdcKeyName>spanId</includeMdcKeyName>
                <includeMdcKeyName>userId</includeMdcKeyName>
                <includeMdcKeyName>requestId</includeMdcKeyName>
            </encoder>
        </appender>
        <root level="INFO">
            <appender-ref ref="JSON"/>
        </root>
    </springProfile>
</configuration>
```

### MDC Enrichment Filter
```java
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class MdcEnrichmentFilter extends OncePerRequestFilter {

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain chain) throws ServletException, IOException {
        try {
            // requestId for correlation (if client sends X-Request-ID, use that)
            String requestId = Optional.ofNullable(request.getHeader("X-Request-ID"))
                .orElse(UUID.randomUUID().toString());
            MDC.put("requestId", requestId);

            // userId from Spring Security (available after auth filter)
            Optional.ofNullable(SecurityContextHolder.getContext().getAuthentication())
                .map(Authentication::getName)
                .ifPresent(name -> MDC.put("userId", name));

            response.setHeader("X-Request-ID", requestId);
            chain.doFilter(request, response);
        } finally {
            MDC.clear();  // critical: prevents MDC leakage in thread pool
        }
    }
}
```

### Logging Rules

```java
// GOOD — structured key=value or parameterized
log.info("Order created orderId={} customerId={} amount={}", orderId, customerId, amount);

// BAD — string concatenation (allocates even when log level is disabled)
log.info("Order created: " + orderId + " for " + customerId);

// GOOD — guard expensive operations
if (log.isDebugEnabled()) {
    log.debug("Full order state: {}", order.toDebugString());
}

// NEVER — PII or secrets in logs
log.info("Processing payment token={}", token);  // ❌ security violation
log.info("User email={}", user.email());          // ❌ PII violation
```

---

## Actuator Health Checks

### Standard Configuration
```yaml
management:
  endpoints:
    web:
      exposure:
        include: health, info, metrics, prometheus
      base-path: /actuator
  endpoint:
    health:
      show-details: when-authorized   # never 'always' in production
      probes:
        enabled: true                 # enables /actuator/health/liveness and /actuator/health/readiness
  health:
    livenessstate:
      enabled: true
    readinessstate:
      enabled: true
```

### Custom HealthIndicator
```java
@Component
public class PaymentGatewayHealthIndicator implements HealthIndicator {

    private final PaymentGatewayClient client;

    @Override
    public Health health() {
        try {
            PingResponse response = client.ping();
            if (response.isOk()) {
                return Health.up()
                    .withDetail("gateway", response.endpoint())
                    .withDetail("latencyMs", response.latencyMs())
                    .build();
            }
            return Health.down()
                .withDetail("reason", response.errorMessage())
                .build();
        } catch (Exception e) {
            return Health.down(e).build();
        }
    }
}
```

### Readiness vs. Liveness
- **Liveness** (`/actuator/health/liveness`): Is the app alive? If DOWN → Kubernetes restarts the pod. Only set DOWN on unrecoverable internal failure.
- **Readiness** (`/actuator/health/readiness`): Is the app ready to receive traffic? If DOWN → removed from load balancer. Set DOWN during startup warmup, migration, or graceful shutdown.

```java
@Component
@RequiredArgsConstructor
public class StartupReadinessProbe implements ApplicationListener<ApplicationReadyEvent> {

    private final ApplicationContext context;

    @Override
    public void onApplicationEvent(ApplicationReadyEvent event) {
        // Mark as ready only after DB migrations, cache warmup, etc.
        AvailabilityChangeEvent.publish(context, ReadinessState.ACCEPTING_TRAFFIC);
    }
}
```

---

## Prometheus + Grafana Setup

### Prometheus scrape config
```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'spring-boot-service'
    metrics_path: '/actuator/prometheus'
    static_configs:
      - targets: ['service:8080']
```

### Key metrics to alert on

| Metric | Alert condition |
|---|---|
| `http_server_requests_seconds_count` | Error rate > 1% for 5 minutes |
| `http_server_requests_seconds_max` | P99 latency > SLO threshold |
| `jvm_memory_used_bytes` | > 85% of `jvm_memory_max_bytes` |
| `hikaricp_connections_pending` | > 0 for > 30 seconds |
| `process_cpu_usage` | > 80% for > 2 minutes |

---

## Pitfalls

| Pitfall | Fix |
|---|---|
| `sampling.probability=1.0` in production | Use 0.01–0.1; 100% sampling kills performance at scale |
| MDC not cleared after request | Always use `finally { MDC.clear(); }` in filters |
| Logging at DEBUG in prod | Use `WARN` or `INFO` in production; enable DEBUG per-class only when diagnosing |
| Actuator without security | Expose only `health` and `info` publicly; require auth for `metrics`, `env`, `beans` |
| Counter per-exception-message | Use exception class name as tag, not message (cardinality explosion) |
| High-cardinality tags | Never use user IDs, request IDs, or UUIDs as metric tags |
