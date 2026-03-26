---
name: springboot-tdd
description: TDD workflow guide for Java/Spring Boot projects. Covers JUnit 5, Mockito, Testcontainers, and Spring Boot Test slices for writing tests first and driving implementation from failing tests.
tools: ["Read", "Write", "Bash", "Grep", "Glob"]
model: claude-sonnet-4-5
activation: ["tdd", "test driven", "write test first", "spring boot test", "junit"]
---

# Spring Boot TDD

## Purpose

Guides the Red → Green → Refactor TDD cycle within Java/Spring Boot projects. Covers the full test pyramid: unit tests for domain logic, service layer tests with mocks, repository tests with `@DataJpaTest`, controller tests with `@WebMvcTest`, and full integration tests with Testcontainers. Each layer uses the narrowest possible Spring context to keep the feedback loop fast.

---

## TDD Cycle — Red → Green → Refactor

### The Rule
Write the failing test FIRST. Never write implementation without a failing test.

### Steps
1. **Red** — Write a test that expresses the requirement. Run it. Confirm it fails for the right reason (not a compile error, but an assertion failure).
2. **Green** — Write the minimal implementation to make the test pass. No more, no less.
3. **Refactor** — Clean up duplication and improve design. Re-run the test after every change.

### Spring Boot Specifics
- Keep the Spring context out of unit tests. Pure JUnit 5 + Mockito for domain logic.
- Use test slices (`@WebMvcTest`, `@DataJpaTest`) to load only the required beans.
- Reserve `@SpringBootTest` for true integration tests that need the full application context.

### Pitfalls
- Writing too much implementation before running the test ("going dark").
- Writing tests after the fact defeats TDD's design feedback benefit.
- Skipping the Refactor step accumulates technical debt.

---

## Test Slices — When to Use Each

| Slice | Loads | Use When |
|---|---|---|
| `@WebMvcTest` | Web layer only (Controllers, Filters, `@ControllerAdvice`) | Testing HTTP request/response mapping, validation, error handling |
| `@DataJpaTest` | JPA layer only (repositories, entity manager, H2 or Testcontainers) | Testing queries, entity mappings, custom repository methods |
| `@JsonTest` | Jackson ObjectMapper only | Testing serialization/deserialization of DTOs |
| `@RestClientTest` | `RestTemplate`/`WebClient` beans only | Testing HTTP client code against a mock server |

**Rule:** Use the narrowest slice that exercises the code under test.

---

## Unit Tests — Pure Domain Logic

No Spring context. No mocks of Spring infrastructure. Test the domain model in isolation.

### When to Use
- Domain entities with business logic
- Value objects and domain services
- Pure calculation/validation logic

### Pattern
```java
// Arrange
var order = new Order(customerId, items);

// Act
var total = order.calculateTotal();

// Assert
assertThat(total).isEqualByComparingTo(new BigDecimal("99.90"));
```

### JUnit 5 + Mockito Setup
```java
@ExtendWith(MockitoExtension.class)
class OrderServiceTest {

    @Mock
    private OrderRepository orderRepository;

    @InjectMocks
    private OrderService orderService;

    @Test
    void shouldThrowWhenOrderNotFound() {
        given(orderRepository.findById(any())).willReturn(Optional.empty());

        assertThatThrownBy(() -> orderService.findOrder(UUID.randomUUID()))
            .isInstanceOf(OrderNotFoundException.class);
    }
}
```

### Pitfalls
- Do NOT use `@SpringBootTest` here — it loads the entire context unnecessarily.
- Prefer `BDDMockito.given/willReturn` over `Mockito.when/thenReturn` for readability.

---

## Service Layer Tests — Mocking Repositories

Use `@ExtendWith(MockitoExtension.class)` only. No Spring context.

### When to Use
- Service methods that orchestrate repository calls
- Testing business rules that depend on repository results
- Error path testing (entity not found, duplicate key, etc.)

### Pattern
```java
@ExtendWith(MockitoExtension.class)
class PaymentServiceTest {

    @Mock PaymentRepository paymentRepository;
    @Mock EventPublisher eventPublisher;
    @InjectMocks PaymentService paymentService;

    @Test
    void shouldPublishEventOnSuccessfulPayment() {
        var payment = PaymentBuilder.aPayment().approved().build();
        given(paymentRepository.save(any())).willReturn(payment);

        paymentService.process(payment);

        then(eventPublisher).should().publish(any(PaymentApprovedEvent.class));
    }
}
```

### Pitfalls
- Do NOT use `@MockBean` here — that requires a Spring context. Use `@Mock`.
- Verify interactions only when the interaction itself is the behavior under test.

---

## Repository Tests — `@DataJpaTest`

### When to Use
- Custom `@Query` methods
- Derived query methods with complex predicates
- Entity relationship mapping validation
- Optimistic locking behavior

### Pattern with H2
```java
@DataJpaTest
class ProductRepositoryTest {

    @Autowired ProductRepository productRepository;
    @Autowired TestEntityManager entityManager;

    @Test
    void shouldFindActiveProductsByCategory() {
        entityManager.persist(ProductBuilder.aProduct().active().inCategory("electronics").build());
        entityManager.flush();

        var results = productRepository.findActiveByCategoryName("electronics");

        assertThat(results).hasSize(1);
    }
}
```

### Pattern with Testcontainers PostgreSQL
```java
@DataJpaTest
@AutoConfigureTestDatabase(replace = NONE)
@Testcontainers
class ProductRepositoryTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }
    // ...
}
```

### Pitfalls
- H2 dialect differences hide PostgreSQL-specific query bugs. Use Testcontainers for production parity.
- `TestEntityManager.flush()` is required to write to the DB before querying.

---

## Controller Tests — `@WebMvcTest` with MockMvc

### When to Use
- HTTP status codes, response body structure
- Request validation (`@Valid`, `@RequestBody`)
- `@ControllerAdvice` error handling
- Security filter chain behavior

### Pattern
```java
@WebMvcTest(OrderController.class)
class OrderControllerTest {

    @Autowired MockMvc mockMvc;
    @MockBean OrderService orderService;

    @Test
    void shouldReturn201WhenOrderCreated() throws Exception {
        var order = OrderBuilder.anOrder().build();
        given(orderService.create(any())).willReturn(order);

        mockMvc.perform(post("/orders")
                .contentType(APPLICATION_JSON)
                .content("""{"customerId": "123", "items": []}"""))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.id").isNotEmpty());
    }

    @Test
    void shouldReturn400WhenCustomerIdMissing() throws Exception {
        mockMvc.perform(post("/orders")
                .contentType(APPLICATION_JSON)
                .content("""{"items": []}"""))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.detail").exists());
    }
}
```

### Pitfalls
- `@MockBean` is required for service dependencies (not `@Mock`).
- Do NOT test service logic through the controller test — mock the service.

---

## Integration Tests — `@SpringBootTest` + Testcontainers

### When to Use
- Full request-to-database flows
- Cross-cutting concerns (transactions, security filters, events)
- Smoke tests that verify the application starts

### Pattern
```java
@SpringBootTest(webEnvironment = RANDOM_PORT)
@Testcontainers
class OrderIntegrationTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired TestRestTemplate restTemplate;

    @Test
    void shouldCreateOrderEndToEnd() {
        var response = restTemplate.postForEntity("/orders", new CreateOrderRequest(...), OrderResponse.class);
        assertThat(response.getStatusCode()).isEqualTo(HttpStatus.CREATED);
    }
}
```

### Pitfalls
- Integration tests are slow. Use them sparingly — prefer slices for most scenarios.
- Use `@DirtiesContext` only when absolutely necessary; it destroys and recreates the context.

---

## Contract Tests — Spring Cloud Contract Basics

### When to Use
- APIs consumed by other services
- Preventing producer-side changes from breaking consumers

### Consumer Side
Define the contract in Groovy/YAML under `src/test/resources/contracts/`:
```groovy
Contract.make {
    request { method POST(); url '/orders'; body([customerId: '123']) }
    response { status 201; body([id: $(anyUuid())]) }
}
```

### Producer Side Verification
```java
@SpringBootTest(webEnvironment = RANDOM_PORT)
class OrderContractTest extends ContractVerifierBase {
    // Generated tests verify the contract against the real producer
}
```

### Pitfalls
- Contracts must be versioned alongside the API. Breaking a contract is a breaking change.
- Do NOT use `@SpringBootTest` with a full DB in contract tests — stub the service layer.

---

## Test Data Builders — Builder Pattern

### Why Not Static Constants
Static final test fixtures are shared across tests and mutate silently. Builders produce fresh, isolated objects per test.

### Pattern
```java
public class OrderBuilder {
    private UUID customerId = UUID.randomUUID();
    private List<OrderItem> items = List.of(OrderItemBuilder.anItem().build());
    private OrderStatus status = OrderStatus.PENDING;

    public static OrderBuilder anOrder() { return new OrderBuilder(); }

    public OrderBuilder withCustomer(UUID customerId) {
        this.customerId = customerId; return this;
    }

    public OrderBuilder approved() {
        this.status = OrderStatus.APPROVED; return this;
    }

    public Order build() {
        return new Order(customerId, items, status);
    }
}
```

### Pitfalls
- Do NOT share builder instances across tests.
- Keep builders in `src/test/java` — never in production code.

---

## Common Anti-patterns

| Anti-pattern | Problem | Fix |
|---|---|---|
| Testing implementation details | Test breaks on refactor without behavior change | Assert on output/side-effects, not internal calls |
| Over-mocking | All collaborators mocked → test proves nothing | Mock only external boundaries (DB, HTTP, MQ) |
| Missing edge cases | Only happy path covered | Always add: null input, empty collection, boundary values |
| `@SpringBootTest` for unit tests | Slow feedback loop | Use `@ExtendWith(MockitoExtension.class)` |
| Shared mutable test state | Tests interfere with each other | Use builders; `@BeforeEach` to reset state |
| Assertions on `toString()` | Fragile; breaks on format change | Use typed assertions (`assertThat(obj.getField())`) |

---

## Standalone Invocation (No Orchestrator)

This agent can be invoked directly without the orchestrator. When `.copilot-runtime/artifacts/context.json` is absent, three options are available:

**Option 1 — Run Diagnostic Commands Directly**
Execute targeted commands to gather context on the fly:
- `find src/test -name "*Test.java" | head -20` — discover existing test structure
- `mvn dependency:tree | grep -E "junit|mockito|testcontainers"` — check test dependencies
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
