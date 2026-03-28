# Everything Copilot CLI

A production-ready foundation for GitHub Copilot CLI: **12 agents** + **36 knowledge skills** + **15 modular instruction files** + **2 MCP servers** engineered for Java/Spring Boot, Angular, and Flutter development.

Clone to `~/.copilot/` once. Every project gets instant context. Every session starts informed.

```bash
# Option 1: Clone and install
git clone https://github.com/RogerioSobrinho/copilot-cli-skills-template
cd copilot-cli-skills-template && ./install.sh

# Option 2: One-liner (no clone needed)
curl -fsSL https://raw.githubusercontent.com/RogerioSobrinho/copilot-cli-skills-template/main/install.sh | bash
```

After installing, activate modular instructions globally by adding to your shell config:

```bash
# ~/.bashrc or ~/.zshrc
export COPILOT_CUSTOM_INSTRUCTIONS_DIRS=~/.copilot/instructions
```

---

## The 3-Layer Context Model

Understanding this model is the key to making Copilot CLI your primary dev tool.

```
Layer 0 — Foundation (this repo, public)
~/.copilot/
├── agents/          12 agents for daily workflows
├── skills/          36 knowledge skills, loaded on-demand
├── instructions/    15 modular instruction files (always-on rules)
└── mcp-config.json  2 local MCP servers (sequential-thinking + memory)

Layer 1 — Company Knowledge (local only, never in any repo)
~/.copilot/skills/
├── company-a-hexagonal/SKILL.md        your company's arch conventions
├── company-a-spring-plugin/SKILL.md    internal plugin usage
└── company-a-jvm-standards/SKILL.md    JVM/header standards

Layer 2 — Project Context (committed to each project repo)
{project}/.github/copilot-instructions.md
    tech stack, architecture, team conventions, known gotchas
{project}/.github/instructions/*.instructions.md
    project-specific modular rules (toggle per-stack via /instructions)
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

## Modular Instructions (15 files)

Instructions are always-on rules loaded automatically. Toggle individual files via `/instructions` in Copilot CLI. Requires `COPILOT_CUSTOM_INSTRUCTIONS_DIRS=~/.copilot/instructions` in your shell.

### Layer 1 — Language-agnostic (active in every project)

| File | What it enforces |
|---|---|
| `core.instructions.md` | Core objective, research-before-coding, stoic communication, YAGNI |
| `engineering.instructions.md` | Immutability, defensive programming, error handling, API design, deployment readiness |
| `security.instructions.md` | OWASP mindset, pre-commit checklist, secrets, XSS, CSRF, data scrubbing |
| `testing.instructions.md` | TDD mandatory (RED→GREEN→REFACTOR), AAA pattern, 80% coverage minimum |
| `git.instructions.md` | Conventional commits, PR workflow, atomic commits |
| `performance.instructions.md` | Big O awareness, resource leaks, structured logging, context budget |
| `multi-option.instructions.md` | 3-option rule — every suggestion must include 3 distinct options + recommendation |
| `agents.instructions.md` | Available agents table, invocation guide, repo structure |

### Layer 2 — Java / Spring Boot (toggle off in non-Java projects)

| File | What it enforces |
|---|---|
| `java.instructions.md` | Naming, modern Java (records, sealed, pattern matching), Optional, Streams |
| `java-spring.instructions.md` | Constructor DI, @Transactional, controllers→DTOs, JPA lazy loading, API envelope |
| `java-security.instructions.md` | Bean Validation, @PreAuthorize, PreparedStatement, secrets via env vars |
| `java-testing.instructions.md` | JUnit5, Mockito, Testcontainers, @WebMvcTest, JaCoCo thresholds |

### Layer 3 — TypeScript / Angular (toggle off in non-Angular projects)

| File | What it enforces |
|---|---|
| `typescript.instructions.md` | No `any`, Zod validation, `Readonly<T>`, interfaces vs types, no `console.log` |
| `angular.instructions.md` | Standalone components, signals, `inject()`, OnPush, functional guards, DomSanitizer |

### Layer 4 — Flutter / Dart (toggle off in non-Flutter projects)

| File | What it enforces |
|---|---|
| `flutter.instructions.md` | Clean Architecture, null safety, `final` by default, no `print()`, BLoC/Riverpod, GoRouter |

**Profile examples:**

| Work context | Active files |
|---|---|
| Any project | 8 language-agnostic |
| + Java backend | + 4 `java.*` |
| + Angular frontend | + `typescript` + `angular` |
| + Flutter mobile | + `flutter` |
| Full stack | all 15 |

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

## Agents (12)

| Agent | Model | When to use |
|---|---|---|
| `/new-feature` | opus | Build a new feature end-to-end |
| `/new-project` | opus | Bootstrap a new Spring Boot service |
| `/explore` | sonnet | Understand unfamiliar code or trace a behavior |
| `/code-review` | sonnet | Review staged changes or a PR diff |
| `/fix` | sonnet | Diagnose and fix a build/test/runtime failure |
| `/refactor` | sonnet | Restructure code while preserving behavior |
| `/secure` | sonnet | Security audit and dependency CVE scan |
| `/planner` | sonnet | Requirements → risks → step plan (waits for confirmation before coding) |
| `/tdd-guide` | sonnet | Enforce RED→GREEN→REFACTOR with coverage verification |
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

**`/planner`** — Planning-only agent. Gathers requirements, surfaces risks, proposes 3 architectural options, writes a structured step plan. **Writes no code** until user confirms. Equivalent to Claude Code's `/plan` command.

**`/tdd-guide`** — Enforces RED→GREEN→REFACTOR strictly. Writes a failing test first, minimal passing code next, refactors last, verifies coverage. Supports Java (JUnit5+Mockito), Angular (TestBed), and Flutter (bloc_test+WidgetTester).

**`/doc-writer`** — 5 modes triggered by phrase: `javadoc`, `readme`, `adr`, `openapi`, `codemap`. Lightweight — uses haiku model.

**`/write-a-commit`** — Reads `git diff --staged`, generates a conventional commit message + PR description paragraph. Copy-paste ready.

**`/init-project`** — Reads project structure, pom.xml, Spring config, existing code patterns. Generates `.github/copilot-instructions.md` based on what is actually in the code, not assumptions.

---

## Skills (36)

Skills are reference material loaded on-demand when relevant context is detected. Invoke via `/skills` or they appear automatically when needed.

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
| `flutter-dart-code-review` | Reviewing Flutter/Dart PRs — library-agnostic checklist for state, navigation, performance |

### Meta / Process

| Skill | Loads when you're... |
|---|---|
| `verification-loop` | Defining done criteria, running the quality gate pipeline |
| `git-workflow` | Writing commit messages, naming branches, rebasing, resolving conflicts |
| `debugging-playbook` | Reading stack traces, diagnosing Spring exceptions, remote debug, thread dumps |
| `strategic-compact` | Session running long (>50% context), cycling on the same problem |
| `continuous-learning` | Documenting a pattern after 3 occurrences, writing ADRs, tracking instincts |
| `architecture-decision-records` | Capturing an ADR, recording a design decision with context and consequences |
| `codebase-onboarding` | Mapping an unfamiliar codebase, producing a codemap for a new team member |
| `context-budget` | Managing token budget in large codebases, avoiding context overflow |
| `tdd-workflow` | Applying RED→GREEN→REFACTOR in any language/framework |
| `skill-authoring` | Converting internal docs/text into a SKILL.md |

### Search / Retrieval / Testing

| Skill | Loads when you're... |
|---|---|
| `search-first` | Starting code exploration, searching for patterns across files |
| `iterative-retrieval` | Searching large codebases incrementally |
| `e2e-testing` | Writing Playwright/Cypress E2E tests, page objects, CI setup |

---

## MCP Servers (2 — 100% local)

Both servers run as local Node.js processes via `npx`. Zero network calls, zero data sent externally. Safe for corporate environments.

| Server | What it does | When it activates |
|---|---|---|
| **sequential-thinking** | Breaks complex problems into numbered thought steps with revision and branching | Automatically, during architecture decisions, refactoring plans, debugging chains |
| **memory** | Persists entities, relations, and observations in a local knowledge graph (`~/.copilot/memory.jsonl`) | When the model detects reusable info — your preferences, conventions, past decisions |

### Sequential Thinking in practice

You ask: "should I use event sourcing or CRUD for orders?"

The model chains structured thought steps: (1) analyze requirements → (2) evaluate CRUD → (3) evaluate event sourcing → (4) compare trade-offs → (5) revise step 2 with new insight → (6) conclude. Each step is a discrete tool call — not free-text rambling. Ephemeral: zero storage.

### Memory in practice

**Session 1:** You say "we always use Flyway, never Liquibase." The model stores: `entity=team_convention`, `observation="always use Flyway, never Liquibase"`.

**Session 2:** You ask "set up DB migrations." The model searches the graph → finds Flyway preference → uses it without asking again.

Storage: `~/.copilot/memory.jsonl` — local file, never transmitted. Complements the `continuous-learning` skill.

### Pre-installed

`install.sh` deploys `mcp-config.json` to `~/.copilot/`. If you already have a custom `mcp-config.json`, the existing file is renamed to `mcp-config.json.old`.

Prerequisite: Node.js + npm installed (`npx` must be in PATH).

---

## Deploy

```bash
# Option 1: Clone and install (recommended for contributors)
git clone https://github.com/RogerioSobrinho/copilot-cli-skills-template
cd copilot-cli-skills-template
./install.sh

# Option 2: One-liner remote install (no clone needed)
curl -fsSL https://raw.githubusercontent.com/RogerioSobrinho/copilot-cli-skills-template/main/install.sh | bash

# Update (safe — preserves your company-local skills)
# From cloned repo:
git pull && ./install.sh
# Or remote:
curl -fsSL https://raw.githubusercontent.com/RogerioSobrinho/copilot-cli-skills-template/main/install.sh | bash
```

`install.sh` preserves any `~/.copilot/skills/company-*/` directories. Your local company skills are never overwritten by an update.

---

## Repository Structure

```
copilot-cli-skills-template/
├── .github/
│   ├── instructions/                    15 modular .instructions.md files
│   │   ├── core.instructions.md         }
│   │   ├── engineering.instructions.md  } Layer 1 — language-agnostic (8 files)
│   │   ├── ...                          }
│   │   ├── java.instructions.md         }
│   │   ├── java-spring.instructions.md  } Layer 2 — Java/Spring Boot (4 files)
│   │   ├── ...                          }
│   │   ├── typescript.instructions.md   } Layer 3 — Angular/TypeScript (2 files)
│   │   ├── angular.instructions.md      }
│   │   └── flutter.instructions.md        Layer 4 — Flutter/Dart (1 file)
│   └── copilot-instructions.template.md   Project context starter template
├── agents/                              12 agent .agent.md files
├── skills/                              36 skills, each in skills/{name}/SKILL.md
├── mcp-config.json                      MCP servers (sequential-thinking + memory)
├── install.sh                           Smart deploy (local or remote via curl)
└── README.md
```

---

## License

MIT
