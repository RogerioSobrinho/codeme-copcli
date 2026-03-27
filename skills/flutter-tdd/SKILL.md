---
name: flutter-tdd
description: >
  Load when writing Flutter widget tests (WidgetTester, pump, pumpWidget), unit tests for
  BLoC or Cubit (bloc_test, whenListen), unit tests for Riverpod providers (ProviderContainer,
  overrides), testing navigation with GoRouter, golden tests (matchesGoldenFile),
  integration tests (integration_test package), measuring test coverage with lcov,
  or when asked "how do I test this Flutter widget", "how do I test this BLoC",
  "how do I write a golden test", "how do I mock a Riverpod provider in tests".
---

# Flutter TDD

## Testing Pyramid for Flutter

```
        [Integration — integration_test (real device/emulator)]
       [Widget — WidgetTester (render + interaction, no real device)]
  [Unit — plain Dart tests for BLoC, UseCases, Repositories, Models]
```

Unit tests cover the most code with the least overhead. Widget tests cover user-visible behavior. Integration tests cover critical end-to-end flows only.

---

## Unit Tests — BLoC / Cubit with bloc_test

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAddItemToCartUseCase extends Mock implements AddItemToCartUseCase {}

void main() {
  group('CartCubit', () {
    late CartCubit cubit;
    late MockAddItemToCartUseCase mockAddItem;

    setUp(() {
      mockAddItem = MockAddItemToCartUseCase();
      cubit = CartCubit(mockAddItem, MockRemoveItemUseCase());
    });

    tearDown(() => cubit.close());

    test('initial state is CartInitial', () {
      expect(cubit.state, const CartState.initial());
    });

    blocTest<CartCubit, CartState>(
      'emits [loading, loaded] when addItem succeeds',
      build: () {
        when(() => mockAddItem(any()))
            .thenAnswer((_) async => Right(mockCart));
        return cubit;
      },
      act: (cubit) => cubit.addItem(mockCartItem),
      expect: () => [
        const CartState.loading(),
        CartState.loaded(mockCart),
      ],
    );

    blocTest<CartCubit, CartState>(
      'emits [loading, error] when addItem fails',
      build: () {
        when(() => mockAddItem(any()))
            .thenAnswer((_) async => const Left(ServerFailure('Out of stock')));
        return cubit;
      },
      act: (cubit) => cubit.addItem(mockCartItem),
      expect: () => [
        const CartState.loading(),
        const CartState.error('Out of stock'),
      ],
    );
  });
}
```

---

## Unit Tests — Riverpod Providers

```dart
void main() {
  group('OrderList provider', () {
    test('returns orders from repository on build', () async {
      // Arrange
      final mockRepo = MockOrderRepository();
      when(() => mockRepo.getOrders()).thenAnswer((_) async => Right(mockOrders));

      final container = ProviderContainer(
        overrides: [
          orderRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      // Act
      final result = await container.read(orderListProvider.future);

      // Assert
      expect(result, mockOrders);
    });

    test('cancelOrder invalidates provider and refetches', () async {
      // Arrange
      final mockRepo = MockOrderRepository();
      when(() => mockRepo.getOrders()).thenAnswer((_) async => Right(mockOrders));
      when(() => mockRepo.cancelOrder(any())).thenAnswer((_) async => const Right(unit));

      final container = ProviderContainer(overrides: [
        orderRepositoryProvider.overrideWithValue(mockRepo),
      ]);
      addTearDown(container.dispose);

      // Load initial state
      await container.read(orderListProvider.future);

      // Act
      await container.read(orderListProvider.notifier).cancelOrder('order-1');

      // Assert — repository called twice (initial load + after cancel)
      verify(() => mockRepo.getOrders()).called(2);
    });
  });
}
```

---

## Widget Tests

```dart
void main() {
  group('OrderListScreen', () {
    late MockOrderListBloc mockBloc;

    setUp(() {
      mockBloc = MockOrderListBloc();
    });

    testWidgets('shows orders when state is loaded', (tester) async {
      // Arrange
      when(() => mockBloc.state).thenReturn(OrderListState.loaded(mockOrders));
      whenListen(
        mockBloc,
        Stream.fromIterable([OrderListState.loaded(mockOrders)]),
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<OrderListBloc>.value(
            value: mockBloc,
            child: const OrderListScreen(),
          ),
        ),
      );

      // Assert
      expect(find.byType(OrderCard), findsNWidgets(mockOrders.length));
    });

    testWidgets('shows loading indicator when state is loading', (tester) async {
      when(() => mockBloc.state).thenReturn(const OrderListState.loading());
      whenListen(mockBloc, const Stream.empty());

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<OrderListBloc>.value(
            value: mockBloc,
            child: const OrderListScreen(),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('tapping cancel button calls cancelOrder', (tester) async {
      when(() => mockBloc.state).thenReturn(OrderListState.loaded([mockOrder]));
      whenListen(mockBloc, const Stream.empty());

      await tester.pumpWidget(/* ... */);

      await tester.tap(find.byKey(const Key('cancel-button-order-1')));
      await tester.pump();

      verify(() => mockBloc.add(const CancelOrderEvent('order-1'))).called(1);
    });
  });
}
```

---

## Golden Tests

Golden tests catch unintended visual regressions by comparing rendered widget screenshots against approved baselines.

```dart
void main() {
  testWidgets('OrderCard renders correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrderCard(order: mockOrder),
        ),
      ),
    );

    await expectLater(
      find.byType(OrderCard),
      matchesGoldenFile('goldens/order_card.png'),
    );
  });
}
```

**Golden test workflow:**
1. Run `flutter test --update-goldens` to create/update baseline images.
2. Commit golden files to source control.
3. CI runs `flutter test` (without `--update-goldens`) — fails if rendering changed.
4. On intentional UI change: run `--update-goldens`, review diff, re-commit.

**When to use golden tests:** custom design system components, complex layouts, dark mode variations.

---

## Integration Tests

```dart
// integration_test/order_flow_test.dart
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Order creation flow', () {
    testWidgets('user can create an order end-to-end', (tester) async {
      app.main(); // Start the real app
      await tester.pumpAndSettle();

      // Navigate to create order
      await tester.tap(find.byKey(const Key('create-order-button')));
      await tester.pumpAndSettle();

      // Fill in form
      await tester.enterText(find.byKey(const Key('customer-id-field')), 'cust-123');
      await tester.tap(find.byKey(const Key('add-item-button')));
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.byKey(const Key('submit-button')));
      await tester.pumpAndSettle();

      // Assert navigation to order detail
      expect(find.byType(OrderDetailScreen), findsOneWidget);
    });
  });
}
```

Run integration tests:
```bash
# On a connected device or emulator
flutter test integration_test/order_flow_test.dart -d <device_id>

# With Firebase Test Lab
gcloud firebase test android run \
  --type instrumentation \
  --app build/app/outputs/apk/debug/app-debug.apk \
  --test build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk
```

---

## Coverage

```bash
# Run tests with coverage
flutter test --coverage

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# View report
open coverage/html/index.html

# CI: enforce minimum coverage
lcov --list coverage/lcov.info | grep "lines......"
# Check output manually or use a coverage enforcement tool
```

**Coverage targets:**

| Category | Target |
|---|---|
| Domain layer (use cases, entities) | 100% |
| Data layer (repositories, data sources) | ≥ 90% |
| BLoC / Cubit | ≥ 90% |
| Widget (screens) | ≥ 70% |
| Integration | Critical paths only |

---

## Mocktail vs. Mockito

Prefer `mocktail` over `mockito` for Flutter:
- No code generation required
- Works natively with `null-safe` Dart
- Cleaner `when(() => mock.method())` syntax vs. `when(mock.method())`

```yaml
# pubspec.yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  bloc_test: ^9.0.0
  mocktail: ^1.0.0
  integration_test:
    sdk: flutter
```
