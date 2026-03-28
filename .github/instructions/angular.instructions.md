# Angular (Angular 17+)

## Standalone Components (Default)

All new components, directives, and pipes are **standalone**. Do not use `NgModule` for new code.

```typescript
@Component({
  selector: 'app-order-list',
  standalone: true,
  imports: [RouterLink, OrderCardComponent],
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `
    @if (orders().length > 0) {
      @for (order of orders(); track order.id) {
        <app-order-card [order]="order" (cancel)="onCancel($event)" />
      }
    } @else {
      <p>No orders found.</p>
    }
  `
})
export class OrderListComponent {
  private readonly orderService = inject(OrderService);
  protected readonly orders = this.orderService.orders; // Signal<Order[]>
}
```

## Dependency Injection: `inject()` over Constructor

Use `inject()` function — not constructor parameter injection:

```typescript
// GOOD
export class OrderService {
  private readonly http = inject(HttpClient);
  private readonly router = inject(Router);
}

// AVOID for new code (verbose, no benefit)
constructor(private http: HttpClient, private router: Router) {}
```

## Signals First (Angular 17+)

Prefer signals over manual subscriptions for component state:

```typescript
// State with signals
protected readonly count = signal(0);
protected readonly doubled = computed(() => this.count() * 2);

// Effect for side effects
effect(() => { console.log('count changed:', this.count()); });
```

Use RxJS for async data streams (HTTP, WebSockets, complex event orchestration). Use `takeUntilDestroyed()` to auto-unsubscribe:

```typescript
this.orderService.orders$.pipe(
  takeUntilDestroyed(this.destroyRef)
).subscribe(orders => this.orders.set(orders));
```

## Change Detection: OnPush Always

Default all new components to `ChangeDetectionStrategy.OnPush`. Only use `Default` if there is a specific, documented reason.

## Routing: Functional Guards (Angular 15+)

```typescript
export const authGuard: CanActivateFn = (route, state) => {
  const authService = inject(AuthService);
  const router = inject(Router);
  if (authService.isAuthenticated()) return true;
  return router.createUrlTree(['/login'], { queryParams: { returnUrl: state.url } });
};

export const routes: Routes = [
  { path: 'orders', component: OrderListComponent, canActivate: [authGuard] }
];
```

## Security

- Use Angular's built-in template binding (`{{ }}`, `[property]`) — it auto-escapes HTML.
- Never use `[innerHTML]` with untrusted input — use `DomSanitizer.sanitize()` if unavoidable.
- Never use `bypassSecurityTrust*` without explicit security review.
- Store tokens in `httpOnly` cookies — never in `localStorage` for sensitive data.
- Use `HttpClient` interceptors for token attachment and refresh logic.

## HTTP Interceptors (Functional, Angular 15+)

```typescript
export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const authService = inject(AuthService);
  const token = authService.getToken();
  if (!token) return next(req);
  return next(req.clone({ setHeaders: { Authorization: `Bearer ${token}` } }));
};
```

## Reactive Forms

- Use `FormBuilder` and `FormGroup` for complex forms
- Always add validators at definition time — not dynamically unless required
- Use `form.getRawValue()` (not `form.value`) when the form may have disabled controls

## Code Quality

- Smart/dumb component split: smart components inject services; dumb components receive `@Input()` and emit `@Output()`
- No business logic in templates — move to component class or service
- Pipes for pure transformations; avoid method calls in templates (re-evaluated every change detection cycle)
