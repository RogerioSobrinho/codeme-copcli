---
name: flutter-patterns
description: >
  Load when building Flutter apps with Clean Architecture, implementing BLoC pattern
  (flutter_bloc, Cubit, Bloc), state management with Riverpod (StateNotifierProvider,
  AsyncNotifierProvider), navigation with GoRouter, HTTP calls with Dio and interceptors,
  local persistence with Hive or Isar, dependency injection with GetIt or Riverpod,
  or when asked "how do I structure this Flutter screen", "should I use BLoC or Riverpod",
  "how do I manage state in Flutter", "how do I navigate between screens with GoRouter".
---

# Flutter Patterns

## Clean Architecture for Flutter

```
lib/
├── core/                      # Shared utilities, error handling, network client
│   ├── error/
│   │   ├── failures.dart      # Sealed class hierarchy for failures
│   │   └── exceptions.dart
│   └── network/
│       └── dio_client.dart
├── features/
│   └── orders/
│       ├── data/
│       │   ├── datasources/   # Remote (API) + local (cache) data sources
│       │   ├── models/        # DTOs with fromJson/toJson
│       │   └── repositories/  # Repository implementations
│       ├── domain/
│       │   ├── entities/      # Pure Dart domain objects (no Flutter, no JSON)
│       │   ├── repositories/  # Abstract repository interfaces
│       │   └── usecases/      # Single-responsibility use cases
│       └── presentation/
│           ├── bloc/          # BLoC / Cubit files
│           ├── pages/         # Full screens
│           └── widgets/       # Reusable widgets for this feature
└── main.dart
```

---

## BLoC Pattern (flutter_bloc)

### Cubit (simple state — no events)

```dart
class CartCubit extends Cubit<CartState> {
  CartCubit(this._addItemUseCase, this._removeItemUseCase)
      : super(const CartState.initial());

  final AddItemToCartUseCase _addItemUseCase;
  final RemoveItemFromCartUseCase _removeItemUseCase;

  Future<void> addItem(CartItem item) async {
    emit(const CartState.loading());

    final result = await _addItemUseCase(AddItemParams(item: item));

    result.fold(
      (failure) => emit(CartState.error(failure.message)),
      (updatedCart) => emit(CartState.loaded(updatedCart)),
    );
  }
}

// Sealed state class (Dart 3+)
sealed class CartState {
  const CartState();
  const factory CartState.initial() = CartInitial;
  const factory CartState.loading() = CartLoading;
  const factory CartState.loaded(Cart cart) = CartLoaded;
  const factory CartState.error(String message) = CartError;
}

class CartInitial extends CartState { const CartInitial(); }
class CartLoading extends CartState { const CartLoading(); }
class CartLoaded extends CartState {
  const CartLoaded(this.cart);
  final Cart cart;
}
class CartError extends CartState {
  const CartError(this.message);
  final String message;
}
```

### Bloc (complex — events + states)

```dart
// Use Bloc over Cubit when: event transformations (debounce, switchMap), complex event handling
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc(this._searchUseCase) : super(const SearchState.initial()) {
    on<SearchQueryChanged>(_onQueryChanged,
        transformer: debounce(const Duration(milliseconds: 300)));
    on<SearchCleared>(_onCleared);
  }

  final SearchProductsUseCase _searchUseCase;

  Future<void> _onQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) async {
    if (event.query.isEmpty) {
      emit(const SearchState.initial());
      return;
    }
    emit(const SearchState.loading());
    final result = await _searchUseCase(SearchParams(query: event.query));
    result.fold(
      (failure) => emit(SearchState.error(failure.message)),
      (products) => emit(SearchState.loaded(products)),
    );
  }
}
```

---

## Riverpod (Alternative to BLoC)

```dart
// providers.dart
final dioClientProvider = Provider<Dio>((ref) => DioClient.create());

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepositoryImpl(
    remoteDataSource: ref.watch(orderRemoteDataSourceProvider),
  );
});

// AsyncNotifierProvider for async state
@riverpod
class OrderList extends _$OrderList {
  @override
  Future<List<Order>> build() async {
    return ref.watch(orderRepositoryProvider).getOrders();
  }

  Future<void> cancelOrder(String orderId) async {
    await ref.read(orderRepositoryProvider).cancelOrder(orderId);
    ref.invalidateSelf(); // Refetch
  }
}

// In widget
class OrderListScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(orderListProvider);

    return ordersAsync.when(
      data: (orders) => OrderListView(orders: orders),
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) => ErrorView(message: error.toString()),
    );
  }
}
```

**BLoC vs. Riverpod:**

| BLoC | Riverpod |
|---|---|
| More verbose, explicit event-state machine | Less boilerplate, code generation friendly |
| Better for complex event transformations | Better for async data fetching (like React Query) |
| Easier to test event-to-state transitions | Easier to test provider output |
| Better with strict team architecture | Better for smaller teams / rapid development |

---

## GoRouter Navigation

```dart
// router.dart
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/orders',
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isOnLoginPage = state.matchedLocation == '/login';

      if (!isAuthenticated && !isOnLoginPage) return '/login';
      if (isAuthenticated && isOnLoginPage) return '/orders';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/orders',
            builder: (_, __) => const OrderListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) => OrderDetailScreen(
                  orderId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
```

---

## Dio HTTP Client

```dart
class DioClient {
  static Dio create() {
    final dio = Dio(BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.addAll([
      AuthInterceptor(),
      LogInterceptor(requestBody: true, responseBody: false), // Don't log response bodies (PII risk)
      RetryInterceptor(dio: dio, retries: 3),
    ]);

    return dio;
  }
}

class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = SecureStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // Token refresh logic here
    }
    handler.next(err);
  }
}
```

---

## Error Handling with Either

Use `fpdart` or `dartz` for functional error handling without exceptions crossing layer boundaries:

```dart
// Repository interface (domain layer)
abstract interface class OrderRepository {
  Future<Either<Failure, Order>> getOrder(String id);
  Future<Either<Failure, List<Order>>> getOrders();
  Future<Either<Failure, Unit>> cancelOrder(String id);
}

// Failure hierarchy (domain layer)
sealed class Failure {
  const Failure(this.message);
  final String message;
}
class NetworkFailure extends Failure { const NetworkFailure() : super('Network unavailable'); }
class ServerFailure extends Failure { const ServerFailure(super.message); }
class CacheFailure extends Failure { const CacheFailure(super.message); }
class NotFoundFailure extends Failure { const NotFoundFailure(String id) : super('Not found: $id'); }

// Repository implementation (data layer)
class OrderRepositoryImpl implements OrderRepository {
  @override
  Future<Either<Failure, Order>> getOrder(String id) async {
    try {
      final dto = await _remoteDataSource.getOrder(id);
      return Right(dto.toEntity());
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError) return const Left(NetworkFailure());
      return Left(ServerFailure(e.message ?? 'Unknown error'));
    }
  }
}
```

---

## Local Persistence — Hive (Key-Value) / Isar (Database)

```dart
// Hive — simple key-value cache for settings / tokens
class UserPreferences {
  static late Box _box;

  static Future<void> init() async {
    _box = await Hive.openBox('preferences');
  }

  static void setThemeMode(ThemeMode mode) => _box.put('theme_mode', mode.index);
  static ThemeMode getThemeMode() => ThemeMode.values[_box.get('theme_mode', defaultValue: 0)];
}

// Isar — embedded database for complex local data
@collection
class CachedOrder {
  Id id = Isar.autoIncrement;
  late String orderId;
  late String status;
  late DateTime cachedAt;

  @Index()
  late String customerId;
}
```
