---
name: react-patterns
description: >
  Load when building React applications with TypeScript, using hooks (useState, useEffect,
  useContext, useReducer, custom hooks), managing state with Zustand or React Query,
  routing with React Router v6+, fetching data with TanStack Query, building forms with
  React Hook Form + Zod, or when asked "how do I structure this React component",
  "should I use Context or Zustand", "how do I handle async state in React".
---

# React Patterns (TypeScript)

## Project Structure

```
src/
├── app/                  # App-level setup: providers, router, global styles
├── features/             # Feature-scoped modules (collocate everything)
│   └── orders/
│       ├── api/          # TanStack Query hooks (useOrders, useCreateOrder)
│       ├── components/   # Feature-specific components
│       ├── hooks/        # Feature-specific custom hooks
│       ├── types.ts      # TypeScript interfaces for this feature
│       └── index.ts      # Public surface — only export what consumers need
├── shared/
│   ├── components/       # Design system: Button, Input, Modal
│   ├── hooks/            # App-wide custom hooks
│   └── lib/              # Utility functions (pure, no React)
└── main.tsx
```

## Component Conventions

```tsx
// Functional components with explicit return type
interface OrderCardProps {
  readonly order: Order;
  readonly onCancel: (id: string) => void;
}

export function OrderCard({ order, onCancel }: OrderCardProps): React.ReactElement {
  return (
    <div>
      <h2>{order.customerName}</h2>
      <button onClick={() => onCancel(order.id)}>Cancel</button>
    </div>
  );
}
```

- **No default exports** — use named exports for all components (easier refactoring)
- Always define `Props` interface — inline props in the signature only for trivial components
- Mark props `readonly` to prevent accidental mutation

## Smart / Dumb Component Split

```tsx
// DUMB — receives data, emits events, no side effects
function OrderList({ orders, onCancel }: OrderListProps) { ... }

// SMART — owns data fetching and business logic
function OrderListContainer() {
  const { data: orders, isLoading } = useOrders();
  const { mutate: cancelOrder } = useCancelOrder();
  return <OrderList orders={orders ?? []} onCancel={cancelOrder} />;
}
```

Dumb components are pure and testable without mocks. Smart components live close to the route.

## Data Fetching: TanStack Query

```tsx
// Query hook — collocate with the feature
function useOrders(): UseQueryResult<Order[]> {
  return useQuery({
    queryKey: ['orders'],
    queryFn: () => apiClient.get<Order[]>('/orders').then(r => r.data),
    staleTime: 30_000,
  });
}

// Mutation hook
function useCancelOrder(): UseMutationResult<void, Error, string> {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (orderId: string) => apiClient.delete(`/orders/${orderId}`),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['orders'] }),
  });
}
```

- Never use `useEffect` + `useState` for data fetching — use TanStack Query
- Define `queryKey` as constants to avoid typos

## State Management: Zustand

```tsx
// For app-wide state that doesn't come from the server
interface AuthStore {
  user: User | null;
  setUser: (user: User) => void;
  logout: () => void;
}

const useAuthStore = create<AuthStore>((set) => ({
  user: null,
  setUser: (user) => set({ user }),
  logout: () => set({ user: null }),
}));
```

Use Zustand for client state. Use TanStack Query for server state. Never mix them.

## Forms: React Hook Form + Zod

```tsx
const createOrderSchema = z.object({
  customerId: z.string().uuid('Invalid customer ID'),
  amount: z.number().positive('Amount must be positive'),
});

type CreateOrderInput = z.infer<typeof createOrderSchema>;

function CreateOrderForm({ onSubmit }: { onSubmit: (data: CreateOrderInput) => void }) {
  const { register, handleSubmit, formState: { errors } } = useForm<CreateOrderInput>({
    resolver: zodResolver(createOrderSchema),
  });

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <input {...register('customerId')} />
      {errors.customerId && <span>{errors.customerId.message}</span>}
      <button type="submit">Create</button>
    </form>
  );
}
```

## Custom Hooks

```tsx
// Extract reusable logic — keeps components thin
function useOrderTotal(items: OrderItem[]): Decimal {
  return useMemo(
    () => items.reduce((sum, item) => sum.plus(item.price), new Decimal(0)),
    [items]
  );
}
```

- Custom hooks must start with `use`
- Extract any non-trivial logic from components into custom hooks
- Keep hooks focused: one concern per hook

## Performance

- Memoize expensive computations with `useMemo`
- Stabilize callback references with `useCallback` (only when passed as props to memo'd components)
- Use `React.memo` on pure components that render frequently
- Lazy-load route-level components: `const Orders = React.lazy(() => import('./features/orders'))`

## Avoid `useEffect` Anti-Patterns

```tsx
// BAD — useEffect as derived state
const [fullName, setFullName] = useState('');
useEffect(() => { setFullName(`${first} ${last}`); }, [first, last]);

// GOOD — just compute it
const fullName = `${first} ${last}`;
```

Use `useEffect` only for: subscriptions, DOM mutations, and synchronizing with external systems. Not for derived state.

## Testing

```tsx
import { render, screen, userEvent } from '@testing-library/react';

test('cancel button calls onCancel with order id', async () => {
  const onCancel = jest.fn();
  render(<OrderCard order={mockOrder} onCancel={onCancel} />);

  await userEvent.click(screen.getByRole('button', { name: /cancel/i }));

  expect(onCancel).toHaveBeenCalledWith(mockOrder.id);
});
```

- Use `@testing-library/react` — test behavior, not implementation
- Wrap async interactions with `await userEvent.*` — never `fireEvent`
- Mock TanStack Query with `createWrapper()` from `@testing-library/react-query`
