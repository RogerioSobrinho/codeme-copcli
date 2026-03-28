---
name: node-patterns
description: >
  Load when building Node.js/Express APIs with TypeScript, using middleware patterns,
  structuring a REST API with Express or Fastify, implementing authentication with JWT in Node,
  using Prisma or TypeORM for database access, writing Jest tests for Node services,
  or when asked "how do I structure this Node.js service", "how do I add middleware in Express",
  "how do I handle errors in Express", "how do I test this Express endpoint".
---

# Node.js Patterns (TypeScript)

## Project Structure

```
src/
├── server.ts             # HTTP server bootstrap only — no logic
├── app.ts                # Express/Fastify app factory — registers routes and middleware
├── config/
│   └── env.ts            # Validated environment variables (Zod)
├── api/
│   ├── routes/           # Route handlers — HTTP boundary only
│   ├── middleware/       # Auth, logging, error handling, rate limiting
│   └── schemas/          # Zod schemas for request validation
├── domain/
│   ├── services/         # Business logic — no HTTP, no ORM
│   ├── models/           # Domain interfaces and types
│   └── repositories/     # Abstract interfaces (TypeScript interfaces)
├── infrastructure/
│   ├── database/         # Prisma client, connection setup
│   ├── repositories/     # Concrete implementations
│   └── http/             # External HTTP clients (axios/got)
└── shared/
    ├── errors/           # Custom error classes
    └── logger.ts         # Pino logger singleton
```

## Environment Variables

```typescript
import { z } from 'zod';

const envSchema = z.object({
  PORT: z.string().transform(Number).default('3000'),
  DATABASE_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
});

export const env = envSchema.parse(process.env);
// Throws at startup if required vars are missing — fail fast
```

## Express App Factory

```typescript
import express, { Application } from 'express';

export function createApp(): Application {
  const app = express();

  app.use(express.json());
  app.use(requestLogger);
  app.use(correlationId);

  app.use('/api/orders', ordersRouter);
  app.use('/api/health', healthRouter);

  app.use(globalErrorHandler); // MUST be last

  return app;
}
```

Separate app factory from server bootstrap — makes testing without a real port trivial.

## Route Handlers

```typescript
// routes/orders.router.ts
const router = Router();

router.get(
  '/:id',
  authenticate,
  asyncHandler(async (req, res) => {
    const order = await orderService.findById(req.params.id);
    res.json({ success: true, data: order });
  })
);

export { router as ordersRouter };
```

- Route handlers contain no business logic — delegate to service
- Wrap all async handlers with `asyncHandler` (catches rejected promises)
- Use `authenticate` middleware for protected routes

## Global Error Handler

```typescript
// middleware/error-handler.ts
export function globalErrorHandler(
  err: unknown,
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  if (err instanceof ValidationError) {
    res.status(400).json({ success: false, error: err.message });
    return;
  }
  if (err instanceof NotFoundError) {
    res.status(404).json({ success: false, error: 'Resource not found' });
    return;
  }

  logger.error({ err, path: req.path }, 'Unhandled error');
  res.status(500).json({ success: false, error: 'Internal server error' });
}
```

Never send stack traces or internal error details to clients.

## Logging with Pino

```typescript
import pino from 'pino';

export const logger = pino({
  level: env.NODE_ENV === 'production' ? 'info' : 'debug',
  redact: ['req.headers.authorization', 'body.password', 'body.token'],
});
```

- Use structured logging (JSON) — never `console.log`
- Redact sensitive fields before logging
- Include `correlationId` in every log line for tracing

## Input Validation with Zod

```typescript
const createOrderSchema = z.object({
  customerId: z.string().uuid(),
  amount: z.number().positive(),
});

function validateBody<T>(schema: z.ZodSchema<T>) {
  return (req: Request, res: Response, next: NextFunction): void => {
    const result = schema.safeParse(req.body);
    if (!result.success) {
      res.status(400).json({ success: false, error: result.error.format() });
      return;
    }
    req.body = result.data;
    next();
  };
}

router.post('/', validateBody(createOrderSchema), asyncHandler(createOrderHandler));
```

## Database with Prisma

```typescript
// infrastructure/database/client.ts
import { PrismaClient } from '@prisma/client';

export const prisma = new PrismaClient({
  log: env.NODE_ENV === 'development' ? ['query', 'warn', 'error'] : ['warn', 'error'],
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  await prisma.$disconnect();
});
```

- Use Prisma for schema management and type-safe queries
- Keep Prisma client as a singleton — never instantiate per request
- Use `prisma.$transaction([...])` for multi-step writes

## JWT Authentication

```typescript
import jwt from 'jsonwebtoken';

interface JwtPayload {
  sub: string;
  role: string;
}

export function authenticate(req: Request, res: Response, next: NextFunction): void {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) {
    res.status(401).json({ success: false, error: 'Unauthorized' });
    return;
  }

  try {
    const payload = jwt.verify(token, env.JWT_SECRET) as JwtPayload;
    req.user = payload;
    next();
  } catch {
    res.status(401).json({ success: false, error: 'Invalid token' });
  }
}
```

## Testing with Jest + Supertest

```typescript
import request from 'supertest';
import { createApp } from '../app';

describe('GET /api/orders/:id', () => {
  it('returns 200 with order data', async () => {
    // Arrange
    const app = createApp();
    jest.spyOn(orderService, 'findById').mockResolvedValue(mockOrder);

    // Act
    const response = await request(app)
      .get('/api/orders/123')
      .set('Authorization', `Bearer ${testToken}`);

    // Assert
    expect(response.status).toBe(200);
    expect(response.body.data.id).toBe('123');
  });
});
```

- Use `supertest` for HTTP integration tests — no real server needed
- Use Jest `spyOn` to mock service dependencies
- Test the full HTTP stack: status codes, headers, response body
