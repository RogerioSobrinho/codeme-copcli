# Python Coding Style

## Naming Conventions

- `snake_case` for modules, functions, variables, parameters, files
- `PascalCase` for classes
- `SCREAMING_SNAKE_CASE` for module-level constants
- Boolean functions: `is_*`, `has_*`, `can_*`
- No `Manager`, `Helper`, `Utils` suffixes — use domain-specific names

## Type Hints (Mandatory)

```python
# BAD — no type hints
def get_user(user_id):
    return repository.find(user_id)

# GOOD — full type annotations
def get_user(user_id: UUID) -> UserResponse:
    return repository.find(user_id)
```

- Enable `mypy --strict` or `pyright` in `pyrightconfig.json`
- Use `X | None` over `Optional[X]` (Python 3.10+)
- Use `from __future__ import annotations` for forward references
- No `Any` in application code — use `object` or generics

## Immutability

```python
from dataclasses import dataclass

@dataclass(frozen=True)
class OrderId:
    value: UUID

# For API models: Pydantic with frozen=True
from pydantic import BaseModel, ConfigDict

class OrderResponse(BaseModel):
    model_config = ConfigDict(frozen=True)
    id: UUID
    customer_name: str
```

## Error Handling

```python
# BAD — bare except
try:
    result = process_order(order_id)
except Exception:
    pass  # silently swallowed

# GOOD — specific exception, log detail, re-raise with context
try:
    result = process_order(order_id)
except OrderNotFoundException as exc:
    logger.warning("Order not found", extra={"order_id": str(order_id)})
    raise
except Exception as exc:
    logger.error("Unexpected error", exc_info=True, extra={"order_id": str(order_id)})
    raise ServiceException("Failed to process order") from exc
```

- Never use bare `except` — always specify exception type
- Never catch `BaseException` or `SystemExit`
- Always preserve cause with `raise ... from exc`
- Log details server-side; return generic messages to clients

## Code Quality

- No `print()` in production — use `logging` or `pino`/`structlog` for structured logs
- No `Any` type annotation — use generics or `object`
- Max function length: **20 lines** — extract if longer
- Max class length: **200 lines** — split responsibilities
- Use `pathlib.Path` over `os.path` for file operations
- Use `decimal.Decimal` for monetary values — never `float`

## Input Validation

Use Pydantic v2 for all boundary validation:

```python
from pydantic import BaseModel, field_validator
from decimal import Decimal

class CreateOrderRequest(BaseModel):
    customer_id: UUID
    amount: Decimal

    @field_validator("amount")
    @classmethod
    def amount_positive(cls, v: Decimal) -> Decimal:
        if v <= 0:
            raise ValueError("amount must be positive")
        return v
```

## Logging

```python
import structlog

logger = structlog.get_logger()

# GOOD — structured, key-value pairs
logger.info("order_created", order_id=str(order.id), customer_id=str(customer_id))

# BAD — string concatenation
logger.info(f"Order {order.id} created for customer {customer_id}")
```

- Use structured logging (structlog or logging with JSON formatter)
- Never log passwords, tokens, or PII
- Include correlation/trace ID in every log entry

## API Response Format

```python
from pydantic import BaseModel
from typing import Generic, TypeVar

T = TypeVar("T")

class ApiResponse(BaseModel, Generic[T]):
    success: bool
    data: T | None = None
    error: str | None = None

    @classmethod
    def ok(cls, data: T) -> "ApiResponse[T]":
        return cls(success=True, data=data)

    @classmethod
    def error_response(cls, message: str) -> "ApiResponse[None]":
        return cls(success=False, error=message)
```
