---
name: api-design
description: >
  Load when designing or reviewing REST endpoints (@GetMapping/@PostMapping/@PutMapping/
  @PatchMapping/@DeleteMapping), HTTP status codes, URL resource naming, API versioning
  strategies (/v1/, Accept-Version header), cursor-based or offset pagination, RFC 7807
  ProblemDetail error responses, OpenAPI/Swagger annotations (@Operation, @ApiResponse,
  @Schema), idempotency-key headers, or HATEOAS links with Spring HATEOAS.
---

# API Design

## Resource Naming

- Use **plural nouns** for collections: `/orders`, `/products`, `/customers`
- Max 2 levels of hierarchy: `/orders/{id}/items`
- Avoid verbs in paths — use HTTP methods for actions
- Use **kebab-case**: `/order-items`, not `/orderItems`
- Query params for filtering/sorting: `/orders?status=PENDING&sort=createdAt,desc`

| Use Path Parameter | Use Query Parameter |
|---|---|
| Identify specific resource: `/orders/{id}` | Filter: `/orders?status=PENDING` |
| Hierarchy: `/customers/{id}/orders` | Sort: `?sort=createdAt,desc` |
| | Paginate: `?page=0&size=20` |

---

## HTTP Methods — Semantics & Idempotency

| Method | Semantic | Safe | Idempotent |
|---|---|---|---|
| GET | Retrieve | ✅ | ✅ |
| POST | Create | ❌ | ❌ |
| PUT | Replace (full update) | ❌ | ✅ |
| PATCH | Partial update | ❌ | ❌ (can be) |
| DELETE | Delete | ❌ | ✅ |

---

## Versioning

**URI versioning** (recommended for public/inter-service APIs):
```
GET /api/v1/orders
GET /api/v2/orders
```

```java
@RestController
@RequestMapping("/api/v1/orders")
public class OrderControllerV1 { ... }
```

Header versioning (`API-Version: 2`) for internal APIs where URL cleanliness is prioritized.

---

## Pagination

### Offset (simple, for small datasets)
```
GET /orders?page=0&size=20
```
```json
{
  "content": [...],
  "page": { "size": 20, "number": 0, "totalElements": 500, "totalPages": 25 }
}
```

### Cursor (recommended for large datasets / infinite scroll)
```
GET /orders?limit=20&after=eyJpZCI6MTAwfQ==
```
```json
{
  "data": [...],
  "pagination": { "limit": 20, "hasNextPage": true, "nextCursor": "eyJpZCI6MTIwfQ==" }
}
```

Cursor = base64-encoded last item ID/timestamp. Consistent results when data changes; efficient (no OFFSET).

Spring Boot `Page<T>` response:
```java
@GetMapping
public ResponseEntity<Page<OrderDto>> list(Pageable pageable) {
    return ResponseEntity.ok(orderService.findAll(pageable).map(orderMapper::toDto));
}
```

---

## Error Responses — RFC 7807 ProblemDetail

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

Spring Boot 3 implementation:
```java
@ExceptionHandler(OrderNotFoundException.class)
public ProblemDetail handleOrderNotFound(OrderNotFoundException ex) {
    var problem = ProblemDetail.forStatusAndDetail(HttpStatus.NOT_FOUND, ex.getMessage());
    problem.setType(URI.create("https://api.example.com/errors/order-not-found"));
    problem.setProperty("traceId", MDC.get("traceId"));
    return problem;
}
```

---

## HTTP Status Code Reference

| Code | When |
|---|---|
| 200 OK | Successful GET, PUT, PATCH |
| 201 Created | Successful POST creating a resource; include `Location` header |
| 204 No Content | Successful DELETE or action with no response body |
| 400 Bad Request | Malformed request syntax, invalid JSON |
| 401 Unauthorized | Missing or invalid authentication |
| 403 Forbidden | Authenticated but not authorized |
| 404 Not Found | Resource does not exist |
| 409 Conflict | Duplicate creation, optimistic lock failure |
| 422 Unprocessable Entity | Valid syntax, invalid business semantics |
| 500 Internal Server Error | Unexpected error — never expose stack traces |

---

## OpenAPI/Swagger (springdoc-openapi)

```xml
<dependency>
    <groupId>org.springdoc</groupId>
    <artifactId>springdoc-openapi-starter-webmvc-ui</artifactId>
    <version>2.3.0</version>
</dependency>
```

```java
@Operation(summary = "Create order", description = "Creates a new order. Returns 201 with Location header.")
@ApiResponses({
    @ApiResponse(responseCode = "201", description = "Order created"),
    @ApiResponse(responseCode = "422", description = "Validation failed",
        content = @Content(schema = @Schema(implementation = ProblemDetail.class)))
})
@PostMapping
public ResponseEntity<OrderResponse> create(@Valid @RequestBody CreateOrderRequest request) { ... }
```

---

## Idempotency for POST

Clients retry failed requests. Without idempotency, retries create duplicates.

```java
@PostMapping("/payments")
public ResponseEntity<PaymentResponse> processPayment(
    @RequestHeader("Idempotency-Key") UUID idempotencyKey,
    @Valid @RequestBody PaymentRequest request) {

    return paymentService.processIdempotent(idempotencyKey, request)
        .map(existing -> ResponseEntity.ok(existing))           // already processed
        .orElseGet(() -> {
            var result = paymentService.process(request);
            idempotencyStore.save(idempotencyKey, result);
            return ResponseEntity.status(201).body(result);
        });
}
```

---

## Rate Limiting (Spring Boot + Bucket4j)

```java
@Component
public class RateLimitingFilter extends OncePerRequestFilter {
    private final Map<String, Bucket> buckets = new ConcurrentHashMap<>();

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
        throws IOException, ServletException {
        var clientId = extractClientId(request);
        var bucket = buckets.computeIfAbsent(clientId, k ->
            Bucket.builder().addLimit(Bandwidth.classic(100, Refill.greedy(100, Duration.ofMinutes(1)))).build());

        if (bucket.tryConsume(1)) {
            chain.doFilter(request, response);
        } else {
            response.setStatus(429);
            response.getWriter().write("Rate limit exceeded");
        }
    }
}
```

Return `Retry-After` header with 429 responses.
