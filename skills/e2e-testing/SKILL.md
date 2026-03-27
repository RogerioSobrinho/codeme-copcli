---
name: e2e-testing
description: >
  Load when writing @SpringBootTest end-to-end tests using REST Assured (given().when().then()
  fluent API), managing Testcontainers lifecycle with singleton pattern (@Container static
  field), stubbing external HTTP services with WireMock (@AutoConfigureWireMock), writing
  consumer-driven Spring Cloud Contracts (.groovy or .yml), running Gatling load simulations,
  or diagnosing port-binding conflicts and context reload overhead in integration test suites.
---

# E2E Testing

## REST Assured Base Class

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Testcontainers
public abstract class AbstractIntegrationTest {

    @LocalServerPort
    private int port;

    @BeforeEach
    void setupRestAssured() {
        RestAssured.baseURI = "http://localhost";
        RestAssured.port = port;
        RestAssured.filters(new RequestLoggingFilter(), new ResponseLoggingFilter());
    }
}
```

```java
class OrderApiTest extends AbstractIntegrationTest {

    @Test
    void createOrder_returns201WithLocation() {
        given()
            .contentType(ContentType.JSON)
            .body(new CreateOrderRequest("CUSTOMER-1", List.of(new LineItem("PROD-1", 2))))
        .when()
            .post("/api/v1/orders")
        .then()
            .statusCode(201)
            .header("Location", matchesPattern(".*/orders/[a-f0-9-]+"))
            .body("status", equalTo("PENDING"))
            .body("lineItems", hasSize(1));
    }
}
```

---

## Testcontainers — Singleton Pattern

Reuse containers across all tests in a test run. Each `@Container` on a class starts/stops per test class, which is slow.

```java
// Singleton: start once, share across all tests
public abstract class AbstractIntegrationTest {

    static final PostgreSQLContainer<?> POSTGRES;
    static final GenericContainer<?> REDIS;

    static {
        POSTGRES = new PostgreSQLContainer<>("postgres:16-alpine")
            .withReuse(true);  // requires ~/.testcontainers.properties: testcontainers.reuse.enable=true
        REDIS = new GenericContainer<>("redis:7-alpine")
            .withExposedPorts(6379)
            .withReuse(true);

        POSTGRES.start();
        REDIS.start();
    }

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
        registry.add("spring.data.redis.host", REDIS::getHost);
        registry.add("spring.data.redis.port", () -> REDIS.getMappedPort(6379));
    }
}
```

Enable reuse in `~/.testcontainers.properties`:
```properties
testcontainers.reuse.enable=true
```

---

## WireMock — External Service Stubs

```java
@SpringBootTest
@AutoConfigureWireMock(port = 0)  // random port, registered in WireMockServer
class PaymentGatewayIntegrationTest extends AbstractIntegrationTest {

    @Autowired
    WireMockServer wireMockServer;

    @BeforeEach
    void stubPaymentGateway() {
        wireMockServer.stubFor(
            post(urlEqualTo("/payments"))
                .withRequestBody(matchingJsonPath("$.amount"))
                .willReturn(aResponse()
                    .withStatus(200)
                    .withHeader("Content-Type", "application/json")
                    .withBody("""
                        {"transactionId": "TXN-123", "status": "APPROVED"}
                        """))
        );
    }

    @Test
    void processPayment_callsGatewayAndPersistsResult() {
        // Act
        given().contentType(ContentType.JSON)
            .body(new ProcessPaymentRequest("ORDER-1", BigDecimal.valueOf(99.99)))
            .post("/api/v1/payments")
            .then().statusCode(200).body("status", equalTo("APPROVED"));

        // Assert gateway was called
        wireMockServer.verify(postRequestedFor(urlEqualTo("/payments")));
    }
}
```

WireMock `@AutoConfigureWireMock` binds the port to `wiremock.server.port` property, which can override `@FeignClient` or `RestClient` URLs via `@DynamicPropertySource`.

---

## Spring Cloud Contract — Consumer-Driven Contract Testing

Define the contract in the **producer** service:

```groovy
// src/test/resources/contracts/shouldReturnOrderById.groovy
Contract.make {
    request {
        method 'GET'
        url '/api/v1/orders/ORDER-1'
    }
    response {
        status 200
        body([id: 'ORDER-1', status: 'PENDING', totalAmount: 99.99])
        headers { contentType(applicationJson()) }
    }
}
```

Producer generates stub JAR; **consumer** imports it:
```java
@SpringBootTest
@AutoConfigureStubRunner(
    ids = "com.example:order-service:+:stubs:8090",
    stubsMode = StubRunnerProperties.StubsMode.LOCAL)
class OrderServiceConsumerTest {
    @Test
    void fetchOrder_returnsExpectedStructure() { ... }
}
```

---

## Parallel Test Execution (JUnit 5)

`src/test/resources/junit-platform.properties`:
```properties
junit.jupiter.execution.parallel.enabled=true
junit.jupiter.execution.parallel.mode.default=concurrent
junit.jupiter.execution.parallel.config.strategy=dynamic
junit.jupiter.execution.parallel.config.dynamic.factor=1.5
```

```java
@Execution(ExecutionMode.CONCURRENT)
class OrderApiConcurrentTest extends AbstractIntegrationTest {
    // Tests run in parallel — must be stateless or use @DirtiesContext
}
```

**Warning:** Parallel tests sharing a DB must use isolated test data (unique IDs per test, transaction rollback with `@Transactional`, or separate schemas).

---

## Gatling Load Test

```scala
class OrderApiLoadTest extends Simulation {
  val httpProtocol = http
    .baseUrl("http://localhost:8080")
    .acceptHeader("application/json")

  val createOrder = scenario("Create Order")
    .exec(
      http("POST /orders")
        .post("/api/v1/orders")
        .header("Content-Type", "application/json")
        .body(StringBody("""{"customerId":"C1","items":[{"sku":"P1","qty":2}]}"""))
        .check(status.is(201))
    )

  setUp(
    createOrder.inject(
      rampUsersPerSec(10).to(100).during(60.seconds),  // ramp to 100 rps over 1 min
      constantUsersPerSec(100).during(120.seconds)     // sustain 100 rps for 2 min
    )
  ).protocols(httpProtocol)
   .assertions(
     global.responseTime.percentile(99).lt(500),  // P99 < 500ms
     global.failedRequests.percent.lt(1)          // error rate < 1%
   )
}
```

Run: `mvn gatling:test -Dgatling.simulationClass=OrderApiLoadTest`
