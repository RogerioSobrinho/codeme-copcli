---
name: verification-loop
description: >
  Load when setting up a quality gate sequence, defining done criteria for a feature or
  bug fix, running the full verification pipeline (compile → unit test → integration test →
  coverage check → security scan), diagnosing which gate is failing and why, or when the
  user says "verify this", "is this ready to merge", "run the full check", or
  "what's the definition of done here".
---

# Verification Loop

A verification loop is a repeatable, ordered sequence of quality gates. The rule is simple: **never advance past a red gate.** If a gate fails, fix it before running the next one.

## The Gate Sequence

```
compile → unit tests → integration tests → coverage → security scan → contract tests
```

Each gate depends on the previous. Skipping gates hides bugs. Running them in parallel masks root causes.

---

## Gate 1 — Compile

```bash
# Maven
./mvnw compile -q

# Gradle
./gradlew compileJava
```

**Pass criteria:** Zero compilation errors.  
**On failure:** Fix before anything else. A red compile gate means nothing else will tell you the truth.

---

## Gate 2 — Unit Tests

```bash
# Maven
./mvnw test -q

# Gradle
./gradlew test
```

**Pass criteria:** All tests green. No skipped tests (`@Disabled`, `@Ignore`) unless explicitly justified with a ticket reference.

**On failure:** Read the stack trace. Common causes:
- `NullPointerException` → missing mock setup (`when(mock.method()).thenReturn(...)`)
- `BeanCreationException` → test slice missing required bean (`@MockBean` for dependencies)
- `AssertionError` → actual behavior changed; either the code or the test is wrong

---

## Gate 3 — Integration Tests

```bash
# Maven — includes @SpringBootTest, @DataJpaTest, Testcontainers
./mvnw verify -DskipUnitTests=true -q

# Or run all together
./mvnw verify -q
```

**Pass criteria:** All integration tests green. Testcontainers started and stopped cleanly.

**On failure:** Check for:
- `DataAccessException` → DB schema mismatch — run migrations before tests
- `ApplicationContext fails to load` → missing `@MockBean`, misconfigured `@TestConfiguration`
- Testcontainers startup failure → Docker not running, or image pull failed

---

## Gate 4 — Coverage

```bash
# Maven + JaCoCo
./mvnw verify jacoco:check -q

# View HTML report
open target/site/jacoco/index.html
```

Minimum coverage configuration:
```xml
<!-- pom.xml -->
<plugin>
    <groupId>org.jacoco</groupId>
    <artifactId>jacoco-maven-plugin</artifactId>
    <executions>
        <execution>
            <id>check</id>
            <goals><goal>check</goal></goals>
            <configuration>
                <rules>
                    <rule>
                        <element>BUNDLE</element>
                        <limits>
                            <limit>
                                <counter>LINE</counter>
                                <value>COVEREDRATIO</value>
                                <minimum>0.80</minimum>
                            </limit>
                        </limits>
                    </rule>
                </rules>
            </configuration>
        </execution>
    </executions>
</plugin>
```

**Pass criteria:** ≥ 80% line coverage. Focus on business logic coverage, not generated code (DTOs, config classes).

**Exclude generated code from coverage:**
```xml
<configuration>
    <excludes>
        <exclude>**/dto/**</exclude>
        <exclude>**/*Config.class</exclude>
        <exclude>**/Application.class</exclude>
    </excludes>
</configuration>
```

---

## Gate 5 — Security Scan (OWASP)

```bash
./mvnw org.owasp:dependency-check-maven:check -DfailBuildOnCVSS=7 -q
```

**Pass criteria:** No CVEs with CVSS score ≥ 7 (configurable).

**On failure:** Identify the vulnerable dependency and its transitive path. Fix by upgrading:
```xml
<!-- Force upgrade of a transitive dependency -->
<dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>org.yaml</groupId>
            <artifactId>snakeyaml</artifactId>
            <version>2.2</version>
        </dependency>
    </dependencies>
</dependencyManagement>
```

---

## Gate 6 — Contract Tests (if applicable)

```bash
# Spring Cloud Contract — verify consumer contracts
./mvnw spring-cloud-contract:test -q
```

**When required:** Any service that is consumed by another service (API producer). Skip if the service has no consumers.

---

## Automation — GitHub Actions

```yaml
# .github/workflows/ci.yml
name: CI

on: [push, pull_request]

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'
          cache: maven

      - name: Compile
        run: ./mvnw compile -q

      - name: Unit Tests
        run: ./mvnw test -q

      - name: Integration Tests + Coverage
        run: ./mvnw verify -q

      - name: Security Scan
        run: ./mvnw org.owasp:dependency-check-maven:check -DfailBuildOnCVSS=7 -q

      - name: Upload Coverage Report
        uses: codecov/codecov-action@v4
        with:
          files: target/site/jacoco/jacoco.xml
```

---

## Verification Decision Table

| Gate | Pass | Fail action |
|---|---|---|
| Compile | 0 errors | Fix errors immediately — nothing else runs |
| Unit tests | All green, 0 skipped | Fix failing test — do not `@Disable` without a ticket |
| Integration tests | All green | Fix context/DB issues — do not mock away the problem |
| Coverage | ≥ threshold | Write missing tests — do not lower the threshold |
| Security scan | 0 HIGH/CRITICAL CVEs | Upgrade dependency or file a tracked exception |
| Contract tests | All contracts satisfied | Fix the contract violation — coordinate with consumer |

---

## Definition of Done

A feature or bug fix is DONE when:
1. All 6 gates pass in CI
2. A PR reviewer has approved (code-review agent or human)
3. No `TODO` or `FIXME` without a ticket reference in modified files
4. API documentation updated (OpenAPI annotations or README)
5. Migrations are versioned and tested (if schema changed)
