# Java Testing

## Test Framework Stack

- **JUnit 5** — `@Test`, `@ParameterizedTest`, `@Nested`, `@DisplayName`
- **AssertJ** — fluent assertions: `assertThat(result).isEqualTo(expected)`
- **Mockito** — `@ExtendWith(MockitoExtension.class)` for unit tests
- **Testcontainers** — real DB/Kafka for integration tests
- **Awaitility** — async assertions (never `Thread.sleep()`)

## Unit Test Pattern

```java
@ExtendWith(MockitoExtension.class)
class OrderServiceTest {

    @Mock private OrderRepository orderRepository;
    private OrderService orderService;

    @BeforeEach
    void setUp() { orderService = new OrderService(orderRepository); }

    @Test
    @DisplayName("findById returns order when it exists")
    void findById_existingOrder_returnsOrder() {
        var order = new Order(1L, "Alice", BigDecimal.TEN);
        when(orderRepository.findById(1L)).thenReturn(Optional.of(order));

        var result = orderService.findById(1L);

        assertThat(result.customerName()).isEqualTo("Alice");
        verify(orderRepository).findById(1L);
    }
}
```

## Test Naming Convention

- Method names: `methodName_givenContext_expectedBehavior`
- `@DisplayName`: human-readable sentence for reports
- Never use `@SpringBootTest` for unit tests — use `@ExtendWith(MockitoExtension.class)`

## Integration Tests

Use `@SpringBootTest` + Testcontainers for real database/Kafka integration:

```java
@Testcontainers
class OrderRepositoryIT {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16");

    @Test
    void save_and_findById() { /* ... */ }
}
```

## Spring Web Layer Tests

Use `@WebMvcTest` + `MockMvc` to test controllers in isolation:

```java
@WebMvcTest(OrderController.class)
class OrderControllerTest {

    @Autowired MockMvc mockMvc;
    @MockBean OrderService orderService;

    @Test
    void getOrder_returnsOk() throws Exception {
        when(orderService.findById(1L)).thenReturn(new OrderResponse(1L, "Alice", BigDecimal.TEN));
        mockMvc.perform(get("/api/orders/1"))
               .andExpect(status().isOk())
               .andExpect(jsonPath("$.data.customerName").value("Alice"));
    }
}
```

## Coverage

- Target 80%+ line coverage via JaCoCo
- Focus on service and domain logic — skip trivial getters and Spring config classes
