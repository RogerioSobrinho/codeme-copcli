# Copilot CLI Skills Template

A production-ready template for GitHub Copilot CLI custom agents and knowledge skills, engineered for Spring Boot microservices development at an ultra-senior level.

## Structure

```
.
├── agents/          # Custom agent profiles (.agent.md)
├── skills/          # Knowledge reference bases (SKILL.md per subdirectory)
└── copilot-instructions.md   # Global engineering principles
```

## Agents

22 specialized agents covering the complete software delivery lifecycle.

| Agent | Model | Role |
|---|---|---|
| `orchestrator` | opus | Manages workflow execution across all agents |
| `architect` | opus | System design and ADR authoring |
| `domain-modeler` | opus | DDD tactical patterns and domain model design |
| `agent-creator` | opus | Meta-agent for creating new agents and skills |
| `requirement-analyst` | sonnet | Structures requirements as actionable specifications |
| `impact-analyst` | sonnet | Blast radius analysis before changes |
| `test-designer` | sonnet | TDD test pyramid strategy and test plan |
| `test-quality-reviewer` | sonnet | Audits test suite coverage and quality |
| `implementer` | sonnet | Writes production-grade Spring Boot code |
| `integration-reviewer` | sonnet | REST and Kafka contract validation |
| `data-integrity-reviewer` | sonnet | DB constraints, migrations, transaction safety |
| `concurrency-reviewer` | sonnet | Thread safety and race condition analysis |
| `performance-profiler` | sonnet | N+1, caching, algorithm complexity |
| `security-reviewer` | sonnet | OWASP Top 10 audit |
| `resilience-reviewer` | sonnet | Circuit breakers, retries, bulkheads |
| `observability-designer` | sonnet | MDC, Micrometer, OpenTelemetry setup |
| `code-reviewer` | sonnet | Bugs, logic errors, security — signal only |
| `release-risk-assessor` | sonnet | GO/NO-GO decision from all review reports |
| `cicd-designer` | sonnet | GitHub Actions, Docker, Kubernetes pipelines |
| `codebase-explorer` | sonnet | Produces structured context.json |
| `java-build-resolver` | sonnet | Maven/Gradle build and compilation failures |
| `doc-writer` | haiku | Codemaps, endpoint inventories, changelogs |

## Skills (Knowledge Bases)

14 reference bases loaded on demand by agents.

| Skill | Contents |
|---|---|
| `springboot-patterns` | Core Spring Boot patterns: configuration, exception handling, validation, scheduling |
| `springboot-tdd` | Test pyramid, Testcontainers, MockMvc, WireMock, test slices |
| `springboot-security` | Spring Security 6, JWT, RBAC, method security, CORS |
| `springboot-verification` | Pre-commit checklist, architecture tests (ArchUnit), quality gates |
| `jpa-patterns` | JPA/Hibernate best practices, N+1 prevention, projections, auditing |
| `postgres-patterns` | PostgreSQL indexing, JSONB, window functions, connection pooling |
| `api-design` | REST naming, versioning, cursor pagination, RFC 7807, OpenAPI, idempotency |
| `database-migrations` | Flyway/Liquibase, zero-downtime DDL, rollback strategy |
| `docker-patterns` | Multi-stage Dockerfile, JVM container tuning, Docker Compose, health checks |
| `deployment-patterns` | Blue-green, canary, rolling updates, K8s probes, graceful shutdown |
| `e2e-testing` | REST Assured, Testcontainers singleton, WireMock, Spring Cloud Contract, Gatling |
| `search-first` | 5-layer search order, grep patterns, dependency cost check |
| `continuous-learning` | Three-time rule, pattern templates, ADR format, session review protocol |
| `iterative-retrieval` | Progressive context loading, token budget, grep-before-read rule |

## Workflow Usage

The `orchestrator` agent manages three built-in workflow sequences. Invoke by starting a conversation with the orchestrator:

### New Feature
```
@orchestrator I need to add a payment processing feature to the orders service.
```
Sequence: `codebase-explorer → requirement-analyst → impact-analyst → architect → domain-modeler → test-designer → implementer → integration-reviewer → test-quality-reviewer → concurrency-reviewer → performance-profiler → security-reviewer → resilience-reviewer → observability-designer → data-integrity-reviewer → code-reviewer → release-risk-assessor → cicd-designer → doc-writer`

### Refactoring
```
@orchestrator Refactor the OrderService to use domain events.
```
Sequence: `codebase-explorer → impact-analyst → test-designer → test-quality-reviewer → architect → domain-modeler → implementer → integration-reviewer → concurrency-reviewer → performance-profiler → security-reviewer → resilience-reviewer → observability-designer → data-integrity-reviewer → code-reviewer → release-risk-assessor → cicd-designer → doc-writer`

### New Project
```
@orchestrator Bootstrap a new Spring Boot 3 service for inventory management.
```
Sequence: `codebase-explorer → requirement-analyst → architect → domain-modeler → test-designer → implementer → integration-reviewer → test-quality-reviewer → concurrency-reviewer → performance-profiler → security-reviewer → resilience-reviewer → observability-designer → data-integrity-reviewer → code-reviewer → release-risk-assessor → cicd-designer → doc-writer`

## Runtime Artifacts

All agents write outputs to `.copilot-runtime/` (git-ignored):

```
.copilot-runtime/
├── artifacts/       # context.json, requirements.md, domain-model.md
├── analysis/        # impact-report.md, security-report.md, performance-report.md
├── decisions/       # ADR-NNN files
├── tests/           # test-plan.md, test-quality-report.md
└── summaries/       # documentation outputs
```

## Adding Agents and Skills

Use the `agent-creator` meta-agent:
```
@agent-creator Create a new agent for GraphQL schema design.
```

Or follow the conventions manually:
- **Agent:** Create `agents/<name>.agent.md` with YAML frontmatter (`name`, `description`, `tools`, `model`) + prose instructions.
- **Skill:** Create `skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description` only) + reference material.
