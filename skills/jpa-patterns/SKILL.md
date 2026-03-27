---
name: jpa-patterns
description: JPA/Hibernate patterns for Spring Boot. Covers N+1 prevention, projections, pagination, custom queries, entity lifecycle, auditing, optimistic locking, and common pitfalls. Load when working with Spring Data JPA or Hibernate.
---

# JPA Patterns

## Entity Design

```java
@Entity
@Table(name = "orders")
public class Order {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "order_seq")
    @SequenceGenerator(name = "order_seq", sequenceName = "order_seq", allocationSize = 50)
    private Long id;

    @Column(nullable = false, unique = true)
    private UUID externalId;  // business key

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof Order other)) return false;
        return externalId != null && externalId.equals(other.externalId);
    }

    @Override
    public int hashCode() { return getClass().hashCode(); }
}
```

**Rules:** Always implement `equals`/`hashCode` on the **business key** (not `@Id`). Use `SEQUENCE` strategy — `IDENTITY` disables batch inserts. Prefer surrogate keys.

---

## Relationships — FetchType.LAZY Mandatory

```java
@OneToMany(mappedBy = "order", fetch = FetchType.LAZY, cascade = CascadeType.ALL, orphanRemoval = true)
private List<OrderItem> items = new ArrayList<>();

@ManyToOne(fetch = FetchType.LAZY, optional = false)
@JoinColumn(name = "customer_id", nullable = false)
private Customer customer;
```

For `@ManyToMany` with extra columns: use an explicit join entity with two `@ManyToOne` — never raw `@ManyToMany`.

Bidirectional helper methods:
```java
public void addItem(OrderItem item) { items.add(item); item.setOrder(this); }
public void removeItem(OrderItem item) { items.remove(item); item.setOrder(null); }
```

---

## N+1 Prevention

### @EntityGraph
```java
@EntityGraph(attributePaths = {"items", "items.product"})
@Query("SELECT o FROM Order o WHERE o.customerId = :customerId")
List<Order> findWithItemsByCustomerId(@Param("customerId") UUID customerId);
```

### JOIN FETCH
```java
@Query("SELECT DISTINCT o FROM Order o JOIN FETCH o.items i JOIN FETCH i.product WHERE o.status = :status")
List<Order> findWithItemsByStatus(@Param("status") OrderStatus status);
```

### @BatchSize (legacy code fix)
```java
@OneToMany(mappedBy = "order", fetch = FetchType.LAZY)
@BatchSize(size = 25)
private List<OrderItem> items;
```

| Scenario | Solution |
|---|---|
| Repository method needs related data | `@EntityGraph` |
| Complex filtering + eager load | `JOIN FETCH` |
| Cannot change queries | `@BatchSize` |
| Never | `FetchType.EAGER` |

---

## Projections

### Interface Projection
```java
public interface OrderSummary {
    UUID getExternalId();
    String getCustomerName();
    BigDecimal getTotalAmount();
}
List<OrderSummary> findByStatus(OrderStatus status);
```

### DTO Projection (Constructor Expression)
```java
@Query("SELECT new com.example.dto.OrderSummaryDto(o.externalId, c.name, o.totalAmount) " +
       "FROM Order o JOIN o.customer c WHERE o.status = :status")
List<OrderSummaryDto> findSummaryByStatus(@Param("status") OrderStatus status);
```

---

## Pagination

### `Page<T>` — when total count is needed (2 queries: data + COUNT)
```java
Page<Order> findByStatus(OrderStatus status, Pageable pageable);
```

### `Slice<T>` — infinite scroll (1 query, has `hasNext()`, no total count)
```java
Slice<Order> findByStatus(OrderStatus status, Pageable pageable);
```

### Optimize COUNT with `countQuery`
```java
@Query(value = "SELECT o FROM Order o JOIN FETCH o.items WHERE o.status = :status",
       countQuery = "SELECT COUNT(o) FROM Order o WHERE o.status = :status")
Page<Order> findWithItemsByStatus(@Param("status") OrderStatus status, Pageable pageable);
```

**Critical:** `JOIN FETCH` + `Pageable` causes Hibernate to paginate in-memory. Always use `countQuery` and replace `JOIN FETCH` with `@EntityGraph` for paginated queries.

---

## Optimistic Locking

```java
@Entity
public class Account {
    @Version
    private Long version;  // incremented on every update; throws OptimisticLockingFailureException on conflict
}
```

Required on any entity updated by concurrent requests. Handle `OptimisticLockingFailureException` in the service layer with a retry or conflict response.

---

## Auditing

```java
@Configuration
@EnableJpaAuditing
public class JpaAuditingConfig { }

@MappedSuperclass
@EntityListeners(AuditingEntityListener.class)
public abstract class Auditable {
    @CreatedDate
    @Column(nullable = false, updatable = false)
    private Instant createdAt;

    @LastModifiedDate
    private Instant updatedAt;

    @CreatedBy
    private String createdBy;
}
```

---

## Specifications (Dynamic Queries)

```java
public class OrderSpecifications {
    public static Specification<Order> hasStatus(OrderStatus status) {
        return (root, query, cb) -> cb.equal(root.get("status"), status);
    }

    public static Specification<Order> createdAfter(LocalDate date) {
        return (root, query, cb) -> cb.greaterThanOrEqualTo(root.get("createdAt"), date.atStartOfDay());
    }
}

// Usage
var spec = hasStatus(PENDING).and(createdAfter(LocalDate.now().minusDays(7)));
orderRepository.findAll(spec, PageRequest.of(0, 20));
```

---

## Common Pitfalls

| Pitfall | Fix |
|---|---|
| `FetchType.EAGER` on `@OneToMany` | Always use `LAZY`; use `@EntityGraph` at query time |
| `findAll()` on large tables | Always add `Pageable` |
| `Optional.get()` without check | Use `orElseThrow()` with a domain exception |
| Saving entities in a loop | Use `saveAll()` with batch insert enabled |
| `equals()` based on `@Id` | Use business key; `@Id` is null for transient entities |
| `@Transactional` on domain entities | Transaction belongs in application/service layer |
