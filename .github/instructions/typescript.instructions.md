# TypeScript Coding Style

## Types

- Add explicit types to exported functions, shared utilities, and public class methods
- Let TypeScript infer obvious local variable types
- Use `interface` for object shapes that may be extended; `type` for unions, intersections, mapped types
- Prefer string literal unions over `enum` unless interoperability requires it

## Avoid `any`

```typescript
// BAD — any removes type safety
function getErrorMessage(error: any) { return error.message; }

// GOOD — unknown forces safe narrowing
function getErrorMessage(error: unknown): string {
  if (error instanceof Error) return error.message;
  return 'Unexpected error';
}
```

Use `unknown` for external/untrusted input, then narrow safely. Use generics when a value's type depends on the caller.

## Immutability

```typescript
// BAD — mutation
function updateUser(user: User, name: string): User {
  user.name = name;  // mutates original
  return user;
}

// GOOD — immutable update
function updateUser(user: Readonly<User>, name: string): User {
  return { ...user, name };
}
```

Prefer `const` for all local variables. Use `Readonly<T>` and `ReadonlyArray<T>` on public API parameters.

## Error Handling

```typescript
async function loadUser(userId: string): Promise<User> {
  try {
    return await fetchUser(userId);
  } catch (error: unknown) {
    logger.error('Failed to load user', { userId, error });
    throw new Error(getErrorMessage(error));
  }
}
```

## Input Validation

Use Zod for schema-based validation — infer types from the schema:

```typescript
import { z } from 'zod';

const createOrderSchema = z.object({
  customerId: z.string().uuid(),
  amount: z.number().positive(),
});

type CreateOrderInput = z.infer<typeof createOrderSchema>;

const validated = createOrderSchema.parse(rawInput);
```

## Code Quality

- No `console.log` in production code — use a proper logger (pino, winston)
- No `any` in application code — use ESLint `@typescript-eslint/no-explicit-any`
- Enable strict mode in `tsconfig.json`: `"strict": true`
- Functions: max 20 lines; files: target 200–400 lines, max 800

## API Response Format

```typescript
interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
}
```
