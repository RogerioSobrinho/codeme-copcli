---
name: frontend-principles
description: >
  Load when designing frontend architecture for any framework, separating presentation from
  business logic (smart/dumb component split), designing state management strategy, integrating
  with a REST or GraphQL API, implementing authentication flow (token storage, refresh, logout),
  or when asked "how should I structure this frontend", "where does this logic go",
  "how do I manage state here", or "how do I handle auth on the client side".
---

# Frontend Principles

Framework-agnostic frontend architecture. These rules apply to Angular, Flutter, React, and any component-based UI.

---

## Clean Architecture for Frontend

```
┌─────────────────────────────────────────────────────┐
│  Presentation Layer (Components / Widgets / Views)  │
│  — Renders UI, handles user events                  │
│  — Reads from state; dispatches actions/commands    │
├─────────────────────────────────────────────────────┤
│  State / Application Layer (BLoC / Store / Service) │
│  — Orchestrates use cases                           │
│  — Holds in-memory application state                │
│  — Calls domain or data layer                       │
├─────────────────────────────────────────────────────┤
│  Domain Layer (Models / Use Cases / Validators)     │
│  — Framework-agnostic business rules                │
│  — No HTTP, no UI, no persistence                   │
├─────────────────────────────────────────────────────┤
│  Data Layer (Repositories / API Clients / Cache)    │
│  — Abstracts HTTP, local storage, device APIs       │
│  — Maps raw JSON/bytes to domain models             │
└─────────────────────────────────────────────────────┘
```

**Dependency rule:** each layer only depends on the layer directly below it. The domain layer has zero external dependencies.

---

## Smart / Dumb Component Split

| Component type | Responsibility | Has state? | Makes API calls? |
|---|---|---|---|
| **Smart (Container)** | Owns data fetching, state, and business decisions | Yes | Yes (via service/repository) |
| **Dumb (Presentational)** | Renders data; emits events via outputs/callbacks | No | Never |

**Rules:**
- Dumb components accept data via inputs/props only.
- Dumb components emit events via outputs/callbacks — they never call services directly.
- Smart components are few (one per route/screen, ideally). Dumb components are many.
- If a dumb component needs to call a service, it should be promoted to smart or a new smart parent should wrap it.

---

## State Management Decision

| Scale | Recommended approach |
|---|---|
| Component-local, ephemeral | Local state (component field / `useState`) |
| Shared across siblings | Lift state up to parent |
| Shared across a feature | Feature-level state service / BLoC |
| Shared across the app (user, auth, settings) | Global store (NgRx, Riverpod, Provider) |

**Anti-pattern:** Do not use global store for local state. A `LoadingState` for a single button press does not belong in the global store.

---

## API Integration Pattern

```
Component → Service/Repository → HTTP Client → Backend API
                ↑
           Handles errors,
           maps DTOs to
           domain models
```

**Rules:**
- Never call `HttpClient` / `Dio` / `http` directly from a component.
- Repositories return domain models, not raw JSON.
- Handle HTTP errors at the repository boundary — do not propagate raw HTTP exceptions to the UI.
- Use a single HTTP interceptor for: auth token injection, error normalization, logging.

**Error handling strategy:**
```
HTTP 400 → Validation error → show field-level feedback
HTTP 401 → Unauthorized → trigger refresh token flow
HTTP 403 → Forbidden → redirect or show access denied
HTTP 422 → Business rule violation → show user-readable message
HTTP 5xx → Server error → show generic error + retry option
Network error → show offline indicator + retry option
```

---

## Authentication Flow

### Token Storage

| Platform | Recommended storage | Avoid |
|---|---|---|
| Web (Angular) | `sessionStorage` for short-lived, `localStorage` with HttpOnly flag awareness | `localStorage` for long-lived access tokens |
| Mobile (Flutter) | `flutter_secure_storage` | `SharedPreferences` for tokens |

### Access Token Refresh

```
Request → HTTP Interceptor
  → If 401 and refresh token exists:
    → Pause in-flight requests
    → Call /auth/refresh
    → If success: update token, retry queued requests
    → If failure: clear tokens, redirect to login
```

**Never retry infinitely** — set a max of 1 refresh attempt per 401.

### Logout

1. Clear tokens from storage
2. Dispatch global logout action (clear all in-memory state)
3. Navigate to login screen
4. Invalidate the token on the backend (`POST /auth/logout` with refresh token)

Step 4 is often skipped — it is required if the backend maintains a token allowlist/denylist.

---

## Loading & Error States

Every async operation should have three states: **idle**, **loading**, **success/error**.

```
// Pattern for any async operation:
sealed class AsyncState<T> {
  Initial()
  Loading()
  Success(T data)
  Failure(String message)
}
```

Components render based on the current state — they never show stale data from a previous successful load alongside a new error.

---

## Accessibility Baseline

- All interactive elements have an accessible label (aria-label, semantics, tooltip).
- Color is never the only way to convey meaning (add icons or text).
- Keyboard navigation works for all interactive elements on web.
- Text is resizable without breaking layout (avoid fixed-height containers on text).

---

## Performance Baseline

- Lazy-load routes/screens — never load all feature code upfront.
- Paginate or virtualize lists > 100 items — never render all at once.
- Debounce user input before making API calls (300ms for search, 500ms for form auto-save).
- Cache stable data (e.g., lookup lists, user profile) — revalidate on user action or fixed TTL.
- Avoid re-renders on every keystroke in forms — use reactive form models, not state per character.
