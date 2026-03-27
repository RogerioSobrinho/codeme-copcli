---
name: angular-patterns
description: >
  Load when writing Angular components, directives, services, or pipes; using Angular 17+
  standalone components; implementing signals (signal(), computed(), effect()); configuring
  OnPush change detection; using the inject() function instead of constructor DI; building
  reactive forms (FormBuilder, FormGroup, FormControl, Validators); writing RxJS operators
  (switchMap, combineLatest, takeUntilDestroyed); configuring HttpClient interceptors; or
  when asked "how do I structure this Angular component", "should I use signals or RxJS here",
  or "how do I configure this Angular service".
---

# Angular Patterns (Angular 17+)

## Standalone Components (Default)

All new components, directives, and pipes are standalone. Do not use `NgModule` for new code.

```typescript
@Component({
  selector: 'app-order-list',
  standalone: true,
  imports: [CommonModule, RouterLink, OrderCardComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    @if (orders().length > 0) {
      <div class="order-list">
        @for (order of orders(); track order.id) {
          <app-order-card [order]="order" (cancel)="onCancel($event)" />
        }
      </div>
    } @else {
      <p>No orders found.</p>
    }
  `
})
export class OrderListComponent {
  private readonly orderService = inject(OrderService);
  
  protected readonly orders = this.orderService.orders; // Signal<Order[]>
  
  protected onCancel(orderId: string): void {
    this.orderService.cancelOrder(orderId);
  }
}
```

**Key rules:**
- Always set `changeDetection: ChangeDetectionStrategy.OnPush`.
- Use `inject()` instead of constructor injection.
- Use Angular 17 control flow (`@if`, `@for`, `@switch`) instead of `*ngIf`, `*ngFor`.

---

## Signals

Signals replace `BehaviorSubject` for component-local and service-level state.

```typescript
@Injectable({ providedIn: 'root' })
export class CartService {
  // Writable signal — owned by this service
  private readonly _items = signal<CartItem[]>([]);
  
  // Read-only projection exposed to consumers
  readonly items = this._items.asReadonly();
  
  // Computed signal — derived state, auto-updates
  readonly totalAmount = computed(() =>
    this._items().reduce((sum, item) => sum + item.price * item.quantity, 0)
  );
  
  readonly isEmpty = computed(() => this._items().length === 0);
  
  addItem(item: CartItem): void {
    this._items.update(current => [...current, item]);
  }
  
  removeItem(itemId: string): void {
    this._items.update(current => current.filter(i => i.id !== itemId));
  }
}
```

**When to use signals vs. RxJS:**

| Use Signals | Use RxJS |
|---|---|
| Component-local state | Async streams (HTTP, WebSocket) |
| Service state that drives UI | Complex async coordination (switchMap, combineLatest) |
| Derived state (computed()) | Time-based operations (debounceTime, delay) |
| Replacing BehaviorSubject | Event streams with multiple subscribers |

---

## Reactive Forms

```typescript
@Component({ standalone: true, imports: [ReactiveFormsModule, ...] })
export class CreateOrderComponent {
  private readonly fb = inject(FormBuilder);
  private readonly orderService = inject(OrderService);
  private readonly router = inject(Router);
  
  protected readonly form = this.fb.group({
    customerId: ['', [Validators.required, Validators.minLength(3)]],
    items: this.fb.array([]),
    notes: ['', Validators.maxLength(500)]
  });
  
  protected get items(): FormArray {
    return this.form.get('items') as FormArray;
  }
  
  protected addItem(): void {
    this.items.push(this.fb.group({
      productId: ['', Validators.required],
      quantity: [1, [Validators.required, Validators.min(1)]]
    }));
  }
  
  protected submit(): void {
    if (this.form.invalid) return;
    
    this.orderService.createOrder(this.form.getRawValue())
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: (order) => this.router.navigate(['/orders', order.id]),
        error: (err) => this.handleError(err)
      });
  }
  
  private readonly destroyRef = inject(DestroyRef);
}
```

**Rules:**
- Always call `takeUntilDestroyed(this.destroyRef)` on subscriptions in components.
- Never use `async/await` for HTTP in Angular — use `Observable` + operators.
- Validate at `form.invalid` level before submit — never check individual fields manually.

---

## HTTP Client & Interceptors

```typescript
// Functional interceptor (Angular 15+)
export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const authService = inject(AuthService);
  const token = authService.getAccessToken();
  
  if (!token) return next(req);
  
  const authReq = req.clone({
    setHeaders: { Authorization: `Bearer ${token}` }
  });
  
  return next(authReq).pipe(
    catchError((error: HttpErrorResponse) => {
      if (error.status === 401) {
        return authService.refreshToken().pipe(
          switchMap((newToken) => {
            const retryReq = req.clone({
              setHeaders: { Authorization: `Bearer ${newToken}` }
            });
            return next(retryReq);
          }),
          catchError(() => {
            authService.logout();
            return throwError(() => error);
          })
        );
      }
      return throwError(() => error);
    })
  );
};

// Registration in app.config.ts
export const appConfig: ApplicationConfig = {
  providers: [
    provideHttpClient(withInterceptors([authInterceptor, loggingInterceptor]))
  ]
};
```

---

## Routing (Lazy Loading)

```typescript
// app.routes.ts
export const routes: Routes = [
  {
    path: 'orders',
    loadChildren: () => import('./features/orders/orders.routes').then(m => m.ORDERS_ROUTES),
    canActivate: [authGuard]
  },
  { path: '', redirectTo: 'orders', pathMatch: 'full' }
];

// Functional guard
export const authGuard: CanActivateFn = () => {
  const authService = inject(AuthService);
  const router = inject(Router);
  
  if (authService.isAuthenticated()) return true;
  
  return router.createUrlTree(['/login']);
};
```

**Always lazy-load feature routes.** Every feature module loaded eagerly is dead weight on initial bundle.

---

## Service Architecture

```typescript
@Injectable({ providedIn: 'root' })
export class OrderService {
  private readonly http = inject(HttpClient);
  private readonly errorHandler = inject(ErrorHandlerService);
  
  // State
  private readonly _orders = signal<Order[]>([]);
  readonly orders = this._orders.asReadonly();
  
  loadOrders(): Observable<void> {
    return this.http.get<OrderDto[]>('/api/orders').pipe(
      map(dtos => dtos.map(toOrder)),    // DTO → domain model mapping
      tap(orders => this._orders.set(orders)),
      map(() => void 0),
      catchError(this.errorHandler.handle)
    );
  }
}
```

**Service rules:**
- Services provided in `'root'` are singletons — appropriate for app-wide state.
- Services provided in a `Component` are scoped to that component tree and destroyed with it.
- Never inject `HttpClient` in a component — always through a service.
