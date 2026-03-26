---
name: api-design
description: REST API design reference for Java/Spring Boot. Covers versioning strategies, pagination, error response standards, OpenAPI documentation, and idempotency patterns.
tools: ["Read", "Grep", "Bash"]
model: claude-sonnet-4-5
activation: ["api design", "rest api", "openapi", "api versioning", "pagination api", "error response", "rest design"]
---

# API Design

## Purpose

REST API design reference for Java/Spring Boot services. Covers resource naming, HTTP method semantics, versioning strategies, pagination patterns, RFC 7807 error responses, OpenAPI/Swagger documentation, idempotency, HATEOAS, and rate limiting. Use this skill when designing new endpoints, reviewing API consistency, or evolving existing contracts.

---

## Resource Naming

### Rules
- Use **plural nouns** for collection resources: `/orders`, `/products`, `/customers`
- Use **hierarchy** to express relationships, max 2 levels deep: `/orders/{id}/items`
- Avoid verbs in paths — use HTTP methods for actions
- Use **kebab-case** for multi-word resources: `/order-items`, not `/orderItems`
- Query parameters for filtering/sorting: `/orders?status=PENDING&sort=createdAt,desc`

### Path vs Query Parameters
| Use Path Parameter | Use Query Parameter |
|---|---|
| Identifying a specific resource: `/orders/{id}` | Filtering: `/orders?status=PENDING` |
| Hierarchy: `/customers/{id}/orders` | Sorting: `?sort=createdAt,desc` |
| | Pagination: `?page=0&size=20` |
| | Optional fields: `?fields=id,status` |

---

## HTTP Methods — Semantics & Idempotency Matrix

| Method | Semantic | Safe | Idempotent | Body |
|---|---|---|---|---|
| GET | Retrieve | ✅ | ✅ | No |
| POST | Create | ❌ | ❌ | Yes |
| PUT | Replace (full update) | ❌ | ✅ | Yes |
| PATCH | Partial update | ❌ | ❌ (can be) | Yes |
| DELETE | Delete | ❌ | ✅ | No |
| HEAD | Metadata only | ✅ | ✅ | No |

### Safe vs Idempotent
- **Safe:** No side effects (GET, HEAD) — can be cached.
- **Idempotent:** Calling N times = same result as calling once (GET, PUT, DELETE).
- POST is neither — calling twice creates two resources.

---

## Versioning — URI vs Header vs Accept

### Option 1 — URI Versioning
```
GET /api/v1/orders
GET /api/v2/orders
```
**Pros:** Visible, cacheable, easy to route in gateways. **Cons:** Pollutes URLs; resource URI changes.

### Option 2 — Custom Header
```
GET /api/orders
API-Version: 2
```
**Pros:** Clean URLs. **Cons:** Not visible in browser, harder to test.

### Option 3 — Accept Header (Content Negotiation)
```
GET /api/orders
Accept: application/vnd.example.v2+json
```
**Pros:** REST-purist approach. **Cons:** Complex to implement and consume.

### Recommendation
**Use URI versioning** (`/api/v1/`) for public APIs and inter-service APIs. Header versioning for internal APIs where URL cleanliness is prioritized.

### Spring Boot URI Versioning
```java
@RestController
@RequestMapping("/api/v1/orders")
public class OrderControllerV1 { ... }

@RestController
@RequestMapping("/api/v2/orders")
public class OrderControllerV2 { ... }
```

---

## Pagination — Cursor vs Offset

### Offset Pagination (Simple)
```
GET /orders?page=0&size=20
```
```json
{
  "content": [...],
  "page": { "size": 20, "number": 0, "totalElements": 500, "totalPages": 25 }
}
```
**Pros:** Easy to jump to page N. **Cons:** Inconsistent results when data changes mid-query; expensive `OFFSET` for high page numbers.

### Cursor Pagination (Recommended for large datasets)
```
GET /orders?limit=20&after=eyJpZCI6MTAwfQ==
```
```json
{
  "data": [...],
  "pagination": {
    "limit": 20,
    "hasNextPage": true,
    "nextCursor": "eyJpZCI6MTIwfQ=="
  }
}
```
**Pros:** Consistent; efficient (no OFFSET); works with infinite scroll. **Cons:** Cannot jump to page N.

### `Link` Header (RFC 5988)
```
Link: </orders?page=1>; rel="next", </orders?page=24>; rel="last"
```

### Spring Boot `Page<T>` Response Envelope
```java
@GetMapping
public ResponseEntity<Page<OrderDto>> list(Pageable pageable) {
    return ResponseEntity.ok(orderService.findAll(pageable).map(orderMapper::toDto));
}
```

---

## Error Responses — RFC 7807 ProblemDetail

### Standard Format
```json
{
  "type": "https://api.example.com/errors/order-not-found",
  "title": "Order Not Found",
  "status": 404,
  "detail": "Order with ID 123e4567 does not exist.",
  "instance": "/orders/123e4567",
  "traceId": "7b3f4c2a"
}
```

### Spring Boot 3 — `ProblemDetail`
```java
@ExceptionHandler(OrderNotFoundException.class)
public ProblemDetail handleOrderNotFound(OrderNotFoundException ex, HttpServletRequest request) {
    var problem = ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.getMessage());
    problem.setType(URI.create("https://api.example.com/errors/order-not-found"));
    problem.setTitle("Order Not Found");
    problem.setProperty("traceId", MDC.get("traceId"));
    return problem;
}
```

### `@ControllerAdvice` Centralized Handler
```java
@ControllerAdvice
public class GlobalExceptionHandler extends ResponseEntityExceptionHandler {

    @ExceptionHandler(BusinessValidationException.class)
    public ProblemDetail handleValidationException(BusinessValidationException ex) {
        var problem = ProblemDetail.forStatusAndDetail(HttpStatus.UNPROCESSABLE_ENTITY, ex.getMessage());
        problem.setProperty("violations", ex.getViolations());
        return problem;
    }
}
```

---

## Status Codes — Correct Usage

| Code | When |
|---|---|
| 200 OK | Successful GET, PUT, PATCH |
| 201 Created | Successful POST that creates a resource; include `Location` header |
| 204 No Content | Successful DELETE or action with no response body |
| 400 Bad Request | Malformed request syntax, invalid JSON |
| 401 Unauthorized | Missing or invalid authentication credentials |
| 403 Forbidden | Authenticated but not authorized for this resource |
| 404 Not Found | Resource does not exist |
| 409 Conflict | Duplicate creation attempt, optimistic lock failure |
| 422 Unprocessable Entity | Syntactically valid but semantically invalid (business rule violation) |
| 500 Internal Server Error | Unexpected server error — do NOT expose stack traces |

---

## OpenAPI/Swagger — springdoc-openapi

### Dependency
```xml
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
    <version>2.3.0</version>
</dependency>
```

### Controller Annotations
```java
@Operation(summary = "Create an order", description = "Creates a new order for the given customer.")
@ApiResponses({
    @ApiResponse(responseCode = "201", description = "Order created",
        content = @Content(schema = @Schema(implementation = OrderResponse.class))),
    @ApiResponse(responseCode = "400", description = "Invalid request",
        content = @Content(schema = @Schema(implementation = ProblemDetail.class))),
    @ApiResponse(responseCode = "422", description = "Business rule violation")
})
@PostMapping
public ResponseEntity<OrderResponse> create(@Valid @RequestBody CreateOrderRequest request) { ... }
```

### Schema Validation
```java
@Schema(description = "Order creation request")
public record CreateOrderRequest(
    @Schema(description = "Customer identifier", example = "123e4567-e89b-12d3-a456-426614174000")
    @NotNull UUID customerId,

    @Schema(description = "List of order items", minItems = 1)
    @NotEmpty List<OrderItemRequest> items
) {}
```

---

## Idempotency — `Idempotency-Key` Header

### Problem
POST is not idempotent. Network retries can create duplicate resources.

### Pattern
1. Client sends `Idempotency-Key: <uuid>` on POST requests.
2. Server checks a deduplication table.
3. If key seen → return cached response.
4. If key new → process, store result, return response.

### Implementation
```java
@PostMapping
public ResponseEntity<OrderResponse> create(
        @RequestHeader("Idempotency-Key") String idempotencyKey,
        @Valid @RequestBody CreateOrderRequest request) {

    return idempotencyService.executeIfNotDuplicate(
        idempotencyKey,
        () -> orderService.create(request),
        OrderResponse.class
    );
}
```

### Deduplication Table
```sql
CREATE TABLE idempotency_keys (
    key VARCHAR(64) PRIMARY KEY,
    response_body JSONB NOT NULL,
    status_code INT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```
TTL: expire keys after 24 hours.

---

## HATEOAS — When to Use

### Use When
- Clients need to discover available actions dynamically (e.g., order status determines valid next actions)
- API contract is volatile and clients should not hardcode URLs

### Do NOT Use When
- Simple CRUD APIs where consumers know the URL structure
- The added complexity outweighs the discovery benefit

### Pattern with WebMvcLinkBuilder
```java
OrderDto dto = orderMapper.toDto(order);
dto.add(linkTo(methodOn(OrderController.class).get(order.getId())).withSelfRel());
dto.add(linkTo(methodOn(OrderController.class).cancel(order.getId())).withRel("cancel"));
```

---

## Rate Limiting — Bucket4j + Spring Boot

### Dependency
```xml
<dependency>
    <groupId>com.bucket4j</groupId>
    <artifactId>bucket4j-core</artifactId>
    <version>8.7.0</version>
</dependency>
```

### Filter Pattern
```java
@Component
public class RateLimitFilter extends OncePerRequestFilter {

    private final Map<String, Bucket> buckets = new ConcurrentHashMap<>();

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        var bucket = buckets.computeIfAbsent(getClientId(request), k -> createBucket());
        var probe = bucket.tryConsumeAndReturnRemaining(1);

        response.addHeader("X-RateLimit-Remaining", String.valueOf(probe.getRemainingTokens()));
        response.addHeader("X-RateLimit-Limit", "100");

        if (probe.isConsumed()) {
            chain.doFilter(request, response);
        } else {
            response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
            response.addHeader("X-RateLimit-Retry-After-Seconds",
                String.valueOf(probe.getNanosToWaitForRefill() / 1_000_000_000));
        }
    }

    private Bucket createBucket() {
        return Bucket.builder()
            .addLimit(Bandwidth.classic(100, Refill.greedy(100, Duration.ofMinutes(1))))
            .build();
    }
}
```

---

## Standalone Invocation (No Orchestrator)

This agent can be invoked directly without the orchestrator. When `.copilot-runtime/artifacts/context.json` is absent, three options are available:

**Option 1 — Run Diagnostic Commands Directly**
Execute targeted commands to gather context on the fly:
- `grep -r "@RestController\|@RequestMapping\|@GetMapping\|@PostMapping" src/main --include="*.java" -l`
- `find src/main -name "*.java" | xargs grep -l "ResponseEntity" | head -10`
- Pros: Fast, zero extra agent invocations
- Cons: Partial context; may miss cross-cutting concerns

**Option 2 — Invoke `codebase-explorer-agent` First**
Ask the user to run `codebase-explorer-agent`, wait for `.copilot-runtime/artifacts/context.json`, then re-run this agent.
- Pros: Richer, consistent context shared with all downstream agents
- Cons: Extra manual step; slightly slower

**Option 3 (RECOMMENDED) — Auto-Bootstrap then Proceed**
Invoke `codebase-explorer-agent` automatically, consume the resulting `context.json`, then continue execution without user intervention.
- Pros: Fully autonomous; deterministic context; no coordination overhead
- Cons: Slightly longer cold start
- **Why recommended:** Eliminates user coordination overhead and guarantees all agents share the same project baseline.

After context is available via any option, resume normal execution flow.
