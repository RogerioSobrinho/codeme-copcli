---
name: git-workflow
description: >
  Load when writing a git commit message (conventional commit format, type/scope/subject/body),
  naming a git branch (feat/, fix/, chore/, hotfix/), doing an interactive rebase (squash,
  fixup, reword, reorder commits), resolving a merge conflict, using git bisect to find a
  regression, managing git stash, or when asked "what type should this commit be",
  "how do I name this branch", "how do I clean up my commit history", "how do I find which
  commit broke this", "how do I undo this commit".
---

# Git Workflow

## Conventional Commits

### Format

```
{type}({scope}): {subject}

{body}

{footer}
```

### Types

| Type | Use when |
|---|---|
| `feat` | New feature or capability |
| `fix` | Bug fix |
| `refactor` | Code change with no behavior impact |
| `perf` | Measurable performance improvement |
| `test` | Test changes only |
| `docs` | Documentation only |
| `chore` | Build, dependencies, CI config |
| `style` | Formatting only (no logic) |
| `revert` | Reverting a prior commit |
| `ci` | CI/CD pipeline changes |

### Subject Rules

- Imperative mood: `add`, `fix`, `remove` — not `added`, `fixes`
- No period at the end
- Max 72 characters
- Lowercase

### Body

```
fix(orders): prevent duplicate order creation on retry

OrderService.createOrder() was not idempotent — calling it twice
with the same idempotency key created two DB records. Added a
uniqueness check on idempotency_key before insert.

Closes #142
```

### Breaking Changes

```
feat(api)!: change order response to include nested customer object

BREAKING CHANGE: GET /orders now returns { order: {...}, customer: {...} }
instead of a flat object. Consumers must update their deserialization.
```

---

## Branch Naming

```
{type}/{ticket-id}-{short-description}

# Examples
feat/ORD-142-idempotent-order-creation
fix/ORD-201-duplicate-payment-on-timeout
chore/update-spring-boot-3.3
hotfix/critical-auth-bypass
refactor/extract-order-domain-service
```

**Rules:**
- Use `-` (hyphen) as separator — no underscores, no spaces
- Include ticket ID when it exists
- Keep description ≤ 4 words
- `hotfix/` is for prod-critical issues on release branches
- Delete branches after merging (branch hygiene)

---

## Interactive Rebase — Clean History Before Merge

Squash, reorder, or reword commits before opening a PR:

```bash
# Rebase the last N commits interactively
git rebase -i HEAD~5

# Or rebase against the base branch
git rebase -i main
```

### Commands in rebase editor

```
pick   a1b2c3 feat: add order service
squash d4e5f6 wip: fix test       ← merge into previous commit
fixup  g7h8i9 fix typo            ← merge into previous, discard message
reword j1k2l3 feat: add repo      ← keep commit, edit message
drop   m4n5o6 debug logging       ← remove commit entirely
```

**Goal:** Each commit in the final PR should:
1. Pass all tests on its own
2. Represent a single logical change
3. Have a meaningful commit message

### Abort an in-progress rebase

```bash
git rebase --abort
```

---

## Conflict Resolution

```bash
# See conflicting files
git status

# For each conflicted file, choose:
git checkout --ours path/to/file    # Keep your version
git checkout --theirs path/to/file  # Keep the other version

# Or edit manually — look for conflict markers:
# <<<<<<< HEAD
# your changes
# =======
# incoming changes
# >>>>>>> feature/branch

# After resolving each file:
git add path/to/file

# Continue the merge/rebase
git merge --continue
git rebase --continue
```

**Strategy for complex conflicts:**
1. Understand BOTH changes before picking a side
2. For Java files: if both changed the same method, merge the intent, not the lines
3. For `pom.xml`/`build.gradle`: always take the higher version of a dependency

---

## git bisect — Find Which Commit Broke Something

```bash
# Start bisect
git bisect start

# Mark current state as broken
git bisect bad

# Mark a known-good commit
git bisect good v2.1.0
# or
git bisect good <commit-sha>

# Git checks out the midpoint — test and tell git the result
./mvnw test -Dtest=OrderServiceTest -q  # or whatever test demonstrates the bug

git bisect bad   # this commit is broken
git bisect good  # this commit is fine

# Repeat until git reports: "abc123 is the first bad commit"

# End bisect (returns to original HEAD)
git bisect reset
```

**Automating bisect:**
```bash
# Provide a script that exits 0 (good) or 1 (bad)
git bisect run ./scripts/test-regression.sh
```

---

## Useful Daily Commands

```bash
# Undo the last commit, keep changes staged
git reset --soft HEAD~1

# Undo the last commit, unstage changes (keep files)
git reset HEAD~1

# Discard all local changes (irreversible)
git reset --hard HEAD

# Save work in progress without committing
git stash push -m "wip: half-done payment refactor"
git stash list
git stash pop           # restore most recent stash
git stash apply stash@{2}  # restore specific stash

# Amend the last commit message (before push)
git commit --amend --no-edit    # keep message, add staged changes
git commit --amend -m "new message"

# Cherry-pick a specific commit to another branch
git cherry-pick <commit-sha>

# See what changed in the last N commits
git log --oneline -20
git show HEAD          # show the last commit's diff
git diff main...HEAD   # see all changes since branching from main
```

---

## PR Best Practices

**Before opening a PR:**
1. `git rebase main` — bring in the latest changes
2. `git diff main...HEAD` — review all your changes as a whole
3. Run the verification loop: `./mvnw verify -q`
4. Check commit messages are clean and conventional

**PR description structure:**
```markdown
## What
{1-2 sentences: what this PR adds or fixes}

## Why
{1-2 sentences: why this change is needed}

## How
{Optional: non-obvious implementation decisions}

## Testing
{How was this tested? What cases were covered?}

## Checklist
- [ ] Tests pass
- [ ] No new TODOs without ticket references
- [ ] API docs updated (if endpoints changed)
- [ ] Database migration added (if schema changed)
```
