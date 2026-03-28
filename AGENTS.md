# Project: {name}
# Location: AGENTS.md (repo root)
# Purpose: Shared agent context read by Copilot CLI, Claude Code, and any compatible AI coding agent.
#          Use this file for universal conventions visible to ALL agents and tools.
#          For Copilot CLI-specific context (skills, agents list), use .github/copilot-instructions.md
#
# Update this file when: core conventions change, architecture evolves, or a recurring mistake is discovered.
# Keep it short — this is a quick-start brief, not documentation.

---

# {Project Name}

## What This Project Does
{One paragraph: what the service/app does, who uses it, what problem it solves.}

## Tech Stack
- **Language**: {Java 21 / TypeScript / Python 3.12 / Dart / ...}
- **Framework**: {Spring Boot 3.x / Angular 17+ / Flutter / FastAPI / ...}
- **Database**: {PostgreSQL / MySQL / MongoDB / ...}
- **Infra**: {Docker / Kubernetes / AWS / GCP / ...}

## Architecture in One Paragraph
{Describe architectural style, layers, and key boundaries. Example:
"Hexagonal architecture. Domain layer has zero framework dependencies. Use cases in `application/`
call Port interfaces only. Controllers and Kafka consumers are adapters in `infrastructure/`. No
business logic in controllers — they translate HTTP to use-case calls exclusively."}

## Absolute Rules (for any AI agent)

### Always
- {Rule 1 — e.g., "Constructor injection only — never @Autowired on fields"}
- {Rule 2 — e.g., "All REST responses wrapped in ApiResponse<T>"}
- {Rule 3 — e.g., "@Transactional belongs on the service layer — never repositories or controllers"}
- {Rule 4 — e.g., "DTOs are Java records — never expose JPA entities in responses"}
- {Rule 5 — e.g., "Flyway for all schema changes — no manual DDL"}

### Never
- {Anti-pattern 1 — e.g., "No business logic in controllers or adapters"}
- {Anti-pattern 2 — e.g., "No Optional.get() without orElseThrow()"}
- {Anti-pattern 3 — e.g., "No @Transactional on repositories"}
- {Anti-pattern 4 — e.g., "No hardcoded secrets — use environment variables"}

## Testing
- {Test framework and style — e.g., "JUnit 5 + Mockito for unit, Testcontainers for integration"}
- {Naming convention — e.g., "methodName_givenContext_expectedBehavior"}
- {Coverage target — e.g., "80% line coverage via JaCoCo"}

## Known Gotchas
{Recurring mistakes or non-obvious behaviors — update whenever you hit a new one:}
- {Gotcha 1 — e.g., "PaymentClient has retry logic at infrastructure level — do NOT add @Retry at service level"}
- {Gotcha 2 — e.g., "OrderService.cancel() is idempotent — do not add duplicate-check guards"}

## Entry Points
- {Main entry point — e.g., "API: `src/main/java/.../OrderController.java`"}
- {Config entry point — e.g., "Spring config: `src/main/resources/application.yml`"}
- {Test entry point — e.g., "Integration tests: `src/test/java/.../integration/`"}
