---
name: skill-authoring
description: >
  Load when converting internal documentation, a block of text, code examples, or copied
  standards into a Copilot CLI SKILL.md file, when deciding whether a piece of knowledge
  should become a SKILL.md, a copilot-instructions.md section, or a new agent, when writing
  the description for a skill so it triggers at the right moment (not too broad, not too
  narrow), or when asked "how do I add this internal standard to Copilot", "turn this into
  a skill", "should this be a skill or instructions", "I have this text, how do I make Copilot
  use it automatically".
---

# Skill Authoring

Converting internal knowledge into precision-triggered Copilot CLI skills.

---

## Decision: SKILL.md vs copilot-instructions.md vs Agent

Before writing anything, answer these questions:

| Question | Answer → Use |
|---|---|
| Is this reusable across many projects? | SKILL.md in `~/.copilot/skills/` |
| Is this specific to one project or codebase? | `.github/copilot-instructions.md` |
| Does this require reading files + making decisions? | Agent (`.agent.md`) |
| Is this a reference developers look up mid-task? | SKILL.md |
| Is this a rule that should ALWAYS be active? | `copilot-instructions.md` |
| Is this a multi-step workflow? | Agent |

**Rule of thumb:**
- **SKILL** = reference knowledge. Loaded when the topic comes up. Example: hexagonal architecture conventions, internal plugin usage, JVM tuning standards.
- **copilot-instructions.md** = always-on constraints. Example: "always use constructor injection", "never expose JPA entities".
- **Agent** = a job to be done. Example: "run a security audit", "generate a new feature".

---

## Anatomy of a Good SKILL.md

```yaml
---
name: company-a-hexagonal           # kebab-case, lowercase, unique
description: >
  Load when structuring a new feature using {CompanyName} hexagonal architecture,
  creating a Port interface, writing an Adapter class, implementing a UseCase,
  or when asked "where does this logic go in our architecture", "how do I add a new
  port", "what layer does this belong to".
---
```

The `description` is the **trigger mechanism**. It must contain:
1. **Specific technical terms** that appear naturally when the topic is relevant
2. **Explicit trigger phrases** in quotes — what the user might actually type
3. **Negative scope** — NOT "Load when working with Java" (too broad)

---

## Converting a Text Block to SKILL.md

### Step 1 — Extract Signal, Discard Noise

Given any internal doc (text, pasted examples, screenshots converted to text), extract only:
- Named conventions ("we always X", "never Y")
- Code examples that show the pattern
- Anti-patterns explicitly mentioned
- Naming rules or structure rules

**Discard:**
- Background/history ("we decided this in 2019 because...")
- Meeting notes / status updates
- Rationale discussions (keep only the decision)
- Redundant explanations of the same rule

### Step 2 — Identify the Trigger Moment

Ask: **When would a developer need this?**

Bad trigger (too broad):
```yaml
description: >
  Load when working on the backend.
```

Good trigger (specific):
```yaml
description: >
  Load when creating a UseCase class in com.company.{domain}.application,
  implementing a Port interface in com.company.{domain}.domain.port,
  writing an Adapter in com.company.{domain}.infrastructure, or when asked
  "where does this validation go", "should this be a domain service or use case".
```

**The test:** Read the description aloud. Would you naturally say these exact words when you need this knowledge? If yes, the trigger is right.

### Step 3 — Write the SKILL body

Structure:

```markdown
# {Skill Name}

## Quick Reference
{1-2 sentences: what this skill covers}

## {Main Pattern or Rule}
{Code example or step-by-step}

## {Second Pattern}
{Code example}

## Anti-Patterns
{What NOT to do, with examples}

## Decision Guide
{Table or flowchart for common decisions}
```

Rules for the body:
- Lead with code examples, not prose explanations
- Keep prose to 1-2 sentences per concept
- Use tables for decision points
- Mark anti-patterns clearly with ❌
- Include naming patterns explicitly (they're what actually varies between companies)

---

## Example Conversion

**Input text (from internal doc, pasted by user):**
> Our hexagonal architecture has three layers: domain, application, and infrastructure.
> Domain contains entities and port interfaces. Application contains use cases — one class per use case.
> Infrastructure has adapters. Use cases call port interfaces, never adapters directly.
> We use the naming convention: `{Verb}{Noun}UseCase.java` — e.g., `CreateOrderUseCase.java`.
> Controllers go in infrastructure/web. Kafka consumers go in infrastructure/messaging.
> A common mistake is putting business logic in adapters. Another is calling repositories from controllers.

**Output SKILL.md:**

```markdown
---
name: company-a-hexagonal
description: >
  Load when creating a UseCase class, implementing a Port interface, writing an Adapter,
  organizing code into domain/application/infrastructure packages, or when asked "where
  does this logic go", "should this be a use case or domain service", "what layer does
  this belong to", "how do I name this class in our architecture".
---

# Company A Hexagonal Architecture

## Layer Structure

\`\`\`
com.company.{domain}/
├── domain/
│   ├── model/          # Entities, Value Objects, domain exceptions
│   └── port/           # Port interfaces (no implementations here)
├── application/
│   └── usecase/        # One class per use case: {Verb}{Noun}UseCase.java
└── infrastructure/
    ├── web/            # REST controllers
    ├── messaging/      # Kafka/RabbitMQ consumers
    ├── persistence/    # JPA repositories
    └── external/       # HTTP clients
\`\`\`

## Naming Convention

| Type | Pattern | Example |
|---|---|---|
| Use case | {Verb}{Noun}UseCase | CreateOrderUseCase |
| Adapter (web) | {Noun}RestAdapter or {Noun}Controller | OrderController |
| Adapter (persistence) | {Noun}JpaAdapter | OrderJpaAdapter |

## Rules
- Use cases depend on Port interfaces, never on concrete Adapters
- Controllers call use cases, never repositories directly
- Domain model has zero Spring annotations

## Anti-Patterns ❌
- Business logic in Adapters — move it to a UseCase
- Controllers calling repositories — go through a UseCase
```

---

## Where to Store Company Skills

```bash
# Machine-local, never committed to any repo
~/.copilot/skills/
├── company-a-hexagonal/SKILL.md
├── company-a-spring-validation-plugin/SKILL.md
├── company-a-jvm-standards/SKILL.md
└── company-a-angular-flame/SKILL.md
```

These directories are automatically loaded by Copilot CLI. They never appear in any repository. When you move to Company B, you add Company B skills — Company A skills don't conflict because their triggers are specific.

To create a new local skill:
```bash
mkdir ~/.copilot/skills/company-a-{topic}
# Create SKILL.md with frontmatter (name + description) + body
```

---

## Minimum Viable Skill

If you have 15 minutes to convert internal knowledge:

```markdown
---
name: {company}-{topic}
description: >
  Load when {3-5 specific technical terms or phrases that appear when this is needed}.
---

# {Topic}

## The Rules
- {Rule 1 with code example}
- {Rule 2 with code example}

## Anti-Patterns
- ❌ {Common mistake with example}

## Quick Reference
{A table or code snippet that captures the most-referenced thing}
```

Even a minimal skill with real code examples beats having no skill at all.
