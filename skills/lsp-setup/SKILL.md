---
name: lsp-setup
description: >
  Load when configuring Language Server Protocol (LSP) for Copilot CLI, setting up code intelligence,
  running /lsp, editing lsp-config.json, installing language servers (jdtls, tsserver, pylsp, dart),
  or when asked "how do I get go-to-definition in Copilot CLI", "how do I enable LSP",
  "how do I configure the language server", "why is code intelligence not working".
---

# LSP Setup for Copilot CLI

LSP (Language Server Protocol) gives Copilot CLI deeper code intelligence: go-to-definition, hover info, diagnostics, and symbol awareness. It enables the agent to understand your code structurally, not just textually.

## Configuration File Locations

Copilot CLI loads LSP config from two places (project takes precedence):

| Scope | Path | Activation |
|-------|------|------------|
| **User-level** (all projects) | `~/.copilot/lsp-config.json` | Always active |
| **Project-level** | `.github/lsp.json` | Active when working inside that repo |

## Config Format

```json
{
  "lspServers": {
    "<language-key>": {
      "command": "<binary>",
      "args": ["<arg1>", "<arg2>"],
      "fileExtensions": {
        ".ext": "<language-id>"
      }
    }
  }
}
```

## Per-Stack Setup

### Java (Eclipse JDT Language Server)

**Install:**
```bash
# Via homebrew (macOS/Linux)
brew install jdtls

# Or download manually:
# https://download.eclipse.org/jdtls/snapshots/
# Unpack and add jdtls wrapper to PATH
```

**Config:**
```json
{
  "lspServers": {
    "java": {
      "command": "jdtls",
      "args": [],
      "fileExtensions": { ".java": "java" }
    }
  }
}
```

### TypeScript / JavaScript

**Install:**
```bash
npm install -g typescript-language-server typescript
```

**Config:**
```json
{
  "lspServers": {
    "typescript": {
      "command": "typescript-language-server",
      "args": ["--stdio"],
      "fileExtensions": {
        ".ts": "typescript",
        ".tsx": "typescript",
        ".js": "javascript",
        ".jsx": "javascript"
      }
    }
  }
}
```

### Dart / Flutter

**Install:** Dart SDK includes the language server. Ensure `dart` is in PATH.

```bash
dart --version  # verify
```

**Config:**
```json
{
  "lspServers": {
    "dart": {
      "command": "dart",
      "args": ["language-server", "--client-id=copilot-cli"],
      "fileExtensions": { ".dart": "dart" }
    }
  }
}
```

### Go

**Install:**
```bash
go install golang.org/x/tools/gopls@latest
```

**Config:**
```json
{
  "lspServers": {
    "go": {
      "command": "gopls",
      "args": [],
      "fileExtensions": { ".go": "go" }
    }
  }
}
```

### Python

**Install:**
```bash
pip install python-lsp-server
# or: pip install pylsp
```

**Config:**
```json
{
  "lspServers": {
    "python": {
      "command": "pylsp",
      "args": [],
      "fileExtensions": { ".py": "python" }
    }
  }
}
```

## Verify LSP Is Running

Inside a Copilot CLI session:
```
/lsp
```

This shows configured servers, their status (running/stopped), and any errors.

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| LSP server not found | Binary not in PATH | Run `which <command>` and install if missing |
| Java LSP crashes | Missing JDK or wrong JAVA_HOME | `echo $JAVA_HOME` — must point to JDK 17+ |
| TypeScript LSP slow | No `tsconfig.json` in project | Add a minimal `tsconfig.json` |
| Python LSP missing modules | Dependencies not installed | Run `pip install python-lsp-server[all]` |

## When LSP Improves Copilot Responses

LSP is most valuable when:
- Navigating a large codebase with many classes/files
- Debugging — the agent can hover on types and follow references
- Refactoring — symbol-aware rename and impact analysis
- Reviewing unfamiliar code — the agent understands method signatures, not just text patterns
