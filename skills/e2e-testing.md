---
name: e2e-testing
description: End-to-end testing patterns for Java/Spring Boot APIs. REST Assured, Testcontainers full-stack testing, Spring Cloud Contract for consumer-driven contracts, and WireMock for external service stubs.
tools: ["Read", "Write", "Bash", "Grep", "Glob"]
model: claude-sonnet-4-5
activation: ["e2e", "end to end", "rest assured", "contract test", "spring cloud contract", "wiremock", "api test"]
---

# E2E Testing

## Purpose

End-to-end and integration testing reference for Java/Spring Boot APIs. Covers REST Assured for HTTP-level testing, Testcontainers full-stack setups, Spring Cloud Contract for consumer-driven contracts, WireMock for external service stubs, test data management strategies, parallel test execution, and Gatling for load test baselines. Use this skill when designing or implementing API-level tests that span the full stack.

---

## REST Assured — Full API Test Setup

### Dependencies
```xml
<dependency>
    <groupId>io.rest-assured</groupId>
    <artifactId>rest-assured</artifactId>
    <scope>test</scope>
</dependency>
<dependency>
    <groupId>io.rest-assured</groupId>
    <artifactId>spring-mock-mvc</artifactId>
    <scope>test</scope>
</dependency>
```

### Base Test Class
```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
public abstract class ApiTestBase {

    @LocalServerPort
    protected int port;

    @BeforeEach
    void setUpRestAssured() {
        RestAssured.port = port;
        RestAssured.basePath = "/api/v1";
        RestAssured.requestSpecification = new RequestSpecBuilder()
            .setContentType(ContentType.JSON)
            .addHeader("Accept", "application/json")
            .build();
    }
}
```

### Request Spec Builders
```java
RequestSpecification authenticatedSpec(String token) {
    return new RequestSpecBuilder()
        .addHeader("Authorization", "Bearer " + token)
        .setContentType(ContentType.JSON)
        .build();
}
```

### Test Pattern
```java
class OrderApiTest extends ApiTestBase {

    @Test
    void shouldCreateOrderAndReturnLocation() {
        var requestBody = """
            {
              "customerId": "123e4567-e89b-12d3-a456-426614174000",
              "items": [{"productId": "prod-1", "quantity": 2}]
            }
            """;

        given()
            .spec(authenticatedSpec(validJwt))
            .body(requestBody)
        .when()
            .post("/orders")
        .then()
            .statusCode(201)
            .header("Location", matchesPattern(".*/orders/[a-f0-9-]{36}"))
            .body("id", notNullValue())
            .body("status", equalTo("PENDING"))
            .body("items", hasSize(1));
    }

    @Test
    void shouldReturn422WhenItemQuantityIsNegative() {
        given()
            .spec(authenticatedSpec(validJwt))
            .body("""{"customerId": "123e4567", "items": [{"productId": "p1", "quantity": -1}]}""")
        .when()
            .post("/orders")
        .then()
            .statusCode(422)
            .body("type", containsString("validation-error"))
            .body("violations[0].field", equalTo("items[0].quantity"));
    }
}
```

---

## Testcontainers Full Stack

### Singleton Container Pattern (Shared Across Tests)
```java
public abstract class ContainerizedTestBase {

    static final PostgreSQLContainer<?> POSTGRES =
        new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("testdb")
            .withUsername("test")
            .withPassword("test")
            .withReuse(true);  // Reuse container across test class reloads

    static final GenericContainer<?> REDIS =
        new GenericContainer<>("redis:7-alpine")
            .withExposedPorts(6379)
            .withReuse(true);

    static final KafkaContainer KAFKA =
        new KafkaContainer(DockerImageName.parse("confluentinc/cp-kafka:7.6.0"))
            .withReuse(true);

    static {
        POSTGRES.start();
        REDIS.start();
        KAFKA.start();
    }

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
        registry.add("spring.data.redis.host", REDIS::getHost);
        registry.add("spring.data.redis.port", () -> REDIS.getMappedPort(6379));
        registry.add("spring.kafka.bootstrap-servers", KAFKA::getBootstrapServers);
    }
}
```

### Usage
```java
@SpringBootTest(webEnvironment = RANDOM_PORT)
class OrderE2ETest extends ContainerizedTestBase {
    // Tests run against real PostgreSQL + Redis + Kafka
}
```

### Pitfalls
- `@Testcontainers` annotation on each class starts new containers per class. Use the static singleton pattern above to share containers across test classes.
- `withReuse(true)` requires `testcontainers.reuse.enable=true` in `~/.testcontainers.properties`.

---

## Spring Cloud Contract — Consumer-Driven Contracts

### Consumer Side — Write the Contract
File: `src/test/resources/contracts/orders/should_return_order_by_id.groovy`
```groovy
import org.springframework.cloud.contract.spec.Contract

Contract.make {
    description "Should return order by ID"
    request {
        method GET()
        url "/api/v1/orders/123e4567-e89b-12d3-a456-426614174000"
        headers { header('Authorization', matching('Bearer .*')) }
    }
    response {
        status 200
        headers { contentType(applicationJson()) }
        body([
            id: $(anyUuid()),
            status: "PENDING",
            customerId: "123e4567-e89b-12d3-a456-426614174000"
        ])
    }
}
```

### Producer Side — Verify Contracts
```java
@SpringBootTest(webEnvironment = RANDOM_PORT)
public abstract class ContractVerifierBase {

    @Autowired WebApplicationContext context;
    @MockBean OrderService orderService;

    @BeforeEach
    void setUp() {
        RestAssuredMockMvc.webAppContextSetup(context);

        given(orderService.findById(any())).willReturn(
            Order.builder().id(UUID.fromString("123e4567-e89b-12d3-a456-426614174000"))
                 .status(OrderStatus.PENDING).customerId(UUID.randomUUID()).build()
        );
    }
}
```

```yaml
# pom.xml plugin config
<plugin>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-contract-maven-plugin</artifactId>
    <configuration>
        <baseClassForTests>com.example.contracts.ContractVerifierBase</baseClassForTests>
    </configuration>
</plugin>
```

### Publishing Stubs for Consumers
```bash
mvn install  # installs stubs to local Maven repo
# Or publish to Artifactory/Nexus for shared consumption
```

---

## WireMock — External HTTP Service Stubs

### Setup
```java
@SpringBootTest(webEnvironment = RANDOM_PORT)
@AutoConfigureWireMock(port = 0)  // random port, injected via ${wiremock.server.port}
class PaymentGatewayIntegrationTest {

    @Autowired WireMockServer wireMockServer;

    @Test
    void shouldProcessPaymentSuccessfully() {
        wireMockServer.stubFor(post(urlEqualTo("/payments/charge"))
            .withHeader("Content-Type", equalTo("application/json"))
            .willReturn(aResponse()
                .withStatus(200)
                .withHeader("Content-Type", "application/json")
                .withBody("""{"transactionId": "txn-123", "status": "APPROVED"}""")));

        var result = paymentService.charge(new ChargeRequest("card-123", Money.of(99.99)));

        assertThat(result.getStatus()).isEqualTo(PaymentStatus.APPROVED);
        wireMockServer.verify(postRequestedFor(urlEqualTo("/payments/charge")));
    }

    @Test
    void shouldHandlePaymentGatewayTimeout() {
        wireMockServer.stubFor(post(urlEqualTo("/payments/charge"))
            .willReturn(aResponse()
                .withFixedDelay(5000)  // 5 second delay → triggers timeout
                .withStatus(200)));

        assertThatThrownBy(() -> paymentService.charge(new ChargeRequest(...)))
            .isInstanceOf(PaymentTimeoutException.class);
    }
}
```

### application-test.yml
```yaml
payment-gateway:
  base-url: http://localhost:${wiremock.server.port}
```

---

## Test Data Management

### `@Sql` Annotation
```java
@Test
@Sql("/test-data/orders.sql")
@Sql(scripts = "/test-data/cleanup.sql", executionPhase = AFTER_TEST_METHOD)
void shouldFindOrdersByStatus() { ... }
```

### `@Transactional` Rollback (Not for Integration Tests)
```java
@DataJpaTest
@Transactional  // rolls back after each test — fine for @DataJpaTest
class OrderRepositoryTest { ... }
```

**Warning:** Do NOT use `@Transactional` on `@SpringBootTest` tests. The transaction wraps the test but NOT the HTTP request, so the DB state is different for the tested code.

### TestEntityManager for Setup
```java
@Autowired TestEntityManager entityManager;

@BeforeEach
void setUp() {
    entityManager.persist(OrderBuilder.anOrder().withStatus(PENDING).build());
    entityManager.flush();
    entityManager.clear();  // Detach all to force DB reads in the test
}
```

### Explicit Cleanup Pattern
```java
@AfterEach
void cleanUp() {
    orderRepository.deleteAll();
    outboxRepository.deleteAll();
}
```

---

## Parallel Test Execution

### JUnit 5 Config
```properties
# src/test/resources/junit-platform.properties
junit.jupiter.execution.parallel.enabled=true
junit.jupiter.execution.parallel.mode.default=concurrent
junit.jupiter.execution.parallel.config.strategy=dynamic
junit.jupiter.execution.parallel.config.dynamic.factor=2
```

### Thread-Safe Singleton Containers
The static singleton Testcontainers pattern (from above) is inherently thread-safe because containers are started once in the static initializer block before any test thread executes.

### Isolation Requirements for Parallel Execution
- Each test class must set up its own test data and clean up after itself.
- Do NOT rely on ordering between test classes.
- Use random IDs in test data to avoid conflicts: `UUID.randomUUID()`.

---

## E2E vs Integration — When to Use What

| Test Type | Annotation | Use When |
|---|---|---|
| Unit | `@ExtendWith(MockitoExtension)` | Single class, no Spring |
| Slice: Controller | `@WebMvcTest` | HTTP mapping, validation, error handling |
| Slice: Repository | `@DataJpaTest` | Query methods, entity mapping |
| Integration | `@SpringBootTest(RANDOM_PORT)` + Testcontainers | Full stack, cross-cutting, DB migrations |
| E2E | `@SpringBootTest` + REST Assured + all infra | Business scenario validation end-to-end |
| Contract | Spring Cloud Contract | Cross-service API compatibility |

**Rule:** Prefer the narrowest test type. Use full `@SpringBootTest` only when slices cannot cover the scenario.

---

## Performance Tests — Gatling + Spring Boot

### Simulation Baseline
```scala
class OrderApiSimulation extends Simulation {

  val httpProtocol = http
    .baseUrl("http://localhost:8080")
    .acceptHeader("application/json")
    .contentTypeHeader("application/json")
    .header("Authorization", "Bearer " + validJwt)

  val createOrderScenario = scenario("Create Order")
    .exec(http("POST /orders")
      .post("/api/v1/orders")
      .body(StringBody("""{"customerId": "#{customerId}", "items": [...]}"""))
      .check(status.is(201)))

  setUp(
    createOrderScenario.inject(
      rampUsers(100).during(60.seconds),   // Ramp to 100 concurrent users over 60s
      constantUsersPerSec(50).during(120.seconds)  // Sustain 50 RPS for 2 min
    )
  ).protocols(httpProtocol)
   .assertions(
     global.responseTime.percentile(99).lt(500),  // P99 < 500ms
     global.failedRequests.percent.lt(1)           // < 1% errors
   )
}
```

---

## Contract Versioning — Evolving Without Breaking Consumers

### Additive Changes (Safe)
- Adding new optional fields to response
- Adding new endpoints
- Adding new optional query parameters

### Breaking Changes (Require Version Negotiation)
- Removing fields from response
- Changing field types
- Changing HTTP status codes
- Removing endpoints

### Strategy for Breaking Changes
1. Publish new contract version to stub repository
2. Notify consumers with migration window
3. Maintain old and new contract simultaneously during transition
4. Deprecate old contract after all consumers migrated

---

## Standalone Invocation (No Orchestrator)

This agent can be invoked directly without the orchestrator. When `.copilot-runtime/artifacts/context.json` is absent, three options are available:

**Option 1 — Run Diagnostic Commands Directly**
Execute targeted commands to gather context on the fly:
- `find src/test -name "*.java" | xargs grep -l "SpringBootTest\|RestAssured\|WireMock" 2>/dev/null | head -10`
- `grep -r "testcontainers\|rest-assured\|spring-cloud-contract" pom.xml`
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
