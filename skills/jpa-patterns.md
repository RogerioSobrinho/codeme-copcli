---
name: jpa-patterns
description: JPA/Hibernate patterns reference for Java/Spring Boot. N+1 prevention, projections, query optimization, entity lifecycle, and Spring Data JPA best practices.
tools: ["Read", "Grep", "Bash"]
model: claude-sonnet-4-5
activation: ["jpa", "hibernate", "n+1", "entity", "spring data", "repository pattern", "jpql"]
---

# JPA Patterns

## Purpose

Reference guide for JPA/Hibernate best practices within Spring Boot applications. Covers entity design, relationship mapping, N+1 query prevention, projections, pagination, custom queries, entity lifecycle hooks, optimistic locking, and auditing. Use this skill to design, review, or optimize the persistence layer of a Spring Boot service.

---

## Entity Design

### Core Rules
- Every entity must have a single `@Id` field. Composite keys are allowed but increase complexity — prefer surrogate keys.
- Implement `equals` and `hashCode` based on the **business key** (natural identifier), NOT the generated `@Id`. Using `@Id` in `equals` breaks Hibernate's identity logic for transient entities.
- Use `@Table(name = "...")` explicitly to decouple class name from table name.

### Pattern
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

### Generation Strategies
| Strategy | When |
|---|---|
| `SEQUENCE` (preferred) | PostgreSQL, Oracle — batching via `allocationSize` |
| `IDENTITY` | Auto-increment; disables batch inserts |
| `UUID` | Distributed systems; no sequence needed |

---

## Relationships — FetchType.LAZY Mandatory

### Rule
ALL `@OneToMany` and `@ManyToMany` MUST use `FetchType.LAZY`. `FetchType.EAGER` is the root cause of most N+1 and cartesian product problems.

```java
@OneToMany(mappedBy = "order", fetch = FetchType.LAZY, cascade = CascadeType.ALL, orphanRemoval = true)
private List<OrderItem> items = new ArrayList<>();

@ManyToOne(fetch = FetchType.LAZY, optional = false)
@JoinColumn(name = "customer_id", nullable = false)
private Customer customer;
```

### Bidirectional Relationship Helper Methods
```java
public void addItem(OrderItem item) {
    items.add(item);
    item.setOrder(this);  // maintain both sides
}

public void removeItem(OrderItem item) {
    items.remove(item);
    item.setOrder(null);
}
```

### `@ManyToMany` — Use Join Entity Instead
For `@ManyToMany` with extra columns, use an explicit join entity with two `@ManyToOne` associations. Raw `@ManyToMany` is difficult to extend and troubleshoot.

---

## N+1 Prevention

### The N+1 Problem
Loading 100 orders and then accessing `order.getItems()` for each = 1 query + 100 queries = 101 queries.

### Solution 1 — `@EntityGraph`
```java
@EntityGraph(attributePaths = {"items", "items.product"})
@Query("SELECT o FROM Order o WHERE o.customerId = :customerId")
List<Order> findWithItemsByCustomerId(@Param("customerId") UUID customerId);
```
**Use when:** You need to load the entity with specific associations in a given query method.

### Solution 2 — `JOIN FETCH`
```java
@Query("SELECT DISTINCT o FROM Order o JOIN FETCH o.items i JOIN FETCH i.product WHERE o.status = :status")
List<Order> findWithItemsByStatus(@Param("status") OrderStatus status);
```
**Use when:** You need precise control over the JOIN and filtering.

### Solution 3 — `@BatchSize`
```java
@OneToMany(mappedBy = "order", fetch = FetchType.LAZY)
@BatchSize(size = 25)
private List<OrderItem> items;
```
**Use when:** You cannot change the query but want to reduce N+1 from N queries to N/25 queries.

### Which to Choose
| Scenario | Solution |
|---|---|
| Repository method needs related data | `@EntityGraph` |
| Complex filtering + eager load | `JOIN FETCH` |
| Legacy code, cannot change queries | `@BatchSize` |
| Never | `FetchType.EAGER` |

---

## Projections

### Interface Projections (Spring Data)
```java
public interface OrderSummary {
    UUID getExternalId();
    String getCustomerName();
    BigDecimal getTotalAmount();
}

List<OrderSummary> findByStatus(OrderStatus status);
```
**Pros:** Spring Data generates optimized SELECT with only required columns. **Cons:** Cannot add behavior.

### DTO Projections with Constructor Expression
```java
@Query("SELECT new com.example.dto.OrderSummaryDto(o.externalId, c.name, o.totalAmount) " +
       "FROM Order o JOIN o.customer c WHERE o.status = :status")
List<OrderSummaryDto> findSummaryByStatus(@Param("status") OrderStatus status);
```
**Pros:** Full DTO control. **Cons:** Constructor must match exactly; fragile with refactoring.

### Pitfalls
- Do NOT return `@Entity` objects from REST endpoints — use projections/DTOs to avoid over-fetching and lazy loading issues in the serialization layer.

---

## Pagination — `Pageable`, `Page<T>` vs `Slice<T>`

### `Page<T>` — Use When Total Count Is Needed
```java
Page<Order> findByStatus(OrderStatus status, Pageable pageable);
```
Executes 2 queries: the data query + a `COUNT(*)` query.

### `Slice<T>` — Use for Infinite Scroll
```java
Slice<Order> findByStatus(OrderStatus status, Pageable pageable);
```
Executes 1 query. Has `hasNext()` but NO total count. More efficient for infinite scroll / cursor pagination.

### `countQuery` — Optimize COUNT
```java
@Query(value = "SELECT o FROM Order o JOIN FETCH o.items WHERE o.status = :status",
       countQuery = "SELECT COUNT(o) FROM Order o WHERE o.status = :status")
Page<Order> findWithItemsByStatus(@Param("status") OrderStatus status, Pageable pageable);
```
Without `countQuery`, Hibernate may generate an invalid COUNT with JOIN FETCH.

### Pitfalls
- Never use `findAll()` without a `Pageable` on large tables. Always paginate.
- `JOIN FETCH` + `Pageable` triggers a Hibernate warning: it loads all records into memory and paginates in-memory. Use `countQuery` and avoid `JOIN FETCH` with pagination — use `@EntityGraph` instead.

---

## Custom Queries

### JPQL vs Native
| Use Case | Preference |
|---|---|
| Standard queries | JPQL (`@Query`) — database-agnostic |
| Complex SQL, window functions, CTEs | Native (`@Query(nativeQuery = true)`) |
| Dynamic queries | Specifications or QueryDSL |

### Specifications Pattern
```java
public class OrderSpecifications {
    public static Specification<Order> hasStatus(OrderStatus status) {
        return (root, query, cb) -> cb.equal(root.get("status"), status);
    }

    public static Specification<Order> createdAfter(LocalDate date) {
        return (root, query, cb) -> cb.greaterThanOrEqualTo(root.get("createdAt"), date);
    }
}

// Usage
orderRepository.findAll(
    hasStatus(APPROVED).and(createdAfter(LocalDate.now().minusDays(30)))
);
```

---

## Entity Lifecycle — `@PrePersist`, `@PreUpdate`, `@PostLoad`

```java
@PrePersist
protected void onCreate() {
    this.createdAt = Instant.now();
    this.externalId = UUID.randomUUID();
}

@PreUpdate
protected void onUpdate() {
    this.updatedAt = Instant.now();
}

@PostLoad
protected void onLoad() {
    // Decrypt sensitive fields loaded from DB
}
```

### Pitfalls
- Do NOT inject Spring beans in lifecycle callbacks — the entity is not a Spring bean.
- Use `@EntityListeners(AuditingEntityListener.class)` + `@EnableJpaAuditing` instead of `@PrePersist` for audit fields.

---

## Auditing — `@CreatedDate`, `@LastModifiedDate`

```java
@Configuration
@EnableJpaAuditing
public class JpaConfig {}

@MappedSuperclass
@EntityListeners(AuditingEntityListener.class)
public abstract class AuditableEntity {

    @CreatedDate
    @Column(nullable = false, updatable = false)
    private Instant createdAt;

    @LastModifiedDate
    @Column(nullable = false)
    private Instant updatedAt;

    @CreatedBy
    @Column(updatable = false)
    private String createdBy;

    @LastModifiedBy
    private String updatedBy;
}
```

### AuditorAware for `@CreatedBy`
```java
@Bean
AuditorAware<String> auditorAware() {
    return () -> Optional.ofNullable(SecurityContextHolder.getContext().getAuthentication())
        .map(Authentication::getName);
}
```

---

## Optimistic Locking — `@Version`

```java
@Entity
public class Product {
    @Version
    private Long version;
}
```

### Handling `OptimisticLockException`
```java
try {
    productService.updatePrice(productId, newPrice);
} catch (OptimisticLockException | ObjectOptimisticLockingFailureException e) {
    // Reload and retry or return 409 Conflict to the client
    throw new ConcurrentModificationException("Product was modified concurrently. Retry.");
}
```

### Pitfalls
- `@Version` on `Long` is sufficient. Do NOT use `@Version` on `Timestamp` — clock skew causes false conflicts.
- Always return HTTP 409 Conflict when an optimistic lock failure reaches the API layer.

---

## Common Pitfalls

| Pitfall | Problem | Fix |
|---|---|---|
| Lazy loading in closed session | `LazyInitializationException` | Load required associations in the service layer (OPEN session) |
| Bidirectional inconsistency | Parent has child, child has no parent | Always maintain both sides with helper methods |
| Multiple bag fetches | `MultipleBagFetchException` | Use `Set` instead of `List` for `@OneToMany`, or separate queries |
| `equals` based on `@Id` | Transient entity = 0, causes `HashSet` bugs | Use business key for `equals` |
| Missing `orphanRemoval` | Orphan rows accumulate | Add `orphanRemoval = true` on `@OneToMany` where parent owns child |
| Flush mode AUTO surprise | Query auto-flushes pending writes | Be explicit about when to flush; avoid queries mid-transaction that trigger flush |

---

## Standalone Invocation (No Orchestrator)

This agent can be invoked directly without the orchestrator. When `.copilot-runtime/artifacts/context.json` is absent, three options are available:

**Option 1 — Run Diagnostic Commands Directly**
Execute targeted commands to gather context on the fly:
- `grep -r "@OneToMany\|@ManyToOne\|@ManyToMany" src/main --include="*.java" -l`
- `grep -r "FetchType.EAGER\|findAll()" src/main --include="*.java"`
- Pros: Fast, zero extra agent invocations
- Cons: Partial context; may miss cross-cutting concerns

**Option 2 — Invoke `codebase-explorer-agent` First**
Ask the user to run `codebase-explorer-agent`, wait for `.copilot-runtime/artifacts/context.json`, then re-run this agent.
- Pros: Richer, consistent context shared with all downstream agents
- Cons: Extra manual step; slightly slower

**Option 3 (RECOMMENDED) — Auto-Bootstrap then Proceed**
Invoke `codebase-explorer-agent` automatically, consume the resulting `context.json`, then continue execution without user intervention.
- Pros: Fully autonomous; deterministic context; no coordination overhead
- Cons: Slightly longer cold start
- **Why recommended:** Eliminates user coordination overhead and guarantees all agents share the same project baseline.

After context is available via any option, resume normal execution flow.
