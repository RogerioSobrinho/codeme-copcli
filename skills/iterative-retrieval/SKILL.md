---
name: iterative-retrieval
description: Progressive context-loading strategy for large codebases. Covers Layer 1/2/3 expansion, stop conditions, token budget management, grep-before-read rule, and context pruning. Load when working in a large codebase to avoid loading unnecessary files into context.
---

# Iterative Retrieval

## Core Principle

Loading entire files blindly wastes context budget and adds noise. Start minimal, expand only when blocked.

**Rule:** Never read a full file when a targeted grep can answer the question.

---

## Three-Layer Expansion

### Layer 1 — Structural Reconnaissance (Always Run First)

Goal: Understand scope without reading any file content.

```bash
# 1. Project structure
find src/main/java -name "*.java" | sed 's|src/main/java/||; s|/|.|g; s|.java$||' | sort

# 2. Public API surface (method signatures)
grep -rn "public.*\(.*\)" src/main/java --include="*.java" | grep -v "test\|Test" | head -50

# 3. Package organization
find src/main/java -type d | sort

# 4. What Spring beans exist?
grep -rn "@Service\|@Repository\|@Component\|@RestController" src/main/java --include="*.java" | sort

# 5. What are the main entry points?
grep -rn "@RestController\|@Controller" src/main/java --include="*.java" -l
```

**Stop condition for Layer 1:** If the needed file is identified and its purpose is clear from its name and package, proceed to targeted read. Do NOT read all files in a package.

---

### Layer 2 — Targeted Content Search

Goal: Find the specific code relevant to the task.

```bash
# Find a specific method or class
grep -rn "class OrderService\|void processOrder\|OrderService {" src/main/java --include="*.java"

# Find usages of a class/method
grep -rn "OrderService\|\.processOrder(" src/main/java --include="*.java"

# Find configuration for a topic
grep -rn "kafka\|datasource\|redis" src/main/resources/ -i --include="*.yml" --include="*.properties"

# Find tests for a component
find src/test/java -name "OrderServiceTest.java" -o -name "OrderApiTest.java"

# Find error handling
grep -rn "@ExceptionHandler\|ResponseEntityExceptionHandler" src/main/java --include="*.java"
```

**Stop condition for Layer 2:** If the grep result shows the exact lines needed (< 30 lines), read only those lines using `sed -n '{start},{end}p' file.java`. Only proceed to Layer 3 if context is insufficient.

---

### Layer 3 — Full File Read (Justified Reads Only)

Triggers for full file read:
- The class has complex internal state that cannot be understood from a snippet
- A method's behavior depends on multiple private methods in the same file
- Refactoring an entire class

```bash
# Read only the file you need
cat src/main/java/com/example/orders/service/OrderService.java

# Read a specific range (prefer this over full read)
sed -n '45,120p' src/main/java/com/example/orders/service/OrderService.java

# Read multiple targeted ranges
awk 'NR>=45 && NR<=80 || NR>=150 && NR<=180' OrderService.java
```

---

## Token Budget

Approximate context token cost per operation:

| Operation | Approx. Tokens | Use When |
|---|---|---|
| Grep result (50 matches) | 500–1,000 | Always prefer over file read |
| Single method (20 lines) | 200–400 | Specific implementation needed |
| Single class (150 lines) | 1,500–3,000 | Full class understanding needed |
| Entire package (10 classes) | 15,000–30,000 | Only for small utility packages |
| Full source tree listing | 500–2,000 | Layer 1 reconnaissance |

**Budget target:** Keep context additions per task under 10,000 tokens from file reads. If approaching limit, prune before expanding.

---

## Grep-Before-Read Rule

The question to ask before opening a file:
> "Can a grep pattern answer this question without reading the file?"

| Question | Grep Pattern |
|---|---|
| Does method X exist? | `grep -rn "methodX\("` |
| Where is X used? | `grep -rn "\.methodX(\|new X()"` |
| What exceptions does X throw? | `grep -n "throw\|throws" TargetClass.java` |
| What @Beans are defined? | `grep -n "@Bean" TargetFile.java` |
| What are the DB column names? | `grep -n "columnDefinition\|@Column(name" Entity.java` |
| Is there an existing test for X? | `find src/test -name "*X*Test.java"` |

---

## Context Pruning Checklist

Before each new Layer 3 read, evict context that is no longer needed:

- [ ] Configuration files already read and understood? Remove from active context.
- [ ] Test files read to understand behavior? Can be pruned once patterns are noted.
- [ ] Old versions of files that were refactored? Remove.
- [ ] Dependency/library source (not project code)? Should never be in context — grep is sufficient.

**Rule:** At any given moment, keep in active context only the files directly relevant to the current sub-task. When starting a new sub-task, re-evaluate what's needed.

---

## Stop Conditions Summary

| Condition | Stop Because |
|---|---|
| Found the method/class implementation | No need to read surrounding code |
| Identified that X does NOT exist | Search complete; proceed to create |
| Found 3+ usages confirming a pattern | Pattern understood; stop expanding |
| Layer 1 confirms the file is in a different service | Out of scope; stop |
| Token budget approaching 80% | Prune before reading anything else |
