---
name: python-patterns
description: >
  Load when writing Python code, designing FastAPI or Django REST APIs, using Pydantic models,
  working with async Python (asyncio, httpx), writing pytest tests, configuring virtual environments,
  using SQLAlchemy ORM, or when asked "how do I structure this Python service", "should I use
  FastAPI or Django", "how do I write a Pydantic model", "how do I test this async function".
---

# Python Patterns

## Project Structure (Clean Architecture)

```
src/
├── main.py               # Entry point
├── api/
│   ├── routers/          # FastAPI routers — HTTP boundary only
│   └── schemas/          # Pydantic request/response models
├── domain/
│   ├── models/           # Pure Python dataclasses/domain objects
│   ├── services/         # Business logic — no HTTP, no ORM
│   └── repositories/     # Abstract interfaces (Protocol)
├── infrastructure/
│   ├── database/         # SQLAlchemy models, migrations (Alembic)
│   ├── http/             # External HTTP clients (httpx)
│   └── repositories/     # Concrete repository implementations
└── config.py             # Settings via pydantic-settings
```

## Naming Conventions

- `snake_case` for everything (modules, functions, variables, files)
- `PascalCase` for classes
- `SCREAMING_SNAKE_CASE` for module-level constants
- `is_*`, `has_*`, `can_*` for boolean functions
- Files: `order_service.py`, `user_repository.py`, `payment_router.py`

## Type Hints (Mandatory)

```python
# BAD — no type hints
def get_user(user_id):
    return repository.find(user_id)

# GOOD — explicit types everywhere
def get_user(user_id: UUID) -> UserResponse:
    return repository.find(user_id)
```

- Enable `mypy` or `pyright` in strict mode
- Use `from __future__ import annotations` for forward references
- Prefer `X | None` over `Optional[X]` (Python 3.10+)
- Use `TypeAlias` for complex types

## Immutability

```python
from dataclasses import dataclass, field

@dataclass(frozen=True)
class OrderId:
    value: UUID

# For DTOs: use Pydantic BaseModel (immutable by default with model_config)
from pydantic import BaseModel

class OrderResponse(BaseModel):
    model_config = ConfigDict(frozen=True)
    id: UUID
    customer_name: str
    total: Decimal
```

## FastAPI Patterns

```python
from fastapi import APIRouter, Depends, HTTPException, status
from uuid import UUID

router = APIRouter(prefix="/orders", tags=["orders"])

@router.get("/{order_id}", response_model=OrderResponse)
async def get_order(
    order_id: UUID,
    service: OrderService = Depends(get_order_service),
) -> OrderResponse:
    order = await service.find_by_id(order_id)
    if order is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Order not found")
    return OrderResponse.model_validate(order)
```

- Use `Depends()` for dependency injection — never import services directly in routers
- Always define `response_model` on route decorators
- Use `status` constants, not raw integers
- Validate path/query params via type annotations — FastAPI validates automatically

## Pydantic v2 Models

```python
from pydantic import BaseModel, field_validator, model_validator
from decimal import Decimal

class CreateOrderRequest(BaseModel):
    customer_id: UUID
    amount: Decimal

    @field_validator("amount")
    @classmethod
    def amount_must_be_positive(cls, v: Decimal) -> Decimal:
        if v <= 0:
            raise ValueError("amount must be positive")
        return v
```

- Use `model_validate()` instead of `parse_obj()` (v2)
- Use `model_dump()` instead of `dict()` (v2)
- Use `model_config = ConfigDict(...)` instead of `class Config` (v2)

## Dependency Injection

```python
# GOOD — factory function via Depends
def get_order_service(
    repo: OrderRepository = Depends(get_order_repository),
) -> OrderService:
    return OrderService(repository=repo)

# BAD — module-level singleton with side effects
order_service = OrderService(repository=SqlOrderRepository(db))
```

## Error Handling

```python
# Domain exception hierarchy
class DomainException(Exception):
    pass

class OrderNotFoundException(DomainException):
    def __init__(self, order_id: UUID) -> None:
        super().__init__(f"Order {order_id} not found")
        self.order_id = order_id

# FastAPI exception handler
@app.exception_handler(OrderNotFoundException)
async def order_not_found_handler(
    request: Request, exc: OrderNotFoundException
) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_404_NOT_FOUND,
        content={"error": "Order not found"},
    )
```

Never return raw Python exceptions to clients. Log detail server-side, return generic messages.

## Async Best Practices

```python
# Use httpx for async HTTP (not requests)
import httpx

async def call_payment_api(order_id: UUID) -> PaymentResult:
    async with httpx.AsyncClient(timeout=5.0) as client:
        response = await client.post("/payments", json={"order_id": str(order_id)})
        response.raise_for_status()
        return PaymentResult.model_validate(response.json())
```

- Use `async def` consistently — mixing sync and async causes deadlocks
- Set explicit timeouts on all external HTTP calls
- Use `asyncio.gather()` for parallel independent calls

## Settings Management

```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    database_url: str
    api_key: str
    debug: bool = False

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

settings = Settings()  # reads from env vars or .env file
```

Never hardcode secrets. Fail fast on startup if required env vars are missing.

## Testing with pytest

```python
import pytest
from httpx import AsyncClient, ASGITransport

@pytest.mark.asyncio
async def test_get_order_returns_200(app, order_in_db):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        response = await client.get(f"/orders/{order_in_db.id}")

    assert response.status_code == 200
    assert response.json()["id"] == str(order_in_db.id)
```

- Use `pytest-asyncio` for async tests
- Use `httpx.AsyncClient` with `ASGITransport` for FastAPI integration tests (no real server needed)
- Use `pytest-mock` or `unittest.mock` for mocking
- Name tests: `test_{function}_{context}_{expected}`
- Use `conftest.py` for shared fixtures
