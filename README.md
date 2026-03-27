# Copilot CLI Skills Template

A production-ready template for GitHub Copilot CLI custom agents and knowledge skills, engineered for Java/Spring Boot development at an ultra-senior level.

## 7 Scenario Agents

Agents are organized around **what you want to do**, not internal pipeline steps.

| When you say... | Use |
|---|---|
| "I want to build X" | `/new-feature` |
| "Explain this codebase" / "Where is X" | `/explore` |
| "Review my changes" / "Review this PR" | `/code-review` |
| "Start a new Spring Boot service" | `/new-project` |
| "Something is broken" / "Fix the build" | `/fix` |
| "Audit security" / "Is this safe?" | `/secure` |
| "Clean up this code" / "This is too complex" | `/refactor` |

### `/new-feature` — Full Feature Lifecycle
Model: `claude-opus-4-5`

Handles everything: explores the codebase, asks clarifying requirements, proposes 3 architectural options (marks one RECOMMENDED), writes an implementation plan, implements via TDD (test first, then code), reviews its own changes for bugs and security, reports what was done. You never need to switch to another agent mid-feature.

### `/explore` — Codebase Navigator
Model: `claude-sonnet-4-5` · Tools: read, search, shell

Runs structural commands first (`find`, `grep`, `git log`), then answers your question based on actual source code. Produces codemaps: architecture layers, key bounded contexts, entry points, main request flows. Rule: scan first, answer second. Never asks you to provide context it can discover itself.

### `/code-review` — Signal-Only Code Review
Model: `claude-sonnet-4-5` · Tools: read, search, shell

Reviews `git diff --staged` (or any specified file/diff). Reports **only**: bugs, security vulnerabilities, logic errors, architecture violations. Never comments on style, naming, or formatting. Every finding: file location + root cause + concrete fix. Ends with APPROVED / APPROVED WITH COMMENTS / CHANGES REQUIRED.

### `/new-project` — Project Bootstrapper
Model: `claude-opus-4-5`

Gathers requirements, proposes 3 architectural approaches (layered monolith / modular monolith / microservices), generates the complete scaffold: `pom.xml`, package structure, `application.yml`, `Dockerfile`, `docker-compose.yml`, GitHub Actions CI, base exception handling. Applies 12-Factor App and Clean Architecture from day 1.

### `/fix` — Build and Test Failure Resolver
Model: `claude-sonnet-4-5` · Tools: read, edit, write, search, shell

Runs the build immediately (no questions first). Classifies: compilation error / dependency conflict / annotation processor issue / Spring context failure / test failure. Applies a surgical fix, re-runs to verify. Max 3 attempts with different approaches.

### `/secure` — Security Auditor
Model: `claude-sonnet-4-5` · Tools: read, search, shell

Runs `mvn dependency-check:check`, then reviews: Spring Security config, authentication/authorization, input validation, secrets in source/config, CORS/CSRF. Maps every finding to an OWASP Top 10 category with severity and concrete fix.

### `/refactor` — Behavior-Preserving Refactor
Model: `claude-sonnet-4-5` · Tools: read, edit, write, search, shell

Maps blast radius (callers, tests), proposes 3 refactoring approaches with risk levels, applies incrementally with compile verification after each step, runs tests to confirm behavior is preserved. Rule: refactor in small verified steps. Never break what works.

---

## 14 Knowledge Skills

Skills are reference material loaded automatically when relevant.

| Skill | Contents |
|---|---|
| `springboot-patterns` | Core Spring Boot patterns: layers, JPA, security, async, caching, transactions |
| `springboot-tdd` | Test pyramid: `@WebMvcTest`, `@DataJpaTest`, Testcontainers, MockMvc, Spring Cloud Contract |
| `springboot-security` | Spring Security 6, JWT, OAuth2 resource server, RBAC, CORS, CSRF |
| `springboot-verification` | Quality gates: compile → unit → integration → coverage (JaCoCo) → mutation (PITest) → security scan |
| `jpa-patterns` | N+1 prevention, projections, pagination, entity design, auditing, optimistic locking |
| `postgres-patterns` | Indexes, EXPLAIN ANALYZE, HikariCP tuning, JSONB, partitioning, zero-downtime DDL |
| `api-design` | REST naming, HTTP semantics, versioning, cursor pagination, RFC 7807, idempotency |
| `database-migrations` | Flyway/Liquibase, zero-downtime DDL, data migration batching, rollback strategy |
| `docker-patterns` | Multi-stage Dockerfile, JVM container tuning, Docker Compose with health checks |
| `deployment-patterns` | Blue-green, canary, rolling updates, K8s probes, graceful shutdown, resource limits |
| `e2e-testing` | REST Assured base class, Testcontainers singleton, WireMock, Spring Cloud Contract, Gatling |
| `search-first` | 5-layer search protocol, grep patterns, dependency cost check, anti-patterns list |
| `continuous-learning` | Three-time rule, pattern/anti-pattern templates, ADR format, end-of-session protocol |
| `iterative-retrieval` | Progressive context loading, token budget guide, grep-before-read rule, pruning checklist |

---

## Repository Structure

```
.
├── agents/
│   ├── new-feature.agent.md
│   ├── explore.agent.md
│   ├── code-review.agent.md
│   ├── new-project.agent.md
│   ├── fix.agent.md
│   ├── secure.agent.md
│   └── refactor.agent.md
├── skills/
│   ├── springboot-patterns/SKILL.md
│   ├── springboot-tdd/SKILL.md
│   └── ... (14 total)
└── copilot-instructions.md
```

## Deploy

```bash
cp -r /path/to/copilot-cli-skills-template/. ~/.copilot/
```
