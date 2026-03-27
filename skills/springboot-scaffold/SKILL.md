---
name: springboot-scaffold
description: >
  Load when creating a new REST endpoint from scratch (Controller + Service + Repository +
  DTOs + unit test + integration test), scaffolding a new domain aggregate (Entity + Value
  Objects + Repository + Service), adding a new Kafka consumer with DLT handler and
  idempotency guard, creating a scheduled background job with distributed lock, or when asked
  "how do I create a new endpoint", "show me the full structure for a new feature",
  "scaffold a new entity", "how do I add a Kafka consumer", "what's the boilerplate for
  a Spring Boot REST endpoint".
---

# Spring Boot Scaffold

Ready-to-use recipes for common Spring Boot patterns. Copy, rename types, and fill in business logic.

---

## Recipe 1 — REST Endpoint Slice

Complete vertical slice for one resource: `Order`.

### 1. Request/Response DTOs

```java
// src/main/java/com/example/orders/api/dto/CreateOrderRequest.java
public record CreateOrderRequest(
    @NotBlank String customerId,
    @NotEmpty @Valid List<OrderItemRequest> items
) {}

public record OrderItemRequest(
    @NotBlank String productId,
    @Min(1) int quantity
) {}

// Response DTO — never expose JPA entity directly
public record OrderResponse(
    String id,
    String customerId,
    String status,
    BigDecimal totalAmount,
    Instant createdAt
) {
    public static OrderResponse from(Order order) {
        return new OrderResponse(
            order.getId().toString(),
            order.getCustomerId(),
            order.getStatus().name(),
            order.getTotalAmount(),
            order.getCreatedAt()
        );
    }
}
```

### 2. Controller

```java
// src/main/java/com/example/orders/api/OrderController.java
@RestController
@RequestMapping("/api/v1/orders")
@RequiredArgsConstructor
public class OrderController {

    private final OrderService orderService;

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public OrderResponse createOrder(@Valid @RequestBody CreateOrderRequest request) {
        return OrderResponse.from(orderService.createOrder(request));
    }

    @GetMapping("/{id}")
    public OrderResponse getOrder(@PathVariable UUID id) {
        return OrderResponse.from(orderService.getOrder(id));
    }

    @GetMapping
    public Page<OrderResponse> listOrders(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return orderService.listOrders(PageRequest.of(page, size))
                .map(OrderResponse::from);
    }
}
```

### 3. Service

```java
// src/main/java/com/example/orders/service/OrderService.java
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)   // read-only default; override for writes
public class OrderService {

    private final OrderRepository orderRepository;

    @Transactional
    public Order createOrder(CreateOrderRequest request) {
        Order order = Order.create(request.customerId(), request.items());
        return orderRepository.save(order);
    }

    public Order getOrder(UUID id) {
        return orderRepository.findById(id)
                .orElseThrow(() -> new OrderNotFoundException(id));
    }

    public Page<Order> listOrders(Pageable pageable) {
        return orderRepository.findAll(pageable);
    }
}
```

### 4. Repository

```java
// src/main/java/com/example/orders/repository/OrderRepository.java
public interface OrderRepository extends JpaRepository<Order, UUID> {

    Page<Order> findByCustomerId(String customerId, Pageable pageable);

    // Use projection for list views — avoids loading all fields
    Page<OrderSummary> findAllProjectedBy(Pageable pageable);
}

// Projection — only load what the list view needs
public interface OrderSummary {
    UUID getId();
    String getStatus();
    BigDecimal getTotalAmount();
    Instant getCreatedAt();
}
```

### 5. Unit Test

```java
// src/test/java/com/example/orders/service/OrderServiceTest.java
@ExtendWith(MockitoExtension.class)
class OrderServiceTest {

    @Mock OrderRepository orderRepository;
    @InjectMocks OrderService orderService;

    @Test
    void createOrder_givenValidRequest_savesAndReturnsOrder() {
        // Arrange
        var request = new CreateOrderRequest("cust-1", List.of(new OrderItemRequest("prod-1", 2)));
        var savedOrder = Order.create(request.customerId(), request.items());
        when(orderRepository.save(any(Order.class))).thenReturn(savedOrder);

        // Act
        var result = orderService.createOrder(request);

        // Assert
        assertThat(result.getCustomerId()).isEqualTo("cust-1");
        verify(orderRepository).save(any(Order.class));
    }

    @Test
    void getOrder_givenUnknownId_throwsOrderNotFoundException() {
        // Arrange
        var unknownId = UUID.randomUUID();
        when(orderRepository.findById(unknownId)).thenReturn(Optional.empty());

        // Act / Assert
        assertThatThrownBy(() -> orderService.getOrder(unknownId))
            .isInstanceOf(OrderNotFoundException.class);
    }
}
```

### 6. Integration Test

```java
// src/test/java/com/example/orders/api/OrderControllerIT.java
@SpringBootTest(webEnvironment = RANDOM_PORT)
@AutoConfigureTestDatabase(replace = NONE)  // use real DB (Testcontainers)
class OrderControllerIT {

    @Autowired TestRestTemplate restTemplate;
    @Autowired OrderRepository orderRepository;

    @BeforeEach
    void setUp() { orderRepository.deleteAll(); }

    @Test
    void createOrder_returns201WithOrderId() {
        var request = new CreateOrderRequest("cust-1", List.of(new OrderItemRequest("prod-1", 2)));

        var response = restTemplate.postForEntity("/api/v1/orders", request, OrderResponse.class);

        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
        assertThat(response.getBody()).isNotNull();
        assertThat(response.getBody().id()).isNotNull();
    }
}
```

---

## Recipe 2 — Kafka Consumer with DLT + Idempotency

```java
@Component
@RequiredArgsConstructor
@Slf4j
public class OrderCreatedConsumer {

    private final OrderService orderService;
    private final ProcessedEventRepository processedEventRepository;

    @KafkaListener(topics = "order-created", groupId = "order-processor")
    public void handle(
            @Payload OrderCreatedEvent event,
            @Header(KafkaHeaders.RECEIVED_KEY) String key) {

        // Idempotency guard — check BEFORE processing
        if (processedEventRepository.existsByEventId(event.eventId())) {
            log.info("Duplicate event skipped: eventId={}", event.eventId());
            return;
        }

        log.info("Processing event: eventId={}, orderId={}", event.eventId(), event.orderId());

        orderService.processOrderCreated(event);

        // Mark as processed in the same transaction as the business operation
        processedEventRepository.save(new ProcessedEvent(event.eventId()));
    }

    @DltHandler
    public void handleDlt(OrderCreatedEvent event, Exception cause) {
        log.error("DLT received: eventId={}, reason={}", event.eventId(), cause.getMessage(), cause);
        // Alert or store for manual review — do NOT re-throw unless you want infinite DLT loop
    }
}
```

```yaml
# application.yml — retry config for consumer
spring:
  kafka:
    listener:
      ack-mode: RECORD
    consumer:
      auto-offset-reset: earliest
    retry:
      topic:
        enabled: true
        attempts: 3
        delay: 1000
        multiplier: 2
        max-delay: 10000
```

---

## Recipe 3 — Scheduled Job with Distributed Lock

```java
@Component
@RequiredArgsConstructor
@Slf4j
public class ExpiredOrderCleanupJob {

    private final OrderRepository orderRepository;
    private final LockRegistry lockRegistry;  // Spring Integration LockRegistry (Redis-backed)

    @Scheduled(cron = "0 0 2 * * *")  // 2am daily
    public void cleanupExpiredOrders() {
        Lock lock = lockRegistry.obtain("expired-order-cleanup");

        if (!lock.tryLock()) {
            log.debug("Cleanup job skipped — another instance holds the lock");
            return;
        }

        try {
            log.info("Starting expired order cleanup");
            int deleted = orderRepository.deleteExpiredOrders(Instant.now().minus(30, DAYS));
            log.info("Expired order cleanup complete: deleted={}", deleted);
        } catch (Exception e) {
            log.error("Expired order cleanup failed", e);
        } finally {
            lock.unlock();
        }
    }
}
```

```java
// Repository method with bulk delete
public interface OrderRepository extends JpaRepository<Order, UUID> {

    @Modifying
    @Query("DELETE FROM Order o WHERE o.status = 'EXPIRED' AND o.createdAt < :cutoff")
    int deleteExpiredOrders(Instant cutoff);
}
```

---

## Recipe 4 — Domain Aggregate

```java
// Entity — owns lifecycle, enforces invariants
@Entity
@Table(name = "orders")
@NoArgsConstructor(access = AccessLevel.PROTECTED)  // JPA requires no-arg, protect from misuse
public class Order {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @Column(nullable = false)
    private String customerId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private OrderStatus status;

    @OneToMany(cascade = CascadeType.PERSIST, fetch = FetchType.LAZY, orphanRemoval = true)
    @JoinColumn(name = "order_id")
    private List<OrderItem> items = new ArrayList<>();

    @Column(nullable = false, updatable = false)
    private Instant createdAt;

    // Factory method — enforces creation invariants
    public static Order create(String customerId, List<OrderItemRequest> requestItems) {
        Objects.requireNonNull(customerId, "customerId is required");
        if (requestItems == null || requestItems.isEmpty()) {
            throw new IllegalArgumentException("Order must have at least one item");
        }

        var order = new Order();
        order.customerId = customerId;
        order.status = OrderStatus.PENDING;
        order.createdAt = Instant.now();
        requestItems.forEach(r -> order.items.add(OrderItem.of(r.productId(), r.quantity())));
        return order;
    }

    // Domain operation — validates state transition
    public void cancel() {
        if (this.status == OrderStatus.SHIPPED || this.status == OrderStatus.DELIVERED) {
            throw new OrderCannotBeCancelledException(this.id, this.status);
        }
        this.status = OrderStatus.CANCELLED;
    }

    // Computed value — not persisted
    public BigDecimal getTotalAmount() {
        return items.stream()
                .map(item -> item.getUnitPrice().multiply(BigDecimal.valueOf(item.getQuantity())))
                .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    // Read-only getters only — no public setters
    public UUID getId() { return id; }
    public String getCustomerId() { return customerId; }
    public OrderStatus getStatus() { return status; }
    public List<OrderItem> getItems() { return Collections.unmodifiableList(items); }
    public Instant getCreatedAt() { return createdAt; }
}
```

---

## Checklist for Each Recipe

Before committing scaffolded code:

- [ ] Request DTOs have `@Valid` + Bean Validation annotations
- [ ] Response DTOs are records, not JPA entities
- [ ] Controller delegates to service — zero business logic
- [ ] Service has `@Transactional(readOnly = true)` at class level, `@Transactional` on writes
- [ ] Repository uses projections for list endpoints
- [ ] Unit test covers happy path + main failure case
- [ ] Integration test covers HTTP contract (status code + response shape)
- [ ] Exception has a meaningful message with relevant IDs
