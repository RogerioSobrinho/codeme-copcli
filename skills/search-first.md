---
name: search-first
description: Research-before-coding workflow. Before writing any implementation, search for existing solutions, documentation, and patterns. Prevents reinventing the wheel and aligns with established conventions.
tools: ["Read", "Bash", "Grep", "Glob"]
model: claude-sonnet-4-5
activation: ["search first", "research before coding", "look up docs", "find existing", "check before implementing"]
---

# Search First

## Purpose

Enforces the research-before-coding discipline: never implement what already exists. Defines a structured search order — codebase → project dependencies → Spring Boot autoconfiguration → documentation — with a concrete decision gate. Prevents duplicate implementations, unnecessary dependencies, and reinvention of utilities provided by the Java standard library or Spring ecosystem.

---

## The Rule

**Before writing a single line of implementation, search for what already exists.**

The cost of a 5-minute search is always lower than the cost of maintaining a duplicate implementation, fixing a subtle divergence, or explaining why two implementations of the same concept coexist.

---

## Search Order

Execute in this exact order. Stop at the first match.

```
1. Existing codebase
   → Does this functionality already exist in THIS project?

2. Project dependencies (pom.xml / build.gradle)
   → Is there an already-declared library that provides this?

3. Spring Boot autoconfiguration
   → Does Spring Boot already configure this automatically?

4. Java standard library
   → Is this in java.util, java.nio, java.time, etc.?

5. Documentation / well-known library
   → Is there a single-dependency solution that eliminates 50+ lines?

Decision gate (see below)
```

---

## Layer 1 — Codebase Search

### Goal
Find existing classes, utilities, or services in the current project.

### Search Patterns
```bash
# Find existing service implementations
grep -r "class.*Service\b" src/main --include="*.java" -l

# Find existing utility classes
find src/main -name "*Util*" -o -name "*Helper*" -o -name "*Utils*"

# Find existing implementations of an interface
grep -r "implements.*Repository\|implements.*Service" src/main --include="*.java"

# Find existing usage of a concept (e.g., "pagination")
grep -ri "pageable\|Page<\|Slice<" src/main --include="*.java" -l

# Find existing exception hierarchy
find src/main -name "*Exception.java" | head -20
```

### What to Check
- Service classes that may already handle the domain
- Utility/helper classes (StringUtils, DateUtils, etc.)
- Existing validators or converters
- Existing event types or DTOs

### Decision
**Found:** Use or extend the existing implementation. Do NOT create a duplicate. If the existing implementation is insufficient, refactor it — do not bypass it.

---

## Layer 2 — Project Dependencies

### Goal
Check whether a declared dependency already provides the needed functionality.

### Search Patterns
```bash
# List all dependencies
mvn dependency:list | grep -v "test\|provided" | sort

# Check if a specific library is present
grep -E "spring-boot-starter|commons-lang|guava|apache" pom.xml

# Check transitive dependencies for a library
mvn dependency:tree | grep "commons\|guava\|jackson"
```

### Common Providers to Check Before Implementing

| Need | Already Provided By |
|---|---|
| String manipulation | `org.apache.commons:commons-lang3` → `StringUtils` |
| Collection utilities | `java.util.Collections`, `java.util.stream.Collectors` |
| Date/time | `java.time.*` (Java 8+) — never use `java.util.Date` |
| JSON serialization | `jackson-databind` (via `spring-boot-starter-web`) |
| HTTP client | `spring-boot-starter-web` → `RestTemplate` / `WebClient` |
| Retry logic | `spring-retry` → `@Retryable` |
| Caching | `spring-boot-starter-cache` → `@Cacheable` |
| Validation | `spring-boot-starter-validation` → `@Valid`, `@NotNull` |
| Pagination | Spring Data → `Pageable`, `Page<T>` |
| UUIDs | `java.util.UUID` |
| Encryption | `spring-security-crypto` → `BCryptPasswordEncoder` |

### Decision
**Found:** Use the provided utility. Do NOT wrap it in a custom class unless adding significant project-specific behavior.

---

## Layer 3 — Spring Boot Autoconfiguration

### Goal
Verify that Spring Boot does not already configure the functionality automatically.

### How to Check
```bash
# List all autoconfigured beans matching a concept
grep -r "AutoConfiguration\|@ConditionalOnMissingBean" \
  ~/.m2/repository/org/springframework/boot/spring-boot-autoconfigure*/ \
  --include="*.java" -l 2>/dev/null | grep -i "cache\|security\|data\|web"

# In the running application (Actuator)
curl http://localhost:8080/actuator/beans | python3 -m json.tool | grep -i "pool\|cache\|security"
```

### Common Autoconfigured Beans
| Bean | Trigger |
|---|---|
| `DataSource` | `spring-boot-starter-data-jpa` + datasource properties |
| `HikariCP pool` | `spring-boot-starter-data-jpa` |
| `EntityManagerFactory` | JPA starter |
| `ObjectMapper` (Jackson) | `spring-boot-starter-web` |
| `PasswordEncoder` | Spring Security (if no `PasswordEncoder` bean defined) |
| `RestTemplate` / `WebClient.Builder` | Web starter |
| `CacheManager` | `spring-boot-starter-cache` + cache provider |
| `KafkaTemplate` | `spring-kafka` |

### Decision
**Autoconfigured:** Use the existing bean via `@Autowired` or constructor injection. Define a custom `@Bean` ONLY to override default configuration.

---

## Layer 4 — Java Standard Library

### Check Before Adding a Dependency

```bash
# Is this in the JDK?
javadoc search: https://docs.oracle.com/en/java/javase/21/docs/api/
```

### Common Reimplementations to Avoid

| What Developers Reinvent | Actual Solution |
|---|---|
| Null-safe string operations | `java.util.Optional`, `Objects.requireNonNullElse()` |
| UUID generation | `UUID.randomUUID()` |
| Base64 encoding | `java.util.Base64` |
| File reading | `java.nio.file.Files.readString(Path)` |
| Date formatting | `java.time.format.DateTimeFormatter` |
| Collections shuffling | `java.util.Collections.shuffle()` |
| Min/Max of a collection | `Collections.min()`, `stream().max(Comparator)` |
| String joining | `String.join()`, `Collectors.joining()` |

---

## Decision Gate

After completing all search layers, apply this decision:

### Found in Codebase (Layer 1)
→ **Reuse or extend** the existing implementation.
→ If it needs modification, refactor it with proper tests.
→ **Do NOT create a parallel implementation.**

### Found in Dependency (Layer 2 or 3)
→ **Use the provided utility directly.**
→ If a wrapper is warranted (e.g., to add logging or metrics), create a thin facade, not a reimplementation.
→ **Do NOT add a new dependency that duplicates an existing one.**

### Not Found — Implementation Required
→ **Implement the minimal solution** that solves today's problem.
→ Follow YAGNI: no speculative features.
→ Add tests before or alongside implementation.
→ Document WHY a custom implementation was needed (not available in existing stack).

### External Library Considered
Apply the dependency cost check:
```
Does this library:
1. Replace ≥ 50 lines of non-trivial code? (worth considering)
2. Have >1000 GitHub stars and active maintenance? (stability check)
3. Not conflict with existing transitive dependencies? (mvn dependency:tree check)
4. Have a compatible license (Apache 2.0, MIT, etc.)?

If all YES → add as a considered dependency (get explicit approval for production services)
If any NO → implement minimally without the dependency
```

---

## Anti-patterns — Reinvention Hall of Shame

| Anti-pattern | What Was Available |
|---|---|
| Custom `Optional`-like wrapper | `java.util.Optional` (Java 8+) |
| Custom string join utility | `String.join()`, `StringJoiner` |
| Custom base64 encoder | `java.util.Base64` |
| Custom retry mechanism | `spring-retry` `@Retryable` |
| Custom pagination DTO | Spring Data `Page<T>` |
| Custom BCrypt implementation | `spring-security-crypto` `BCryptPasswordEncoder` |
| Custom UUID validator | `UUID.fromString()` in a try/catch |
| Custom `@Transactional` analog | Spring's `@Transactional` |
| Custom `ObjectMapper` instance per class | Injected Spring-managed `ObjectMapper` bean |

---

## Standalone Invocation (No Orchestrator)

This agent can be invoked directly without the orchestrator. When `.copilot-runtime/artifacts/context.json` is absent, three options are available:

**Option 1 — Run Diagnostic Commands Directly**
Execute targeted commands to gather context on the fly:
- `grep -r "class.*Util\|class.*Helper" src/main --include="*.java" | head -20`
- `mvn dependency:list | grep -v test | sort | head -30`
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
