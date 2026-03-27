---
name: springboot-verification
description: Verification loop patterns for Spring Boot. Defines ordered quality gates: compile → unit test → integration test → contract test → security scan → coverage check. Load when setting up CI or running quality checks.
---

# Spring Boot Verification

## Verification Pipeline — Ordered Gates

```
Gate 1: Compile
    ↓ (fail → stop)
Gate 2: Unit Tests
    ↓ (fail → stop)
Gate 3: Integration Tests
    ↓ (fail → stop)
Gate 4: Contract Tests
    ↓ (fail → stop)
Gate 5: Coverage (JaCoCo — line ≥ 80%, branch ≥ 80%)
    ↓ (fail → stop)
Gate 6: Mutation Testing (PITest — score ≥ 70%)
    ↓ (fail → stop)
Gate 7: Security Scan (OWASP — no CVSS ≥ 7)
    ↓ (fail → stop)
Gate 8: All Gates Green → Ready to merge/deploy
```

**Rule:** Never skip a gate. Never run gate N+1 when gate N fails.

---

## Maven Commands

```bash
# Gate 1 — Compile
mvn compile -q

# Gate 2 — Unit Tests
mvn test -DfailIfNoTests=false

# Gate 3 — Integration Tests (Failsafe)
mvn failsafe:integration-test failsafe:verify

# Gate 4 — Contract Tests
mvn spring-cloud-contract:generateTests verify

# Gate 5 — Coverage
mvn verify -P coverage

# Gate 6 — Mutation Testing
mvn test-compile org.pitest:pitest-maven:mutationCoverage

# Gate 7 — Security Scan
mvn org.owasp:dependency-check-maven:check -DfailBuildOnCVSS=7
```

---

## JaCoCo Coverage Config

```xml
<plugin>
    <groupId>org.jacoco</groupId>
    <artifactId>jacoco-maven-plugin</artifactId>
    <version>0.8.11</version>
    <executions>
        <execution><id>prepare-agent</id><goals><goal>prepare-agent</goal></goals></execution>
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
                                <counter>LINE</counter><value>COVEREDRATIO</value><minimum>0.80</minimum>
                            </limit>
                            <limit>
                                <counter>BRANCH</counter><value>COVEREDRATIO</value><minimum>0.80</minimum>
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

---

## PITest Mutation Testing Config

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
    </configuration>
</plugin>
```

Apply only to business logic (`domain`, `service`). PITest is slow — run in a dedicated CI job.

---

## OWASP Dependency-Check Config

```xml
<plugin>
    <groupId>org.owasp</groupId>
    <artifactId>dependency-check-maven</artifactId>
    <version>9.0.9</version>
    <configuration>
        <failBuildOnCVSS>7</failBuildOnCVSS>
        <suppressionFile>dependency-check-suppression.xml</suppressionFile>
    </configuration>
</plugin>
```

Suppression with expiry:
```xml
<suppressions>
    <suppress>
        <notes>False positive: CVE does not affect our usage</notes>
        <cve>CVE-2023-XXXXX</cve>
        <until>2024-12-31</until>
    </suppress>
</suppressions>
```

---

## Failure Handling Protocol

When a gate fails:
1. Stop immediately — do not proceed to the next gate.
2. Capture: test name, error message, stack trace (first 20 lines).
3. Identify root cause: compile error, assertion failure, environment issue, or configuration problem.
4. Fix the root cause.
5. Re-run from the **failed gate only** (not from Gate 1).
6. After 3 failed attempts at the same gate → escalate to user.

---

## GitHub Actions Pipeline

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

  security-scan:
    needs: integration-tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with: { java-version: '21', distribution: 'temurin' }
      - run: mvn org.owasp:dependency-check-maven:check -DfailBuildOnCVSS=7
```
