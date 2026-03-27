---
name: search-first
description: Research-before-coding methodology for Spring Boot. Covers 5-layer search order, grep patterns per layer, dependency cost check, and anti-patterns to avoid. Load before writing any new implementation to ensure solutions reuse existing code and native framework capabilities.
---

# Search-First Methodology

## Core Principle

Before writing any new code, search the existing codebase and ecosystem to find something that already solves the problem. 95% of Spring Boot requirements are already solved by: existing project code, Spring Boot autoconfiguration, Java stdlib, or a well-known library already on the classpath.

**Rule:** Never write a utility/helper class without first verifying it doesn't already exist.

---

## 5-Layer Search Order

### Layer 1: Codebase (Always Check First)

```bash
# Find existing utilities, helpers, converters
grep -r "class.*Util\|class.*Helper\|class.*Converter\|class.*Mapper" src/main/java --include="*.java" -l

# Find existing validators
grep -r "implements.*Validator\|@Component.*Validator" src/main/java --include="*.java" -l

# Find similar method signatures
grep -rn "public.*OrderService\|private.*processOrder" src/main/java --include="*.java"

# Find existing HTTP client setup
grep -r "RestTemplate\|RestClient\|WebClient\|FeignClient" src/main/java --include="*.java" -l

# Find existing exception hierarchy
grep -r "extends.*Exception\|extends.*RuntimeException" src/main/java --include="*.java" -l
```

### Layer 2: Dependencies Already on Classpath

```bash
# What is already available?
./mvnw dependency:tree -Dincludes=org.springframework.boot:*
./mvnw dependency:tree -Dincludes=org.apache.commons:*
./mvnw dependency:tree | grep "compile\|runtime"

# Is Apache Commons Lang already available?
./mvnw dependency:tree | grep commons-lang3
# → Yes: StringUtils.isBlank(), StringUtils.truncate(), NumberUtils.isParsable() — use them

# Is Guava available?
./mvnw dependency:tree | grep guava
# → Yes: Joiner, Splitter, Preconditions, ImmutableList, etc.
```

### Layer 3: Spring Boot Autoconfiguration

```bash
# What beans does Spring Boot auto-configure?
grep -r "@ConditionalOnMissingBean\|@AutoConfiguration" ~/.m2/repository/org/springframework/boot/ --include="*.java" -l 2>/dev/null | head -20

# Check actuator metrics — already instrumented?
grep -r "MeterRegistry\|Counter\|Timer\|Gauge" src/main/java --include="*.java" -l

# What's auto-configured for this app?
curl -s http://localhost:8080/actuator/conditions | jq '.positiveMatches | keys[]' 2>/dev/null | head -40
```

Built-in Spring Boot capabilities (no extra code needed):
- `JdbcTemplate` / `NamedParameterJdbcTemplate` — injected automatically when datasource is configured
- `RestTemplate` (via `RestTemplateBuilder`) — just inject `RestTemplateBuilder`
- `ObjectMapper` — pre-configured, just inject it
- `MessageSource` — i18n, auto-configured
- `Environment` — access all properties without extra config

### Layer 4: Java Standard Library

Before adding any dependency for:
- String manipulation → `String`, `StringBuilder`, `StringJoiner`
- Collections → `List.of()`, `Map.of()`, `Set.of()`, `Collectors`, `Stream`
- Dates → `java.time.LocalDate`, `ZonedDateTime`, `DateTimeFormatter`
- IO → `Files`, `Paths`, `InputStream`, `BufferedReader`
- Concurrency → `CompletableFuture`, `ExecutorService`, `ScheduledExecutorService`

### Layer 5: External Library (Last Resort)

Only add a new dependency when:
1. Layers 1–4 confirmed nothing solves the problem
2. The library is on the [Spring Initializr curated list](https://start.spring.io) or is a well-known standard
3. The maintenance burden is justified

**Dependency cost check:**
```bash
# Check for transitive conflicts before adding
./mvnw dependency:analyze -DignoreNonCompile=true | grep "WARNING"

# Check artifact size
./mvnw help:evaluate -Dexpression=project.dependencies -q
```

---

## Anti-Patterns — Hall of Shame

| What Was Written | What Should Have Been Used |
|---|---|
| `class StringHelper { isEmpty(str) ... }` | `String.isBlank()` (Java 11+) |
| `class DateUtil { format(date) ... }` | `DateTimeFormatter` + `LocalDate` |
| `class CollectionUtils { isEmpty(col) ... }` | `CollectionUtils.isEmpty()` from Spring itself |
| New HTTP client class wrapping RestTemplate | Inject `RestTemplateBuilder` directly |
| Custom retry loop with Thread.sleep | `@Retryable` from Spring Retry |
| Manual JSON serialization | `ObjectMapper` (already configured) |
| Custom property reader | `@Value` or `@ConfigurationProperties` |
| Custom base64 encoder | `Base64.getEncoder()` from `java.util` |
| Custom UUID generator | `UUID.randomUUID()` |

---

## Quick Decision Rule

```
Does the codebase already have this?  → Use it, don't duplicate
Is it a Spring built-in capability?    → Use @annotation or inject the bean
Is it in java.util/java.io/java.time? → Use the stdlib, no import needed
Is it in a dependency already present? → Use it, zero extra cost
→ Only NOW consider adding a new dependency
```
