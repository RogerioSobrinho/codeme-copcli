# Git Workflow

## Conventional Commit Format

```
<type>(<scope>): <description>

<optional body>

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

**Types:** `feat` · `fix` · `refactor` · `docs` · `test` · `chore` · `perf` · `ci`

Rules:
- Description in imperative mood: "add feature" not "added feature"
- Body explains *why*, not *what* — the diff shows what
- Scope is optional but encouraged for large repos

## Pull Request Workflow

1. Analyze full commit history on the branch (not just the latest commit)
2. Use `git diff [base-branch]...HEAD` to see all changes
3. Draft a comprehensive PR description: what changed, why, and how to test
4. Include a test plan with any manual verification steps needed

## Git Discipline

- **Authorization:** Present diffs for review. Never commit secrets or generated artifacts.
- **Atomic commits:** One logical change per commit — easier to revert, bisect, and review.
- **Minimal diffs:** Do not touch unrelated lines or reformat files in the same commit.
