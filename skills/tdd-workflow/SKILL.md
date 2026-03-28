---
name: tdd-workflow
description: >
  Load when writing a new feature, fixing a bug, or refactoring code in any stack.
  Enforces the RED → GREEN → REFACTOR cycle with 80%+ coverage. Use when asked
  "how do I write this with TDD", "write tests first", "what tests should I write for this",
  "help me apply TDD to this feature". Covers Java (JUnit5/AssertJ/Mockito),
  TypeScript (Jest/Vitest/Playwright), and Flutter (flutter_test/bloc_test).
---

# Test-Driven Development Workflow

Enforce: **write the failing test first**, then implement the minimum code to make it pass, then refactor.

## The Cycle

```
RED   → Write a failing test. Run it. Confirm it fails for the right reason.
GREEN → Write the minimum code to make it pass. No more.
REFACTOR → Clean up while tests stay green.
REPEAT
```

**Never skip RED.** A test that was never failing gives zero confidence.

---

## Coverage Requirements

| Test type | Minimum | 100% required for |
|---|---|---|
| Unit | 80% | Auth, payments, security-critical code |
| Integration | Key flows | DB operations, API endpoints |
| E2E | Critical paths | Login, checkout, core user journeys |

---

## Java (JUnit 5 + AssertJ + Mockito)

### Unit test

```java
@ExtendWith(MockitoExtension.class)
class OrderServiceTest {

    @Mock private OrderRepository orderRepository;
    private OrderService sut;

    @BeforeEach void setUp() { sut = new OrderService(orderRepository); }

    @Test
    @DisplayName("createOrder saves and returns the new order")
    void createOrder_validRequest_returnsSavedOrder() {
        // Arrange
        var request = new CreateOrderRequest("cust-1", List.of(new OrderItem("prod-1", 2)));
        var saved = new Order(UUID.randomUUID(), "cust-1", OrderStatus.PENDING);
        when(orderRepository.save(any())).thenReturn(saved);

        // Act
        var result = sut.createOrder(request);

        // Assert
        assertThat(result.status()).isEqualTo(OrderStatus.PENDING);
        verify(orderRepository).save(any(Order.class));
    }

    @Test
    @DisplayName("createOrder throws when customer ID is blank")
    void createOrder_blankCustomerId_throwsIllegalArgument() {
        var request = new CreateOrderRequest("", List.of());
        assertThatThrownBy(() -> sut.createOrder(request))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessageContaining("customerId");
    }
}
```

### Repository / integration test (Testcontainers)

```java
@DataJpaTest
@Testcontainers
class OrderRepositoryIT {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16")
        .withReuse(true);

    @DynamicPropertySource
    static void props(DynamicPropertyRegistry r) {
        r.add("spring.datasource.url", postgres::getJdbcUrl);
        r.add("spring.datasource.username", postgres::getUsername);
        r.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired OrderRepository sut;

    @Test
    void save_thenFindById_returnsPersistedOrder() {
        var order = new Order(null, "cust-1", OrderStatus.PENDING);
        var saved = sut.save(order);
        var found = sut.findById(saved.id());
        assertThat(found).isPresent().get()
            .extracting(Order::customerId).isEqualTo("cust-1");
    }
}
```

### Run + coverage

```bash
./mvnw test                          # unit tests
./mvnw verify                        # all tests including integration
./mvnw verify jacoco:report          # coverage report → target/site/jacoco/index.html
```

---

## TypeScript (Jest / Vitest)

### Unit test

```typescript
// orders.service.test.ts
import { OrderService } from './orders.service';
import { OrderRepository } from './orders.repository';

jest.mock('./orders.repository');

describe('OrderService', () => {
  let sut: OrderService;
  let repo: jest.Mocked<OrderRepository>;

  beforeEach(() => {
    repo = new OrderRepository() as jest.Mocked<OrderRepository>;
    sut = new OrderService(repo);
  });

  it('createOrder returns the saved order', async () => {
    // Arrange
    const saved = { id: 'ord-1', customerId: 'cust-1', status: 'PENDING' };
    repo.save.mockResolvedValue(saved);

    // Act
    const result = await sut.createOrder({ customerId: 'cust-1', items: [] });

    // Assert
    expect(result.status).toBe('PENDING');
    expect(repo.save).toHaveBeenCalledTimes(1);
  });

  it('createOrder rejects blank customerId', async () => {
    await expect(sut.createOrder({ customerId: '', items: [] }))
      .rejects.toThrow('customerId');
  });
});
```

### API integration test (supertest / httpx)

```typescript
import request from 'supertest';
import { app } from '../app';

describe('POST /orders', () => {
  it('returns 201 with the created order', async () => {
    const res = await request(app)
      .post('/orders')
      .send({ customerId: 'cust-1', items: [{ productId: 'prod-1', qty: 2 }] });

    expect(res.status).toBe(201);
    expect(res.body.data.status).toBe('PENDING');
  });

  it('returns 400 when customerId is missing', async () => {
    const res = await request(app).post('/orders').send({ items: [] });
    expect(res.status).toBe(400);
  });
});
```

### Run + coverage

```bash
npx jest --coverage
# or with Vitest:
npx vitest run --coverage
```

---

## Flutter (flutter_test + bloc_test)

### Widget test

```dart
testWidgets('OrderListPage shows empty state when orders list is empty', (tester) async {
  // Arrange
  when(mockBloc.state).thenReturn(const OrderState.loaded([]));

  // Act
  await tester.pumpWidget(
    BlocProvider<OrderBloc>.value(
      value: mockBloc,
      child: const MaterialApp(home: OrderListPage()),
    ),
  );

  // Assert
  expect(find.text('No orders yet'), findsOneWidget);
  expect(find.byType(OrderCard), findsNothing);
});
```

### BLoC test

```dart
blocTest<OrderBloc, OrderState>(
  'emits [loading, loaded] when LoadOrders succeeds',
  build: () {
    when(mockRepo.getOrders()).thenAnswer((_) async => [fakeOrder]);
    return OrderBloc(repository: mockRepo);
  },
  act: (bloc) => bloc.add(const LoadOrders()),
  expect: () => [
    const OrderState.loading(),
    OrderState.loaded([fakeOrder]),
  ],
);
```

### Run + coverage

```bash
flutter test                              # all tests
flutter test --coverage                   # coverage → coverage/lcov.info
genhtml coverage/lcov.info -o coverage/html && open coverage/html/index.html
```

---

## Test Naming Convention

| Stack | Pattern | Example |
|---|---|---|
| Java | `method_context_expectation` | `createOrder_blankCustomerId_throwsIllegalArgument` |
| TypeScript | `describe + it` | `describe('OrderService') it('rejects blank customerId')` |
| Flutter | `'description of expected behavior'` | `'shows empty state when list is empty'` |

---

## Anti-Patterns

❌ Writing implementation before tests — removes the verification that the test can fail.
❌ Testing implementation details (private methods, internal state) — test behavior, not structure.
❌ One massive test for multiple behaviors — one test, one behavior.
❌ `Thread.sleep()` in async tests — use Awaitility (Java), `fakeAsync`/`pump` (Flutter), `jest.useFakeTimers()` (TS).
❌ Skipping the refactor step — green is not done; clean code is done.
