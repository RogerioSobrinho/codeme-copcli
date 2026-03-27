# Everything Copilot CLI

A production-ready foundation for GitHub Copilot CLI: **10 agents** + **30 knowledge skills** engineered for Java/Spring Boot, Angular, and Flutter development.

Clone to `~/.copilot/` once. Every project gets instant context. Every session starts informed.

```bash
git clone https://github.com/your-username/copilot-cli-skills-template
cd copilot-cli-skills-template && ./install.sh
```

---

## The 3-Layer Context Model

Understanding this model is the key to making Copilot CLI your primary dev tool.

```
Layer 0 — Foundation (this repo, public)
~/.copilot/
├── agents/          10 agents for daily workflows
├── skills/          30 knowledge skills, auto-injected
└── copilot-instructions.md   always-on global rules

Layer 1 — Company Knowledge (local only, never in any repo)
~/.copilot/skills/
├── company-a-hexagonal/SKILL.md        your company's arch conventions
├── company-a-spring-plugin/SKILL.md    internal plugin usage
└── company-a-jvm-standards/SKILL.md    JVM/header standards

Layer 2 — Project Context (committed to each project repo)
{project}/.github/copilot-instructions.md
    tech stack, architecture, team conventions, known gotchas
```

**Switching companies:** Layer 0 is identical on every machine (re-run `./install.sh`). Layer 1 lives on the machine — Company A skills stay on Company A's machine. Layer 2 stays in each project repo.

### Adding Company-Specific Knowledge

Your company has internal standards, custom frameworks, or proprietary plugins. Convert them to machine-local skills:

```bash
mkdir ~/.copilot/skills/company-a-hexagonal
# Create SKILL.md with: name + description (trigger) + rules + code examples
# Never committed. Auto-loaded by Copilot CLI.
```

See the `skill-authoring` skill for a step-by-step guide: paste any internal text or examples, get back a precision-triggered SKILL.md.

---

## init-project Workflow

Run once per project. Generates `.github/copilot-instructions.md` so every future session starts with full context.

```
1. Install foundation once
   git clone ... && ./install.sh → ~/.copilot/

2. Add company skills once per machine
   mkdir ~/.copilot/skills/company-a-hexagonal
   # Create SKILL.md from internal docs/examples

3. For each project
   cd your-project/
   /init-project        → reads codebase, generates .github/copilot-instructions.md
   # Enrich the file manually:
   #   - add company-specific conventions
   #   - reference your local company skills
   #   - document known gotchas
   git add .github/copilot-instructions.md && git commit

4. Every future session in that directory: fully context-aware
```

Use `.github/copilot-instructions.template.md` (in this repo) as a manual starting point if you prefer to fill it in without running `init-project`.

---

## Agents (10)

| Agent | Model | When to use |
|---|---|---|
| `/new-feature` | opus | Build a new feature end-to-end |
| `/new-project` | opus | Bootstrap a new Spring Boot service |
| `/explore` | sonnet | Understand unfamiliar code or trace a behavior |
| `/code-review` | sonnet | Review staged changes or a PR diff |
| `/fix` | sonnet | Diagnose and fix a build/test/runtime failure |
| `/refactor` | sonnet | Restructure code while preserving behavior |
| `/secure` | sonnet | Security audit and dependency CVE scan |
| `/doc-writer` | haiku | Javadoc, README, ADR, OpenAPI annotations |
| `/write-a-commit` | haiku | Generate conventional commit from `git diff --staged` |
| `/init-project` | sonnet | Generate project-level Copilot context file (run once) |

**`/new-feature`** — Explores the codebase, asks requirements questions, proposes 3 architectural options (one RECOMMENDED), implements via TDD (tests first), reviews its own output for bugs and security. Never skips steps.

**`/new-project`** — Proposes 3 architectural approaches (layered / modular monolith / microservices), generates complete scaffold: pom.xml, packages, application.yml, Dockerfile, docker-compose.yml, GitHub Actions CI.

**`/explore`** — Runs `find`, `grep`, `git log` first, then answers. Produces codemaps: layers, bounded contexts, entry points, main flows. Scan first, answer second — never asks for context it can discover itself.

**`/code-review`** — CRITICAL / HIGH / MEDIUM tiered review. Reports only: bugs, security vulnerabilities, logic errors, architecture violations. Never style comments. Ends with APPROVED / CHANGES REQUESTED / BLOCKED.

**`/fix`** — Runs the build immediately. Classifies the failure type, applies a surgical fix, re-runs to verify. Max 3 attempts with different approaches.

**`/refactor`** — Maps blast radius, proposes 3 options, applies incrementally with verification after each step. Never breaks existing behavior.

**`/secure`** — OWASP dependency check + Spring Security config review + auth/authorization + input validation + secrets scan. Every finding mapped to OWASP Top 10 with severity and concrete fix.

**`/doc-writer`** — 5 modes triggered by phrase: `javadoc`, `readme`, `adr`, `openapi`, `codemap`. Lightweight — uses haiku model.

**`/write-a-commit`** — Reads `git diff --staged`, generates a conventional commit message + PR description paragraph. Copy-paste ready.

**`/init-project`** — Reads project structure, pom.xml, Spring config, existing code patterns. Generates `.github/copilot-instructions.md` based on what is actually in the code, not assumptions.

---

## Skills (30)

Skills are reference material, loaded automatically when relevant. You don't invoke them — they appear when needed.

### Java / Spring Boot

| Skill | Loads when you're... |
|---|---|
| `springboot-patterns` | Writing @Service, @Repository, @RestController, @Configuration |
| `jpa-patterns` | Writing @Entity, debugging LazyInitializationException, N+1 queries |
| `springboot-security` | Configuring SecurityFilterChain, JWT, @PreAuthorize, OAuth2 |
| `springboot-tdd` | Writing @SpringBootTest, @DataJpaTest, @WebMvcTest, Testcontainers |
| `springboot-verification` | Running Maven verify, JaCoCo, defining quality gates |
| `api-design` | Designing REST endpoints, status codes, versioning, pagination |
| `database-migrations` | Writing Flyway V{n} scripts, Liquibase changesets, zero-downtime migrations |
| `java-coding-standards` | Using Java 17+ records, sealed classes, pattern matching, switch expressions |
| `observability-patterns` | Adding @Timed, MeterRegistry, MDC, Actuator probes, Prometheus |
| `messaging-patterns` | Writing @KafkaListener, outbox pattern, Avro, DLT, RabbitMQ |
| `resilience-patterns` | Using @CircuitBreaker, @Retry, @Bulkhead, Resilience4j config |
| `springboot-scaffold` | Creating a new endpoint, aggregate, Kafka consumer, scheduled job |

### Infrastructure / DevOps

| Skill | Loads when you're... |
|---|---|
| `docker-patterns` | Writing Dockerfile, multi-stage builds, JVM heap in containers |
| `deployment-patterns` | Configuring Kubernetes, health probes, rolling updates, Helm |
| `postgres-patterns` | Writing SQL, indexes, EXPLAIN ANALYZE, connection pooling |

### Frontend — Angular

| Skill | Loads when you're... |
|---|---|
| `frontend-principles` | Designing frontend architecture, state management, API integration, auth flow |
| `angular-patterns` | Writing standalone components, signals, reactive forms, HttpClient interceptors |
| `angular-tdd` | Writing TestBed tests, ComponentFixture, testing signals |
| `angular-security` | Implementing auth guards, JWT interceptors, DomSanitizer, XSS prevention, CSP |

### Frontend — Flutter

| Skill | Loads when you're... |
|---|---|
| `flutter-patterns` | Building BLoC/Cubit, Riverpod, GoRouter, Dio, Either error handling |
| `flutter-tdd` | Writing bloc_test, WidgetTester, golden tests, integration_test |

### Meta / Process

| Skill | Loads when you're... |
|---|---|
| `verification-loop` | Defining done criteria, running the quality gate pipeline |
| `git-workflow` | Writing commit messages, naming branches, rebasing, resolving conflicts |
| `debugging-playbook` | Reading stack traces, diagnosing Spring exceptions, remote debug, thread dumps |
| `strategic-compact` | Session running long (>50% context), cycling on the same problem |
| `continuous-learning` | Documenting a pattern after 3 occurrences, writing ADRs, tracking instincts |
| `skill-authoring` | Converting internal docs/text into a SKILL.md |

### Search / Retrieval / Testing

| Skill | Loads when you're... |
|---|---|
| `search-first` | Starting code exploration, searching for patterns across files |
| `iterative-retrieval` | Searching large codebases incrementally |
| `e2e-testing` | Writing Playwright/Cypress E2E tests, page objects, CI setup |

---

## Deploy

```bash
# First install
git clone https://github.com/your-username/copilot-cli-skills-template
cd copilot-cli-skills-template
./install.sh

# Update (safe — preserves your company-local skills)
git pull && ./install.sh
```

`install.sh` preserves any `~/.copilot/skills/company-*/` directories. Your local company skills are never overwritten by an update.

---

## Repository Structure

```
copilot-cli-skills-template/
├── agents/                                  10 agent .agent.md files
├── skills/                                  30 skills, each in skills/{name}/SKILL.md
├── .github/
│   └── copilot-instructions.template.md     Project context starter template
├── copilot-instructions.md                  Global + Java/Spring Boot rules
├── install.sh                               Smart merge deploy script
└── README.md
```

---

## License

MIT
