---
name: debugging-playbook
description: >
  Load when reading a Java stack trace to identify root cause, diagnosing a
  NullPointerException, LazyInitializationException, BeanCreationException, or
  ContextRefreshException in Spring Boot, using Spring Boot Actuator endpoints
  (/actuator/env, /actuator/beans, /actuator/conditions, /actuator/loggers) to diagnose
  a runtime issue, configuring JDWP remote debug for a JVM in Docker, reading a thread dump
  to find deadlocks or blocked threads, or when asked "how do I debug this", "what does this
  stack trace mean", "why is the application context not starting", "how do I attach a
  debugger to this Docker container".
---

# Debugging Playbook

## Step 1 — Read the Stack Trace

Find the **root cause**, not the top frame. The top frame is often a framework wrapper.

```
org.springframework.web.util.NestedServletException: Handler dispatch failed
  at org.springframework.web.servlet.DispatcherServlet.noHandlerFound(...)  ← framework noise
  ...
Caused by: org.hibernate.LazyInitializationException: could not initialize proxy  ← THIS
  at org.hibernate.proxy.AbstractLazyInitializer.initialize(...)
  at com.example.orders.service.OrderService.getOrderDetails(OrderService.java:47)  ← YOUR CODE
```

**Rule:** Scroll down to the last `Caused by:` — that is the actual failure.

---

## Common Spring Boot Exceptions — Root Causes

### `LazyInitializationException`

```
org.hibernate.LazyInitializationException: failed to lazily initialize a collection
of role: com.example.Order.items, could not initialize proxy - no Session
```

**Root cause:** Accessing a lazy collection outside of a transaction — the Hibernate session is closed.

**Where to look:** The line in YOUR code that accesses `order.getItems()`. Is it inside a `@Transactional` method? Or are you accessing it after the transaction has already committed (e.g., in a controller or DTO mapper)?

**Fixes:**
1. Move the access inside a `@Transactional` service method
2. Use a JOIN FETCH query: `SELECT o FROM Order o JOIN FETCH o.items WHERE o.id = :id`
3. Use a projection/DTO that fetches only what you need

---

### `BeanCreationException`

```
org.springframework.beans.factory.BeanCreationException: Error creating bean with name 'orderService'
...
Caused by: org.springframework.beans.factory.UnsatisfiedDependencyException
...
Caused by: org.springframework.beans.factory.NoSuchBeanDefinitionException: No qualifying bean of type 'com.example.PaymentClient'
```

**Root cause:** A dependency can't be found. Follow the `Caused by` chain to the missing bean.

**Checklist:**
- Is the missing class annotated with `@Service`, `@Component`, `@Repository`?
- Is it in a package scanned by `@SpringBootApplication`? (Must be in a subpackage of the main class)
- Is there a `@Profile` condition preventing it from loading in this environment?
- Is there a `@ConditionalOn*` that evaluates to false?

**Diagnose with Actuator:**
```bash
curl http://localhost:8080/actuator/conditions | jq '.positiveMatches | keys'   # what loaded
curl http://localhost:8080/actuator/conditions | jq '.negativeMatches | keys'   # what didn't load
```

---

### `ContextRefreshException` / Application fails to start

```
Application failed to start
  ...
Caused by: java.lang.IllegalStateException: Failed to load ApplicationContext
```

**Checklist (in order):**
1. Check the FULL stack trace — the root cause is buried deep
2. Check `application.yml` syntax — YAML is whitespace-sensitive
3. Check required properties: `@Value("${some.property}")` — is it set in config?
4. Check datasource config — can the app reach the database?
5. Check circular dependencies: `The dependencies of some of the beans in the application context form a cycle`

**Find missing properties:**
```bash
grep -r "@Value" src/main/java --include="*.java" | grep -v "test"
# Cross-reference with application.yml
```

---

### `NullPointerException` in Spring Code

```
java.lang.NullPointerException: Cannot invoke "com.example.Order.getId()" because "order" is null
  at com.example.OrderService.processOrder(OrderService.java:83)
```

Java 17+ NPEs include the null reference in the message. Read it literally: `order` is null at line 83.

**Common Spring causes:**
- Repository returns `Optional` but code calls `.get()` without checking
- `@Autowired` field is null — the class was instantiated via `new` instead of Spring (not a bean)
- `@MockBean` not set up in a test — returns null by default

---

## Spring Boot Actuator Debugging Endpoints

Enable for debugging (dev/staging only — never expose in prod without auth):

```yaml
# application-local.yml
management:
  endpoints:
    web:
      exposure:
        include: "*"
  endpoint:
    health:
      show-details: always
```

### Endpoints

```bash
# What properties are loaded (and from where)?
curl http://localhost:8080/actuator/env | jq '.'

# Find a specific property
curl http://localhost:8080/actuator/env | jq '.propertySources[].properties."spring.datasource.url"'

# What beans are loaded?
curl http://localhost:8080/actuator/beans | jq '.contexts[].beans | keys'

# Find a specific bean
curl http://localhost:8080/actuator/beans | jq '.. | objects | .type? // empty' | grep -i "OrderService"

# What auto-configuration loaded or was excluded?
curl http://localhost:8080/actuator/conditions | jq '.'

# Change a log level at runtime (no restart)
curl -X POST http://localhost:8080/actuator/loggers/com.example.orders \
  -H 'Content-Type: application/json' \
  -d '{"configuredLevel": "DEBUG"}'

# Current thread state
curl http://localhost:8080/actuator/threaddump | jq '.'

# Heap info
curl http://localhost:8080/actuator/metrics/jvm.memory.used | jq '.'
```

---

## Remote Debug — Attach IDE to JVM in Docker

### JVM flags

```bash
# Start JVM with debug port open
java -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005 -jar app.jar
```

`suspend=n` — app starts immediately (doesn't wait for debugger to attach)  
`suspend=y` — app pauses until debugger attaches (useful for startup issues)

### Docker Compose

```yaml
services:
  app:
    environment:
      JAVA_TOOL_OPTIONS: "-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:5005"
    ports:
      - "8080:8080"
      - "5005:5005"   # Debug port
```

### IDE (IntelliJ IDEA)

Run → Edit Configurations → Add → Remote JVM Debug  
Host: `localhost`, Port: `5005`, Debugger mode: `Attach to remote JVM`

---

## Thread Dump Analysis

Trigger a thread dump:

```bash
# Send SIGQUIT to the JVM (prints to stdout)
kill -3 <pid>

# Via Actuator
curl http://localhost:8080/actuator/threaddump > thread-dump.json

# jstack
jstack <pid> > thread-dump.txt
```

**What to look for:**

| Pattern | Meaning |
|---|---|
| Many threads in `BLOCKED` state | Lock contention — find the thread holding the lock |
| Threads in `WAITING` on `@Scheduled` | Normal — threads waiting for their next scheduled run |
| `DEADLOCK` in dump | Two threads blocked on each other — fix lock ordering |
| All threads waiting on same monitor | Single-threaded bottleneck — needs async or pool tuning |
| Pool threads all `RUNNING` on same code | Hot path — candidate for optimization |

**Deadlock detection:**

```bash
# jstack will explicitly call out deadlocks
jstack <pid> | grep -A 20 "Found.*deadlock"
```

---

## Heap Analysis — OOM Diagnosis

Trigger heap dump before the OOM kills the process:

```bash
# JVM flag — auto-dump on OOM
JAVA_TOOL_OPTIONS="-XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/tmp/heap-$(date +%s).hprof"

# Manual dump
jmap -dump:format=b,file=heap.hprof <pid>
```

Analyze with Eclipse MAT or VisualVM. What to look for:
- **Retained heap** — objects keeping large amounts of memory alive
- **Dominator tree** — the root objects responsible for most memory
- **Unreachable objects** — GC pressure from short-lived allocation spikes

**Quick diagnosis from logs:**

```bash
# Find GC pressure
grep -i "GC overhead\|OutOfMemoryError\|PermGen\|Metaspace" app.log

# Find retained caches
grep -i "CaffeineCache\|EhCache\|loadingCache" app.log
```

---

## Diagnostic Quick Reference

| Symptom | First action |
|---|---|
| App won't start | Read `Caused by` at bottom of stack trace |
| `LazyInitializationException` | Add `@Transactional` or use JOIN FETCH |
| `NoSuchBeanDefinitionException` | Check annotation + package scan |
| NPE on injected field | Class probably created with `new` — not a Spring bean |
| Slow response, no error | Check `/actuator/threaddump` for blocked threads |
| Memory leak / OOM | Enable `-XX:+HeapDumpOnOutOfMemoryError`, analyze with MAT |
| Property not loading | Check `/actuator/env` — is the profile active? |
| `DataAccessException` | Check datasource URL, credentials, and DB migrations |
