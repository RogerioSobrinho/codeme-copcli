# Verification & Edit Safety

## Task Completion (Mandatory Gate)

**Never say "Done.", "Complete.", or equivalent until verification passes.**

Before closing any task:
1. Run the project's existing verification suite (build → lint → tests). Auto-detect:
   - TypeScript/JS: `npx tsc --noEmit` + `npx eslint . --quiet` + `npm test`
   - Python: `mypy .` + `ruff check .` + `pytest`
   - Java/Maven: `mvn verify -q` or `./gradlew build`
   - Rust: `cargo check` + `cargo test`
2. If no build/lint/test tooling is found in the project, **state that explicitly** to the user — never claim success silently.
3. Fix all failures before declaring done. Completion = verification passes, not bytes written.

## Edit Safety

**Before editing a file:**
- If the file hasn't been read in the last 10 turns, re-read it first. Context compaction may have destroyed your memory of it.
- For files over 500 lines, read in chunks using offset/limit rather than loading the entire file.

**After editing a file:**
- Re-read the edited section to confirm the change was applied exactly as intended.
- If the edit introduced new imports or dependencies, verify the added symbols actually exist.

## Rename & Move Safety

When renaming any symbol, function, class, file, or module, search ALL reference types — missing even one breaks the build:

1. **Grep for the literal string** — find direct usages
2. **Type references** — interfaces, generics, annotations that mention the old name
3. **String literals** — configuration files, decorators, reflection-based lookups
4. **Dynamic imports** — `import()`, `require()`, lazy-loaded routes
5. **Re-exports / barrel files** — `index.ts`, `index.js`, `__init__.py` that re-export the name
6. **Test mocks/spies** — `jest.mock('old-path')`, `vi.mock`, `@MockBean`, `patch('...')`

A rename is not complete until all six are checked and updated.

## Truncation Awareness

Search tools truncate results when output exceeds ~50K characters. Signs of truncation:
- Grep returns fewer results than expected (e.g., 2 matches for a widely-used symbol)
- Bash output ends mid-line or shows a truncation warning

When truncation is suspected:
- Re-run the search with a narrower scope (specific directory, file extension)
- Or read the full file directly rather than relying on grep output

## Self-Correction

When a mistake is discovered mid-task (wrong assumption, missed case, incorrect approach):
1. Stop — do not compound the error with more code
2. State what went wrong and why
3. If the project has an `AGENTS.md`, log the gotcha in the **Known Gotchas** section to prevent recurrence
4. Fix the root issue before continuing

At the start of a session on a known project, check `AGENTS.md` Known Gotchas for previously logged mistakes.
