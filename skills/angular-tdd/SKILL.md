---
name: angular-tdd
description: >
  Load when writing Angular unit tests (TestBed, ComponentFixture), integration tests for
  services (HttpClientTestingModule, HttpTestingController), testing components with
  Spectator or Angular Testing Library, testing reactive forms validation, testing signal-based
  components, testing RxJS streams with marble testing, or when asked "how do I test this
  Angular component", "how do I mock this service in a test", "how do I test this HTTP call".
---

# Angular TDD

## Testing Pyramid for Angular

```
          [E2E — Playwright/Cypress]
         [Integration — TestBed + HTTP mocks]
    [Unit — Isolated class tests with MockitoEquivalent]
```

Unit tests: the vast majority. TestBed integration tests: for component behavior that depends on template rendering.

---

## Component Tests with TestBed

```typescript
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { signal } from '@angular/core';
import { By } from '@angular/platform-browser';
import { OrderListComponent } from './order-list.component';
import { OrderService } from '../services/order.service';

describe('OrderListComponent', () => {
  let fixture: ComponentFixture<OrderListComponent>;
  let mockOrderService: jasmine.SpyObj<OrderService>;

  const mockOrders: Order[] = [
    { id: '1', customerId: 'c1', status: 'PENDING', totalAmount: 100 },
    { id: '2', customerId: 'c2', status: 'SHIPPED', totalAmount: 200 }
  ];

  beforeEach(async () => {
    mockOrderService = jasmine.createSpyObj('OrderService', ['cancelOrder'], {
      orders: signal(mockOrders)  // Spy on signal property
    });

    await TestBed.configureTestingModule({
      imports: [OrderListComponent],
      providers: [
        { provide: OrderService, useValue: mockOrderService }
      ]
    }).compileComponents();

    fixture = TestBed.createComponent(OrderListComponent);
    fixture.detectChanges();
  });

  it('renders an order card for each order', () => {
    const cards = fixture.debugElement.queryAll(By.css('app-order-card'));
    expect(cards.length).toBe(2);
  });

  it('calls cancelOrder when cancel event emits', () => {
    const card = fixture.debugElement.query(By.css('app-order-card'));
    card.triggerEventHandler('cancel', '1');
    
    expect(mockOrderService.cancelOrder).toHaveBeenCalledWith('1');
  });

  it('shows empty state when no orders', async () => {
    mockOrderService = jasmine.createSpyObj('OrderService', ['cancelOrder'], {
      orders: signal([])
    });
    
    await TestBed.overrideProvider(OrderService, { useValue: mockOrderService });
    fixture.detectChanges();
    
    expect(fixture.nativeElement.querySelector('p').textContent).toContain('No orders found');
  });
});
```

---

## Service Tests with HttpClientTestingModule

```typescript
import { TestBed } from '@angular/core/testing';
import { HttpClientTestingModule, HttpTestingController } from '@angular/common/http/testing';
import { OrderService } from './order.service';

describe('OrderService', () => {
  let service: OrderService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [HttpClientTestingModule],
      providers: [OrderService]
    });
    
    service = TestBed.inject(OrderService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify(); // Ensures no unexpected requests
  });

  it('loads orders and updates the signal', () => {
    const mockDtos: OrderDto[] = [{ id: '1', customer_id: 'c1', status: 'PENDING', total: 100 }];

    service.loadOrders().subscribe();

    const req = httpMock.expectOne('/api/orders');
    expect(req.request.method).toBe('GET');
    req.flush(mockDtos);

    expect(service.orders().length).toBe(1);
    expect(service.orders()[0].customerId).toBe('c1'); // Verify DTO → domain mapping
  });

  it('handles 401 by triggering logout', () => {
    // Arrange
    const logoutSpy = spyOn(TestBed.inject(AuthService), 'logout');

    // Act
    service.loadOrders().subscribe({ error: () => {} });
    httpMock.expectOne('/api/orders').flush('Unauthorized', {
      status: 401,
      statusText: 'Unauthorized'
    });

    // Assert
    expect(logoutSpy).toHaveBeenCalled();
  });
});
```

---

## Reactive Form Tests

```typescript
describe('CreateOrderComponent form validation', () => {
  let component: CreateOrderComponent;
  let fixture: ComponentFixture<CreateOrderComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [CreateOrderComponent, ReactiveFormsModule],
      providers: [{ provide: OrderService, useValue: mockOrderService }]
    }).compileComponents();

    fixture = TestBed.createComponent(CreateOrderComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('is invalid when customerId is empty', () => {
    component.form.get('customerId')!.setValue('');
    expect(component.form.get('customerId')!.hasError('required')).toBeTrue();
    expect(component.form.valid).toBeFalse();
  });

  it('does not submit when form is invalid', () => {
    component.form.get('customerId')!.setValue('');
    fixture.debugElement.query(By.css('button[type=submit]')).nativeElement.click();
    
    expect(mockOrderService.createOrder).not.toHaveBeenCalled();
  });

  it('calls createOrder with form values on valid submit', () => {
    mockOrderService.createOrder.and.returnValue(of({ id: 'new-1' }));
    component.form.get('customerId')!.setValue('customer-abc');
    fixture.debugElement.query(By.css('button[type=submit]')).nativeElement.click();
    
    expect(mockOrderService.createOrder).toHaveBeenCalledWith(
      jasmine.objectContaining({ customerId: 'customer-abc' })
    );
  });
});
```

---

## Signal Tests

```typescript
it('computed signal recalculates when items change', () => {
  const service = TestBed.inject(CartService);
  
  // Initial state
  expect(service.totalAmount()).toBe(0);
  expect(service.isEmpty()).toBeTrue();
  
  // Act
  service.addItem({ id: 'p1', price: 50, quantity: 2 });
  
  // Assert — signals update synchronously
  expect(service.totalAmount()).toBe(100);
  expect(service.isEmpty()).toBeFalse();
});
```

---

## Testing with Spectator (Recommended for Complex Components)

```typescript
import { createComponentFactory, Spectator } from '@ngneat/spectator';

describe('OrderCardComponent (Spectator)', () => {
  let spectator: Spectator<OrderCardComponent>;
  
  const createComponent = createComponentFactory({
    component: OrderCardComponent,
    providers: [mockProvider(OrderService)],
    detectChanges: false
  });

  beforeEach(() => {
    spectator = createComponent({ props: { order: mockOrder } });
    spectator.detectChanges();
  });

  it('displays order id', () => {
    expect(spectator.query('.order-id')).toHaveText(mockOrder.id);
  });

  it('emits cancel with order id on button click', () => {
    const cancelSpy = spyOn(spectator.component.cancel, 'emit');
    spectator.click('.cancel-button');
    expect(cancelSpy).toHaveBeenCalledWith(mockOrder.id);
  });
});
```

---

## What NOT to Test

- Template HTML structure for its own sake (fragile, low value)
- Angular's own binding mechanics (`[class.active]` wires up correctly — trust Angular)
- Private methods — test their effects through public API
- Implementation details of RxJS operators — test observable output, not operator choice

## Coverage Targets

| Category | Target |
|---|---|
| Services (business logic) | ≥ 90% |
| Smart components (behavior) | ≥ 80% |
| Dumb components | ≥ 60% (mostly input/output contracts) |
| Guards / resolvers | 100% |
| Interceptors | 100% |
