# Project-Level Agents

This directory contains **project-specific custom agents** for Copilot CLI.

Agents placed here are automatically available when working inside this repository. They complement (and can override) the user-level agents in `~/.copilot/agents/`.

## Scope Precedence

```
System agents (built-in)        ← highest priority
  ↓ overrides
Repository agents (.github/agents/)
  ↓ overrides  
User agents (~/.copilot/agents/)
  ↓ overrides
Organization agents (.github-private/agents/)  ← lowest priority
```

## When to Add a Project-Level Agent

Add agents here when the agent needs project-specific knowledge that doesn't belong in `~/.copilot/agents/` (which is generic across all your projects):

- **Domain context** — an agent that knows your specific domain model, bounded contexts, or business rules
- **Stack-specific conventions** — your company's internal framework, custom annotations, or proprietary patterns
- **Onboarding** — a guided tour agent for new team members that references actual files in this repo
- **Integration patterns** — an agent that knows how this service integrates with your internal systems

## File Format

Each agent is a `.agent.md` file with YAML frontmatter:

```markdown
---
name: onboarding
description: Guides new engineers through this codebase. Explains the domain model, key services, and how to run the project locally. Use when joining the team or returning after a long absence.
tools: ["read", "search", "shell"]
model: claude-sonnet-4.6
---

You are an expert on this codebase...
```

## Invoking Project Agents

```bash
# Interactive selection
/agent

# By name in prompt
"Use the onboarding agent to explain how the payment flow works"

# CLI flag
copilot --agent=onboarding --prompt "Explain the checkout flow"
```

## Example: Domain-Aware Reviewer

```markdown
---
name: domain-review
description: Reviews code changes against our domain model conventions. Knows our bounded contexts (Orders, Payments, Catalog), our event naming conventions, and our internal SDK usage patterns. Use instead of the generic code-review agent when reviewing domain logic.
tools: ["read", "search", "shell"]
model: claude-sonnet-4.6
---

You are a reviewer expert in this specific domain model.

## Our Domain Conventions
- Orders bounded context owns: Order, OrderLine, OrderStatus
- Payments bounded context owns: Payment, PaymentMethod, Refund
- Cross-context communication via domain events (never direct service calls)
- Event naming: {Entity}{PastTense} (e.g., OrderPlaced, PaymentConfirmed)
- Internal SDK: use `@InternalApi` from `com.company.sdk` — never call internal HTTP directly

## Review Steps
...
```
