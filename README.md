# Everything Copilot CLI

A production-ready foundation for GitHub Copilot CLI: **17 agents** + **43 knowledge skills** + **16 modular instruction files** + **2 MCP servers** + **LSP config** engineered for Java/Spring Boot, Angular, Flutter, Python, React, Node.js, and Go development.

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
├── agents/          17 agents for daily workflows
├── skills/          43 knowledge skills, loaded on-demand
├── instructions/    16 modular instruction files (always-on rules)
├── mcp-config.json  2 local MCP servers (sequential-thinking + memory)
└── lsp-config.json  LSP server config (code intelligence per stack)

Note: The GitHub MCP server is BUILT-IN to Copilot CLI — always active, no config needed.
      The 2 MCP servers above ADD TO the built-in GitHub MCP.

Layer 1 — Company Knowledge (local only, never in any repo)
~/.copilot/skills/
├── company-a-hexagonal/SKILL.md        your company's arch conventions
├── company-a-spring-plugin/SKILL.md    internal plugin usage
└── company-a-jvm-standards/SKILL.md    JVM/header standards

Layer 2 — Project Context (committed to each project repo)
{project}/AGENTS.md
    universal agent context — read by Copilot CLI, Claude Code, and any compatible agent
{project}/.github/copilot-instructions.md
    tech stack, architecture, team conventions, known gotchas (Copilot CLI-specific)
{project}/.github/instructions/*.instructions.md
    project-specific modular rules (toggle per-stack via /instructions)
{project}/.github/agents/*.agent.md
    project-specific agents — override user-level agents when names conflict
    version-controlled alongside the code, shared across the team
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

Instructions are always-on rules loaded by Copilot CLI when relevant. Toggle individual files via `/instructions`.

### How instructions are loaded — two scopes

| Scope | Path | Activation |
|-------|------|------------|
| **Per-project** | `{project}/.github/instructions/*.instructions.md` | Auto-loaded in any git repo that has this directory |
| **Global (all projects)** | `~/.copilot/instructions/*.instructions.md` | Requires `COPILOT_CUSTOM_INSTRUCTIONS_DIRS=~/.copilot/instructions` in shell config |

`install.sh` deploys to `~/.copilot/instructions/` (not `~/.copilot/.github/instructions/` — that path would only work while your cwd is inside `~/.copilot/` itself, not in your projects).

The `.github/instructions/` directory in this repo is the **source** used by `install.sh`. For project-level instructions, copy specific files from `.github/instructions/` into your project's `.github/instructions/`.

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

### Layer 5 — Python (toggle off in non-Python projects)

| File | What it enforces |
|---|---|
| `python.instructions.md` | Type hints mandatory, Pydantic v2, no bare `except`, structured logging, `Decimal` for money |

**Profile examples:**

| Work context | Active files |
|---|---|
| Any project | 8 language-agnostic |
| + Java backend | + 4 `java.*` |
| + Angular frontend | + `typescript` + `angular` |
| + Flutter mobile | + `flutter` |
| + Python backend | + `python` |
| Full stack | all 16 |

---

## init-project Workflow

Run once per project. Generates `.github/copilot-instructions.md` **and** `AGENTS.md` so every future session starts with full context.

```
1. Install foundation once
   git clone ... && ./install.sh → ~/.copilot/

2. Add company skills once per machine
   mkdir ~/.copilot/skills/company-a-hexagonal
   # Create SKILL.md from internal docs/examples

3. For each project
   cd your-project/
   /init-project        → reads codebase, generates:
                           - .github/copilot-instructions.md  (Copilot CLI-specific)
                           - AGENTS.md                        (universal agent context)
   # Enrich both files manually:
   #   - add company-specific conventions
   #   - reference your local company skills
   #   - document known gotchas
   git add .github/copilot-instructions.md AGENTS.md && git commit

4. Every future session in that directory: fully context-aware
   (AGENTS.md is also read by Claude Code, GitHub Copilot, and other AI agents)
```

Use `.github/copilot-instructions.template.md` (in this repo) as a manual starting point if you prefer to fill it in without running `init-project`.

---

## Agents (17)

| Agent | Model | When to use |
|---|---|---|
| `/new-feature` | opus | Build a new feature end-to-end |
| `/new-project` | opus | Bootstrap a new Spring Boot service |
| `/architect` | sonnet | System design, 3-option trade-off analysis, ADR generation |
| `/explore` | sonnet | Understand unfamiliar code or trace a behavior |
| `/code-review` | sonnet | Review staged Java/Spring Boot changes or a PR diff |
| `/typescript-reviewer` | sonnet | Review TypeScript/React changes for type safety and hook patterns |
| `/python-reviewer` | sonnet | Review Python changes for async safety, type hints, and security |
| `/pr-review` | sonnet | Review an existing GitHub PR via GitHub MCP |
| `/fix` | sonnet | Diagnose and fix a build/test/runtime failure |
| `/build-resolver` | sonnet | Fix build/compile errors across any stack (Java, TS, Go, Python, Flutter) |
| `/refactor` | sonnet | Restructure code while preserving behavior |
| `/secure` | opus | Security audit and dependency CVE scan |
| `/planner` | sonnet | Requirements → risks → step plan (waits for confirmation before coding) |
| `/tdd-guide` | sonnet | Enforce RED→GREEN→REFACTOR with coverage verification |
| `/doc-writer` | haiku | Javadoc, README, ADR, OpenAPI annotations |
| `/write-a-commit` | haiku | Generate conventional commit from `git diff --staged` |
| `/init-project` | sonnet | Generate project-level Copilot context files (run once) |

**`/new-feature`** — Explores the codebase, asks requirements questions, proposes 3 architectural options (one RECOMMENDED), implements via TDD (tests first), reviews its own output for bugs and security. Never skips steps.

**`/new-project`** — Proposes 3 architectural approaches (layered / modular monolith / microservices), generates complete scaffold: pom.xml, packages, application.yml, Dockerfile, docker-compose.yml, GitHub Actions CI.

**`/architect`** — Reads existing architecture, presents 3 distinct design options with pros/cons, marks one RECOMMENDED, and generates an Architecture Decision Record (ADR) once confirmed. Use for new services, major design choices, or cross-cutting concerns.

**`/explore`** — Runs `find`, `grep`, `git log` first, then answers. Produces codemaps: layers, bounded contexts, entry points, main flows. Scan first, answer second — never asks for context it can discover itself.

**`/code-review`** — CRITICAL / HIGH / MEDIUM tiered review for Java/Spring Boot. Reports only: bugs, security vulnerabilities, logic errors, architecture violations. Never style comments. Ends with APPROVED / CHANGES REQUESTED / BLOCKED.

**`/typescript-reviewer`** — Specialized review for TypeScript and React. Catches `any` leaks, unsound assertions, hook rule violations, missing `await`, and unsafe `dangerouslySetInnerHTML`. Same tiered format as `/code-review`.

**`/python-reviewer`** — Specialized review for Python. Catches blocking I/O in async context, missing type hints, SQL injection via f-strings, broad `except`, and Pydantic `Any` fields. Same tiered format as `/code-review`.

**`/pr-review`** — Uses the GitHub MCP server to read an existing PR diff, files, and comments. Produces the same tiered review format as `/code-review` but for any PR number in the repo. Useful for async review and CI gate checks.

**`/fix`** — Runs the build immediately. Classifies the failure type (compilation, dependency conflict, test failure, runtime), applies a surgical fix, re-runs to verify. Max 3 attempts with different approaches.

**`/build-resolver`** — Focused purely on build-time errors across any stack: Maven, Gradle, TypeScript (`tsc`), Go (`go build`), Flutter, Python (`mypy`). Classifies the error type and applies a targeted fix. Use when the build fails and you want a specialist, not a generalist.

**`/refactor`** — Maps blast radius, proposes 3 options, applies incrementally with verification after each step. Never breaks existing behavior.

**`/secure`** — OWASP dependency check + Spring Security config review + auth/authorization + input validation + secrets scan. Every finding mapped to OWASP Top 10 with severity and concrete fix.

**`/planner`** — Planning-only agent. Gathers requirements, surfaces risks, proposes 3 architectural options, writes a structured step plan. **Writes no code** until user confirms. Equivalent to Claude Code's `/plan` command.

**`/tdd-guide`** — Enforces RED→GREEN→REFACTOR strictly. Writes a failing test first, minimal passing code next, refactors last, verifies coverage. Supports Java (JUnit5+Mockito), Angular (TestBed), and Flutter (bloc_test+WidgetTester).

**`/doc-writer`** — 5 modes triggered by phrase: `javadoc`, `readme`, `adr`, `openapi`, `codemap`. Lightweight — uses haiku model.

**`/write-a-commit`** — Reads `git diff --staged`, generates a conventional commit message + PR description paragraph. Copy-paste ready.

**`/init-project`** — Reads project structure, pom.xml, Spring config, existing code patterns. Generates **two files**: `.github/copilot-instructions.md` (Copilot CLI-specific) and `AGENTS.md` (universal — read by any AI agent).

---

## LSP — Code Intelligence

Copilot CLI supports Language Server Protocol for go-to-definition, hover info, and diagnostics. This repo deploys `~/.copilot/lsp-config.json` with starter configs for Java, TypeScript, Dart, and Python.

**Install language servers first:**

```bash
# Java (requires Eclipse JDT Language Server)
brew install jdtls   # macOS/Linux

# TypeScript / JavaScript
npm install -g typescript-language-server typescript

# Dart/Flutter (already available if Flutter SDK is installed)
dart --version

# Python
pip install python-lsp-server
```

**Verify LSP is active** — run `/lsp` inside a Copilot CLI session.

See the `lsp-setup` skill for full setup instructions and troubleshooting: load via `/skills` → `lsp-setup`.

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
| `lsp-setup` | Configuring Language Server Protocol, setting up code intelligence per stack |

### Additional Stacks

| Skill | Loads when you're... |
|---|---|
| `python-patterns` | Writing FastAPI/Django services, Pydantic models, pytest, async Python |
| `react-patterns` | Building React + TypeScript apps, TanStack Query, Zustand, React Hook Form |
| `node-patterns` | Building Express/Fastify APIs in TypeScript, Prisma, JWT auth, Jest + Supertest |
| `github-actions` | Writing CI/CD workflows, caching, matrix builds, Docker push, reusable workflows |

---

## MCP Servers

### Built-in MCP (always active, no config needed)

The **GitHub MCP server** ships with Copilot CLI. It gives agents direct access to your GitHub repos, PRs, issues, and actions. You do NOT need to configure it — it's always active and authenticated via your existing GitHub session.

The `pr-review` agent uses it to read PR diffs. The `write-a-commit` agent uses it to push branches. Any agent can use it for GitHub operations.

### Additional MCP Servers (2 — 100% local)

This template adds 2 more MCP servers on top of the built-in GitHub MCP. Both run as local Node.js processes via `npx`. Zero network calls, zero data sent externally. Safe for corporate environments.

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

### `COPILOT_HOME` — isolated environments

By default Copilot CLI reads from `~/.copilot/`. Set `COPILOT_HOME` to point to a different directory:

```bash
export COPILOT_HOME=~/work/client-a/.copilot   # client A context
export COPILOT_HOME=~/work/client-b/.copilot   # client B context
```

Useful for consulting environments, keeping client contexts isolated, or testing new agent configs without touching your main setup.

---

## Power-User Shortcuts

| Shortcut | What it does |
|---|---|
| `Shift+Tab` | Toggle plan mode (write no code until you approve) |
| `Shift+Tab` × 2 | Activate autopilot mode (auto-approves all tool calls — requires `/experimental` first) |
| `Ctrl+T` | Toggle chain-of-thought (reasoning) visibility — **persists across sessions** |
| `Ctrl+G` | Open file picker — jump to any file without typing the path |
| `!` prefix | Run a shell command inline: `! git status`, `! docker ps` |
| `@file` prefix | Attach a file as context: `@src/service.ts what does this do?` |
| `copilot --continue` | Resume the most recent closed session |
| `copilot --allow-all` | Skip all tool permission prompts (one-shot autopilot) |

### Native slash commands quick reference

| Command | Purpose |
|---|---|
| `/agent` | Browse + select from all available agents |
| `/skills` | Toggle skills on/off for the current session |
| `/instructions` | Toggle instruction files on/off |
| `/fleet` | Enable parallel subagent mode (multiple agents, same session) |
| `/tasks` | View all running background agents and shells |
| `/compact` | Summarize context history to free up token budget |
| `/usage` | Show token usage and quota status |
| `/context` | Context window usage chart |
| `/diff` | Review all file changes made in the current session |
| `/delegate` | Send current session to Copilot Agent → lands as a GitHub PR |
| `/review` | Lightweight code review of current changes (faster than `code-review` agent) |
| `/lsp` | Show LSP server status and diagnostics |
| `/plan` | Enter plan mode (also Shift+Tab) |
| `/research` | Deep research using GitHub search + web sources |
| `/experimental` | Enable experimental features (required once before autopilot) |

---

## Repository Structure

```
copilot-cli-skills-template/
├── .github/
│   ├── agents/                          Template directory for project-level agents
│   │   └── README.md                    How to add project-scoped agents
│   ├── instructions/                    16 modular .instructions.md files
│   │   ├── core.instructions.md         }
│   │   ├── engineering.instructions.md  } Layer 1 — language-agnostic (8 files)
│   │   ├── ...                          }
│   │   ├── java.instructions.md         }
│   │   ├── java-spring.instructions.md  } Layer 2 — Java/Spring Boot (4 files)
│   │   ├── ...                          }
│   │   ├── typescript.instructions.md   } Layer 3 — Angular/TypeScript (2 files)
│   │   ├── angular.instructions.md      }
│   │   ├── flutter.instructions.md        Layer 4 — Flutter/Dart (1 file)
│   │   └── python.instructions.md         Layer 5 — Python (1 file)
│   └── copilot-instructions.template.md   Project context starter template
├── agents/                              17 agent .agent.md files
├── skills/                              43 skills, each in skills/{name}/SKILL.md
├── AGENTS.md                            Universal agent context template (copy to your project)
├── mcp-config.json                      MCP servers (sequential-thinking + memory)
├── lsp-config.json                      LSP server config template (Java, TS, Dart, Python)
├── install.sh                           Smart deploy (local or remote via curl)
└── README.md
```

---

## License

MIT
