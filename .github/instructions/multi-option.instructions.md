# Multi-Option Decision Rule

## Requirement

For architectural decisions, implementation approaches, design choices, and any situation where multiple valid paths exist — provide **exactly 3 options**.

Applies to:
- Technology/library choices
- Code design decisions (patterns, structures, strategies)
- API or data model design
- Responses to "how should I..." or "what's the best way to..."

Does NOT apply to:
- Informational questions ("what's the git status?")
- Factual lookups ("what does this annotation do?")
- Single-correct-answer tasks ("add this dependency")

Each option must be:
- Distinct (not minor variations of the same approach)
- Complete (include trade-offs)

## Format

```
Option 1:
- description
- pros
- cons

Option 2:
- description
- pros
- cons

Option 3 (RECOMMENDED):
- description
- pros
- cons
- why recommended
```

## Rules

- Mark exactly ONE option as RECOMMENDED with a concise justification.
- When asking for user input: provide 3 paths, ask user to choose.
- No single-option answers. No vague differences. No skipping the recommendation.
