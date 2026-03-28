---
name: golang-patterns
description: >
  Load when writing Go code, designing Go packages, handling errors in Go, using goroutines or channels,
  writing Go interfaces, implementing Go testing, using go.mod, or when asked "how do I structure this
  in Go", "what's the Go way to handle errors", "should I use goroutines here", "how do I write
  idiomatic Go", "how do I test this Go function".
---

# Go Patterns

Idiomatic Go for production services. These patterns are derived from the Go standard library style and the Uber Go Style Guide.

## Package Design

- One package per directory. Package name matches the directory name (no underscores, no `utils`, no `helpers`).
- Export only what callers need. Keep the internal surface small.
- No circular imports — extract shared types to a separate package if needed.

```go
// BAD — generic catch-all
package utils

// GOOD — domain-specific
package order
```

## Error Handling

Errors are values in Go. Handle them at every call site.

```go
// BAD — ignoring errors
result, _ := doSomething()

// BAD — generic wrapping without context
return fmt.Errorf("error: %w", err)

// GOOD — wrap with context at each layer
func (s *OrderService) FindByID(ctx context.Context, id string) (*Order, error) {
    order, err := s.repo.FindByID(ctx, id)
    if err != nil {
        return nil, fmt.Errorf("OrderService.FindByID id=%s: %w", id, err)
    }
    return order, nil
}
```

**Sentinel errors** — define at package level, check with `errors.Is`:
```go
var ErrNotFound = errors.New("not found")

// caller
if errors.Is(err, ErrNotFound) {
    // handle not found
}
```

**Error types** — for structured errors with extra fields, use `errors.As`:
```go
type ValidationError struct {
    Field   string
    Message string
}
func (e *ValidationError) Error() string { return fmt.Sprintf("%s: %s", e.Field, e.Message) }

var ve *ValidationError
if errors.As(err, &ve) {
    log.Printf("validation failed on field %s", ve.Field)
}
```

## Interfaces

Keep interfaces small — the smaller the interface, the more useful it is.

```go
// BAD — fat interface, hard to mock
type OrderRepository interface {
    FindByID(ctx context.Context, id string) (*Order, error)
    FindAll(ctx context.Context) ([]*Order, error)
    Save(ctx context.Context, order *Order) error
    Delete(ctx context.Context, id string) error
    Count(ctx context.Context) (int, error)
}

// GOOD — define the interface where it's used, with only the methods needed
type OrderFinder interface {
    FindByID(ctx context.Context, id string) (*Order, error)
}
```

**Accept interfaces, return structs:**
```go
// Function accepts interface (easy to mock in tests)
func ProcessOrder(ctx context.Context, finder OrderFinder, id string) (*Receipt, error) { ... }

// Constructor returns concrete struct (not interface — callers can still use an interface if they want)
func NewOrderService(repo *PostgresRepo) *OrderService { ... }
```

## Concurrency

Use goroutines and channels only when you need concurrency — not by default.

```go
// Simple concurrent fan-out with errgroup
import "golang.org/x/sync/errgroup"

g, ctx := errgroup.WithContext(ctx)
for _, id := range ids {
    id := id // capture loop variable
    g.Go(func() error {
        return process(ctx, id)
    })
}
if err := g.Wait(); err != nil {
    return fmt.Errorf("fan-out failed: %w", err)
}
```

**Rules:**
- Always pass `context.Context` as the first argument of any goroutine-launched function.
- Use `sync.WaitGroup` for fire-and-forget parallelism; use `errgroup` when you need error propagation.
- Never close a channel from the receiver side.
- Never share mutable state across goroutines without a mutex or channel.

```go
// Protect shared state
type SafeCounter struct {
    mu    sync.Mutex
    count int
}
func (c *SafeCounter) Inc() { c.mu.Lock(); defer c.mu.Unlock(); c.count++ }
```

## Context

Pass `context.Context` as the first parameter of every function that does I/O or may block.

```go
// GOOD
func (s *OrderService) FindByID(ctx context.Context, id string) (*Order, error) {
    return s.repo.FindByID(ctx, id)
}

// BAD — no context, can't cancel or add deadlines
func (s *OrderService) FindByID(id string) (*Order, error) { ... }
```

Always check for context cancellation in long loops:
```go
for _, item := range items {
    if err := ctx.Err(); err != nil {
        return err
    }
    process(item)
}
```

## Structs and Constructors

```go
// Use a constructor — validate inputs, set defaults
func NewOrderService(repo OrderRepository, logger *slog.Logger) (*OrderService, error) {
    if repo == nil {
        return nil, errors.New("repo is required")
    }
    return &OrderService{repo: repo, logger: logger}, nil
}
```

Use struct embedding for composition, not inheritance simulation:
```go
type AuditedOrder struct {
    Order         // embed — promotes all Order methods
    CreatedBy string
    UpdatedAt time.Time
}
```

## Testing

Go testing uses `testing.T` directly. No test frameworks needed for unit tests.

```go
func TestFindByID_Found(t *testing.T) {
    // Arrange
    repo := &fakeRepo{order: &Order{ID: "1", Status: "active"}}
    svc := &OrderService{repo: repo}

    // Act
    got, err := svc.FindByID(context.Background(), "1")

    // Assert
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
    if got.Status != "active" {
        t.Errorf("got status %q, want %q", got.Status, "active")
    }
}
```

**Table-driven tests** for multiple cases:
```go
func TestValidate(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        wantErr bool
    }{
        {"valid", "abc123", false},
        {"empty", "", true},
        {"too long", strings.Repeat("x", 300), true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := Validate(tt.input)
            if (err != nil) != tt.wantErr {
                t.Errorf("Validate(%q) error = %v, wantErr %v", tt.input, err, tt.wantErr)
            }
        })
    }
}
```

**Interfaces for mocking** — define a minimal interface, implement a fake inline in the test:
```go
type fakeRepo struct{ order *Order }
func (f *fakeRepo) FindByID(_ context.Context, _ string) (*Order, error) { return f.order, nil }
```

## Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Package | lowercase, single word | `order`, `payment` |
| Exported type | PascalCase | `OrderService`, `PaymentGateway` |
| Unexported | camelCase | `orderRepo`, `parseDate` |
| Interface | noun or `-er` suffix | `OrderFinder`, `Writer` |
| Error variable | `Err` prefix | `ErrNotFound`, `ErrTimeout` |
| Test function | `Test` + subject + condition | `TestFindByID_NotFound` |
| Boolean | `Is`/`Has`/`Can` prefix | `IsActive`, `HasExpired` |

## go.mod

- Always specify a Go version in `go.mod`.
- Use `go mod tidy` before committing to remove unused dependencies.
- Pin dependencies to specific versions — never use `latest` in production.
- Vendor if you need reproducible offline builds: `go mod vendor`.
