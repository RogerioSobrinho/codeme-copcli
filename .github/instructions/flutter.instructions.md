# Flutter / Dart

## Project Structure (Clean Architecture)

```
lib/
├── core/                      # Shared utilities, error handling, network client
│   ├── error/                 # Failures (sealed class), exceptions
│   └── network/               # Dio client, interceptors
├── features/
│   └── orders/
│       ├── data/
│       │   ├── datasources/   # Remote (API) + local (cache)
│       │   ├── models/        # DTOs with fromJson/toJson
│       │   └── repositories/  # Repository implementations
│       ├── domain/
│       │   ├── entities/      # Pure Dart — no Flutter, no JSON
│       │   ├── repositories/  # Abstract interfaces
│       │   └── usecases/      # Single-responsibility use cases
│       └── presentation/
│           ├── bloc/          # BLoC / Cubit
│           ├── pages/         # Full screens
│           └── widgets/       # Feature-scoped reusable widgets
└── main.dart
```

## Dart Language Rules

- **`final` by default** — use `var` only when reassignment is required
- **Null safety:** avoid excessive `!` (bang operator) — use null checks, `??`, or pattern matching
- **No `print()` in production** — use `dart:developer` `log()` or the project's logging package
- **No `dynamic`** — enable `strict-casts`, `strict-inference`, `strict-raw-types` in `analysis_options.yaml`
- **Catching too broadly:** always use `on` clause — never bare `catch (e)`
- **Catching `Error`:** `Error` subtypes indicate bugs — do not catch them
- **Unused `async`:** never mark a function `async` if it does not `await` anything
- **`late` overuse:** prefer nullable or constructor initialization — `late` defers errors to runtime
- **Mutable collections in public APIs:** return unmodifiable views (`List.unmodifiable`, `UnmodifiableListView`)

```dart
// BAD
dynamic value = fetchSomething();
print('debug: $value');

// GOOD
final Object? value = fetchSomething();
log('debug: $value', name: 'OrderService');
```

## State Management

- **BLoC/Cubit** (preferred for complex state): use `flutter_bloc`. Events → BLoC → States. No business logic in widgets.
- **Riverpod** (preferred for simpler state): `StateNotifierProvider`, `AsyncNotifierProvider`.
- Never put business logic directly in widgets — delegate to BLoC/Cubit/Notifier.

## Navigation: GoRouter

- Use `GoRouter` for all navigation — no `Navigator.push` directly in business logic
- Define routes in a centralized `router.dart`
- Use `redirect` for auth guards

## HTTP: Dio + Interceptors

- Use `Dio` with interceptors for token attachment, refresh, and error normalization
- Never make raw HTTP calls from presentation layer — go through repository → datasource

## Widget Rules

- No single `build()` method exceeding **80 lines** — extract into smaller widgets
- **const constructors everywhere possible** — reduces rebuilds
- Prefer `StatelessWidget` + state management over `StatefulWidget`
- Use `Key` when widgets of the same type appear in lists

## Failures (Sealed Classes)

Model domain errors as sealed classes — not exceptions:

```dart
sealed class OrderFailure {
  const OrderFailure();
}
class NotFoundFailure extends OrderFailure { const NotFoundFailure(); }
class NetworkFailure extends OrderFailure { const NetworkFailure(); }
class ServerFailure extends OrderFailure {
  const ServerFailure(this.message);
  final String message;
}
```

Use `Either<Failure, T>` (from `dartz` or `fpdart`) in repository return types.

## Security

- Never store secrets or tokens in `SharedPreferences` (plain text) — use `flutter_secure_storage`
- Validate server certificates — do not disable SSL verification in production
- Obfuscate release builds: `flutter build apk --obfuscate --split-debug-info=...`

## Code Quality

- Enable strict lints: use `flutter_lints` or `very_good_analysis`
- Run `dart fix --apply` and `flutter analyze` before committing
- Generated files (`.g.dart`, `.freezed.dart`) in `.gitignore` or committed consistently
