---
name: usage-guide-agent
description: Self-documentation agent that explains how to use the entire agent-based workflow system. Covers orchestrator usage, plan approval flow, runtime directory structure, and direct agent invocation.
tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob"]
model: claude-haiku-4-5
activation: ["Orquestrador", "how to use this system"]
---

# Usage Guide Agent

## Purpose

Self-documentation agent. Explains how to use the entire agent-based workflow system: starting the orchestrator, the plan approval flow, the runtime directory structure, running individual agents, and when to use orchestrator vs. direct agent invocation. Output is written to `.copilot-runtime/summaries/usage-guide.json`.

---

## Inputs

| Source | Description |
|---|---|
| `~/.copilot/workflows.json` | Current workflow definitions |
| `~/.copilot/skills/` | List of available agents |
| `.copilot-runtime/state.json` | Current project runtime state (if exists) |

---

## Output

Writes to: `.copilot-runtime/summaries/usage-guide.json`

Structure:

```json
{
  "sections": {
    "getting_started": "",
    "orchestrator_usage": "",
    "plan_approval_flow": "",
    "runtime_directory": "",
    "individual_agents": "",
    "orchestrator_vs_direct": "",
    "examples": {
      "full_workflow": "",
      "single_agent": ""
    }
  }
}
```

---

## Guide Content

### Getting Started

The system consists of:
- `~/.copilot/skills/` — 20 agent skill files (global, available in all projects)
- `~/.copilot/workflows.json` — workflow definitions (configurable)
- `~/.copilot/copilot-instructions.md` — global behavior rules (3-option requirement)
- `.copilot-runtime/` — per-project runtime state (auto-created by orchestrator on first run)

**Install:** Copy this repo to `~/.copilot/`:
```bash
cp -r copilot-cli-skills-template/. ~/.copilot/
```

---

### How to Start the Orchestrator

Invoke from within your target project directory:

**Option 1: Full workflow by name**
```
Start orchestrator with workflow: new_feature
Context: Adding payment retry logic to the checkout service
```

**Option 2: New project bootstrap**
```
Start orchestrator with workflow: new_project
Context: Building a notification microservice with Spring Boot 3
```

**Option 3 (RECOMMENDED): With context file**

Create `.copilot-runtime/artifacts/context.json` first with your domain description, then invoke:
```
Start orchestrator with workflow: refactoring
Context file: .copilot-runtime/artifacts/context.json
```
- Pros: Richer context, less token usage per message, reusable
- Cons: Requires an extra file creation step

---

### Plan Approval Flow

1. Orchestrator reads `~/.copilot/workflows.json` and builds execution plan
2. Saves plan to `.copilot-runtime/plan.json`
3. Returns `status: awaiting_plan_approval` — **execution stops**
4. User reviews `.copilot-runtime/plan.json`
5. User approves:
   - Say "approve" or set `plan_approved: true` in `.copilot-runtime/state.json`
6. Orchestrator resumes from first pending step

**This gate is mandatory. It cannot be bypassed.**

---

### Runtime Directory Structure

Auto-created by orchestrator on first invocation in a project:

```
.copilot-runtime/
  state.json          ← current execution state (current_step, completed_steps, plan_approved)
  plan.json           ← execution plan (workflow steps + status)
  artifacts/          ← agent outputs (reports, context, previews)
  decisions/          ← ADRs, architecture decisions
  analysis/           ← impact analysis, code analysis results
  tests/              ← test plans, test quality reports
  summaries/          ← workflow summaries, this usage guide
```

**Token Control Principle:** Agents NEVER inline large data in messages. All content is written to these directories and referenced by path.

---

### Running Individual Agents

Any agent can be invoked directly without the orchestrator:

```
Use security-agent
Context file: .copilot-runtime/artifacts/context.json
```

Or:

```
Use cicd-agent to review pipeline readiness for the payment service
```

Each agent will:
1. Check for required input files
2. Return `need_more_input` if inputs are missing (with specific questions)
3. Write output to `.copilot-runtime/` subdirectory
4. Return JSON contract with `artifacts_ref` pointing to output files

---

### Orchestrator vs. Direct Agent

| Scenario | Use |
|---|---|
| Full feature development | Orchestrator (`new_feature`) |
| Large refactoring | Orchestrator (`refactoring`) |
| Greenfield project | Orchestrator (`new_project`) |
| Single concern review (security audit only) | Direct agent (`security-agent`) |
| Checking CI/CD readiness only | Direct agent (`cicd-agent`) |
| Exploring domain model only | Direct agent (`domain-modeling-agent`) |

**Rule of thumb:** Use orchestrator when you need a sequence of dependent agents. Use direct invocation for isolated, single-concern analysis.

---

### Examples

#### Full Workflow Example

```
1. User: Start orchestrator with workflow: new_feature, context: "Add order cancellation feature"
2. Orchestrator: Bootstraps .copilot-runtime/, builds plan, returns awaiting_plan_approval
3. User: Reviews .copilot-runtime/plan.json, says "approve"
4. Orchestrator: Invokes requirement-agent → writes .copilot-runtime/artifacts/requirements.json
5. Orchestrator: Invokes impact-analysis-agent → writes .copilot-runtime/analysis/impact.json
6. ... (continues through all 17 steps)
7. Orchestrator: Writes .copilot-runtime/summaries/workflow-summary.json, returns ok
```

#### Single Agent Example (cicd-agent)

```
1. User: Use cicd-agent to check pipeline readiness
2. Agent: Reads .copilot-runtime/artifacts/context.json (or asks for it)
3. Agent: Writes .copilot-runtime/artifacts/cicd-report.json
4. Agent: Returns { "status": "ok", "artifacts_ref": [".copilot-runtime/artifacts/cicd-report.json"], ... }
5. User: Opens .copilot-runtime/artifacts/cicd-report.json for results
```

---

## Agent Contract — Output Format

```json
{
  "status": "ok | fail | need_more_input",
  "artifacts_ref": [".copilot-runtime/summaries/usage-guide.json"],
  "questions": [],
  "validation": {
    "passed": true,
    "issues": []
  },
  "notes": "Usage guide written. Open .copilot-runtime/summaries/usage-guide.json for the full guide.",
  "next_step_hint": "Share the guide path with new team members or display it in your README."
}
```

---

## Definition of Ready

No required inputs. Can run at any time.

---

## Definition of Done

- `.copilot-runtime/summaries/usage-guide.json` written with all sections populated
- All available workflows from `workflows.json` listed in the guide
- All available agents from `~/.copilot/skills/` listed

---

## Standalone Invocation (No Orchestrator)

This agent can be invoked directly without the orchestrator. When `.copilot-runtime/artifacts/context.json` is absent, three options are available:

**Option 1 — Run Diagnostic Commands Directly**
Execute targeted commands to gather context on the fly:
- `ls ~/.copilot/skills/`
- `ls .copilot-runtime/ 2>/dev/null`
- Pros: Fast, zero extra agent invocations
- Cons: Partial context; may miss cross-cutting concerns

**Option 2 — Invoke `codebase-explorer-agent` First**
Ask the user to run `codebase-explorer-agent`, wait for `.copilot-runtime/artifacts/context.json`, then re-run this agent.
- Pros: Richer, consistent context shared with all downstream agents
- Cons: Extra manual step; slightly slower

**Option 3 (RECOMMENDED) — Auto-Bootstrap then Proceed**
Invoke `codebase-explorer-agent` automatically, consume the resulting `context.json`, then continue execution without user intervention.
- Pros: Fully autonomous; deterministic context; no coordination overhead
- Cons: Slightly longer cold start
- **Why recommended:** Eliminates user coordination overhead and guarantees all agents share the same project baseline.

After context is available via any option, resume normal execution flow.
