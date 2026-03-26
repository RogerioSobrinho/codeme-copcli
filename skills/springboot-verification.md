---
name: springboot-verification
description: Verification loop patterns for Java/Spring Boot. Defines quality gates: compile → unit test → integration test → contract test → security scan. Drives autonomous quality enforcement.
tools: ["Read", "Write", "Bash", "Grep"]
model: claude-sonnet-4-5
activation: ["verify", "quality gate", "verification loop", "spring boot verify", "run all checks"]
---

# Spring Boot Verification

## Purpose

Defines an ordered, fail-fast verification pipeline for Java/Spring Boot projects. Each gate must pass before the next runs. Covers compilation, unit tests, integration tests, contract verification, coverage enforcement with JaCoCo, mutation testing with PITest, security scanning with OWASP dependency-check, and CI integration. Used to drive autonomous quality enforcement loops.

---

## Verification Pipeline — Ordered Gates

```
Gate 1: Compile
    ↓ (fail → stop, report compile errors)
Gate 2: Unit Tests
    ↓ (fail → stop, report failing test + root cause)
Gate 3: Integration Tests
    ↓ (fail → stop, report failing test + DB/service state)
Gate 4: Contract Tests
    ↓ (fail → stop, report broken contract + consumer impact)
Gate 5: Coverage Threshold (JaCoCo)
    ↓ (fail → stop, report uncovered lines/branches)
Gate 6: Mutation Testing (PITest)
    ↓ (fail → stop, report surviving mutants)
Gate 7: Security Scan (OWASP dependency-check)
    ↓ (fail → stop, report vulnerable dependencies)
Gate 8: All Gates Green → Ready to merge/deploy
```

**Rule:** NEVER skip a gate. NEVER run gate N+1 when gate N fails.

---

## Gate Commands — Maven

### Gate 1 — Compile
```bash
mvn compile -q
```
Expected: `BUILD SUCCESS`. Any `ERROR` → stop.

### Gate 2 — Unit Tests
```bash
mvn test -pl . -Dtest="**/*Test" -DfailIfNoTests=false
```
Or with profile:
```bash
mvn test -P unit-tests
```

### Gate 3 — Integration Tests
```bash
mvn verify -P integration-tests -DskipUnitTests=true
```
Or using Failsafe:
```bash
mvn failsafe:integration-test failsafe:verify
```

### Gate 4 — Contract Tests
```bash
mvn verify -P contract-tests
# or
mvn spring-cloud-contract:run spring-cloud-contract:generateTests verify
```

### Gate 5 — Coverage (JaCoCo)
```bash
mvn verify -P coverage
```
Gate fails if line coverage < 80% or branch coverage < 80%.

### Gate 6 — Mutation Testing (PITest)
```bash
mvn test-compile org.pitest:pitest-maven:mutationCoverage
```
Gate fails if mutation score < 70%.

### Gate 7 — Security Scan
```bash
mvn org.owasp:dependency-check-maven:check -DfailBuildOnCVSS=7
```
Gate fails on any CVSS score ≥ 7 (HIGH or CRITICAL).

---

## Gate Commands — Gradle

### Gate 1 — Compile
```bash
./gradlew compileJava compileTestJava
```

### Gate 2 — Unit Tests
```bash
./gradlew test
```

### Gate 3 — Integration Tests
```bash
./gradlew integrationTest
```

### Gates 5+
```bash
./gradlew jacocoTestCoverageVerification   # Gate 5
./gradlew pitest                           # Gate 6
./gradlew dependencyCheckAnalyze           # Gate 7
```

---

## Stopping Conditions

When a gate fails:
1. **Stop immediately.** Do NOT proceed to the next gate.
2. **Capture the failure:** test name, error message, stack trace first 20 lines.
3. **Identify root cause:** Is it a compile error, assertion failure, environment issue, or configuration problem?
4. **Report** with structured output:

```json
{
  "gate": "unit-tests",
  "status": "fail",
  "failing_test": "OrderServiceTest#shouldThrowWhenOrderNotFound",
  "root_cause": "NullPointerException in OrderService.findOrder:42",
  "fix_hint": "OrderRepository mock not configured for findById"
}
```

5. Fix the root cause, then re-run from the **failed gate only** (not from Gate 1).

---

## Coverage Threshold — JaCoCo Config

### Maven `pom.xml`
```xml
<plugin>
    <groupId>org.jacoco</groupId>
    <artifactId>jacoco-maven-plugin</artifactId>
    <version>0.8.11</version>
    <executions>
        <execution>
            <id>prepare-agent</id>
            <goals><goal>prepare-agent</goal></goals>
        </execution>
        <execution>
            <id>check</id>
            <phase>verify</phase>
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
                            <limit>
                                <counter>BRANCH</counter>
                                <value>COVEREDRATIO</value>
                                <minimum>0.80</minimum>
                            </limit>
                        </limits>
                    </rule>
                </rules>
                <excludes>
                    <exclude>**/config/**</exclude>
                    <exclude>**/dto/**</exclude>
                    <exclude>**/*Application.class</exclude>
                </excludes>
            </configuration>
        </execution>
    </executions>
</plugin>
```

### Pitfalls
- 100% coverage is NOT the goal. 80% with meaningful tests beats 95% with trivial tests.
- Always exclude generated code, DTOs, and Spring config classes from JaCoCo.

---

## Mutation Testing — PITest

### What It Measures
Coverage tells you which lines executed. Mutation testing tells you whether your tests actually DETECT changes (mutations) to the code.

A surviving mutant = a line your tests cannot catch changing.

### Maven Config
```xml
<plugin>
    <groupId>org.pitest</groupId>
    <artifactId>pitest-maven</artifactId>
    <version>1.15.3</version>
    <configuration>
        <targetClasses>
            <param>com.example.domain.*</param>
            <param>com.example.service.*</param>
        </targetClasses>
        <targetTests>
            <param>com.example.*Test</param>
        </targetTests>
        <mutationThreshold>70</mutationThreshold>
        <coverageThreshold>80</coverageThreshold>
        <outputFormats>
            <outputFormat>HTML</outputFormat>
            <outputFormat>XML</outputFormat>
        </outputFormats>
    </configuration>
</plugin>
```

### Pitfalls
- PITest is slow. Run it in a dedicated CI job, not on every commit.
- Apply only to business logic (`domain`, `service`) — not controllers or config.

---

## Contract Verification — Spring Cloud Contract

### Verify Producer Contracts
```bash
# Generate tests from contract files and run against the real producer
mvn spring-cloud-contract:generateTests verify
```

### Verify Consumer Stubs
```bash
# Run consumer tests against published stubs
mvn test -Dspring.profiles.active=contract
```

### Gate Failure Criteria
- Any contract test failure = the producer broke a consumer contract.
- Do NOT merge until the contract is either fixed or the consumer is notified and migrated.

---

## Security Gate — OWASP Dependency-Check

### Maven Config
```xml
<plugin>
    <groupId>org.owasp</groupId>
    <artifactId>dependency-check-maven</artifactId>
    <version>9.0.9</version>
    <configuration>
        <failBuildOnCVSS>7</failBuildOnCVSS>
        <suppressionFile>dependency-check-suppression.xml</suppressionFile>
        <formats>
            <format>HTML</format>
            <format>JSON</format>
        </formats>
    </configuration>
</plugin>
```

### Suppression File Pattern
When a CVE is a false positive or an accepted risk:
```xml
<suppressions>
    <suppress>
        <notes>False positive: CVE does not affect our usage pattern</notes>
        <cve>CVE-2023-XXXXX</cve>
        <until>2024-12-31</until>
    </suppress>
</suppressions>
```

### Pitfalls
- Set `<until>` dates on suppressions. Unlimited suppressions accumulate and hide real vulnerabilities.
- Run this gate ONCE per day in CI, not on every commit (it calls the NVD API and is slow).

---

## Loop Pattern — Autonomous Verification Loop

```
1. Run Gate N
2. If PASS → run Gate N+1
3. If FAIL:
   a. Capture root cause
   b. Generate fix (code change, config change, dependency update)
   c. Apply fix
   d. Re-run Gate N (NOT from Gate 1)
   e. If Gate N PASS → continue to Gate N+1
   f. If Gate N FAIL again after 3 attempts → escalate to user
4. When all gates PASS → mark verification complete
```

### Escalation Criteria
- Same gate fails 3 times with different fixes → root cause is likely architectural, not trivial.
- Security gate fails with a HIGH/CRITICAL CVE in a direct dependency → requires dependency upgrade decision.

---

## CI Integration — GitHub Actions

```yaml
name: verification-pipeline

on: [push, pull_request]

jobs:
  compile:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { java-version: '21', distribution: 'temurin' }
      - run: mvn compile -q

  unit-tests:
    needs: compile
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { java-version: '21', distribution: 'temurin' }
      - run: mvn test

  integration-tests:
    needs: unit-tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { java-version: '21', distribution: 'temurin' }
      - run: mvn failsafe:integration-test failsafe:verify

  coverage:
    needs: integration-tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { java-version: '21', distribution: 'temurin' }
      - run: mvn verify -P coverage
      - uses: codecov/codecov-action@v4

  security-scan:
    needs: coverage
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { java-version: '21', distribution: 'temurin' }
      - run: mvn org.owasp:dependency-check-maven:check -DfailBuildOnCVSS=7
```

---

## Standalone Invocation (No Orchestrator)

This agent can be invoked directly without the orchestrator. When `.copilot-runtime/artifacts/context.json` is absent, three options are available:

**Option 1 — Run Diagnostic Commands Directly**
Execute targeted commands to gather context on the fly:
- `mvn compile -q 2>&1 | tail -20` — check compile status
- `mvn test -q 2>&1 | grep -E "Tests run|BUILD"` — check unit test status
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
