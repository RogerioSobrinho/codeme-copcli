---
name: springboot-tdd
description: TDD workflow guide for Spring Boot. Covers JUnit 5, Mockito, @WebMvcTest/@DataJpaTest slices, Testcontainers, MockMvc, Spring Cloud Contract. Load when writing tests or practicing TDD in Spring Boot projects.
---

# Spring Boot TDD

## TDD Cycle — Red → Green → Refactor

1. **Red** — Write a failing test that expresses the requirement. Run it. Confirm it fails with an assertion error (not a compile error).
2. **Green** — Write the minimal implementation to make the test pass. Nothing more.
3. **Refactor** — Clean up duplication and improve design. Re-run the test after every change.

**Spring Boot specifics:** Keep the Spring context out of unit tests. Use `@ExtendWith(MockitoExtension.class)` for domain and service logic. Use test slices (`@WebMvcTest`, `@DataJpaTest`) for bounded context loading. Reserve `@SpringBootTest` for true integration tests.

---

## Test Slices — When to Use Each

| Slice | Loads | Use When |
|---|---|---|
| `@WebMvcTest` | Web layer only (Controllers, Filters, `@ControllerAdvice`) | Testing HTTP mapping, validation, error handling |
| `@DataJpaTest` | JPA layer only (repositories, entity manager) | Testing queries, entity mappings, custom repository methods |
| `@JsonTest` | Jackson ObjectMapper only | Testing DTO serialization/deserialization |
| `@RestClientTest` | `RestTemplate`/`WebClient` beans only | Testing HTTP client code against a mock server |

---

## Unit Tests — Domain Logic

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

Use `BDDMockito.given/willReturn`, not `Mockito.when/thenReturn`. Never use `@SpringBootTest` for unit tests.

---

## Controller Tests — @WebMvcTest

```java
@WebMvcTest(OrderController.class)
class OrderControllerTest {

    @Autowired MockMvc mockMvc;
    @MockBean OrderService orderService;  // @MockBean, not @Mock — requires Spring context

    @Test
    void shouldReturn201WhenOrderCreated() throws Exception {
        given(orderService.create(any())).willReturn(OrderBuilder.anOrder().build());

        mockMvc.perform(post("/orders")
                .contentType(APPLICATION_JSON)
                .content("""{"customerId": "123", "items": []}"""))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.id").isNotEmpty());
    }

    @Test
    void shouldReturn400WhenCustomerIdMissing() throws Exception {
        mockMvc.perform(post("/orders").contentType(APPLICATION_JSON).content("""{"items": []}"""))
            .andExpect(status().isBadRequest())
            .andExpect(jsonPath("$.detail").exists());
    }
}
```

---

## Repository Tests — @DataJpaTest

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

Use Testcontainers PostgreSQL, not H2 — H2 dialect differences hide real bugs.

---

## Integration Tests — @SpringBootTest + Testcontainers

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

---

## Test Data Builders

Never use shared static constants. Builders produce fresh, isolated objects per test.

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

---

## Common Anti-patterns

| Anti-pattern | Problem | Fix |
|---|---|---|
| Testing implementation details | Test breaks on refactor without behavior change | Assert on output/side-effects, not internal calls |
| Over-mocking | All collaborators mocked → test proves nothing | Mock only external boundaries (DB, HTTP, MQ) |
| Missing edge cases | Only happy path covered | Always add: null input, empty collection, boundary values |
| `@SpringBootTest` for unit tests | Slow feedback loop | Use `@ExtendWith(MockitoExtension.class)` |
| Shared mutable test state | Tests interfere with each other | Use builders; `@BeforeEach` to reset state |

---

## Spring Cloud Contract Basics

```groovy
// src/test/resources/contracts/create-order.groovy
Contract.make {
    request { method POST(); url '/orders'; body([customerId: '123']) }
    response { status 201; body([id: $(anyUuid())]) }
}
```

Producer verification: generated tests run against the real implementation. Consumer side: stubs are published for consumers to test against without hitting the real service.
