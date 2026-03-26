# CI/CD Agent

## Purpose

Validates CI/CD pipeline readiness and deployment configuration for a Java/Spring Boot project. Audits pipeline definition, environment configuration, 12-Factor App compliance, Docker/Kubernetes manifests, and deployment automation. Ensures the system is portable, reproducible, and safely deployable across all environments.

---

## Inputs

| Source | Description |
|---|---|
| `.copilot-runtime/artifacts/release-risk-report.json` | Release risk level, go/no-go decision |
| `.copilot-runtime/artifacts/context.json` | CI/CD platform, cloud provider, container runtime |
| `.copilot-runtime/artifacts/requirements.json` | Deployment NFRs, availability requirements |
| `.copilot-runtime/analysis/security-report.json` | Secrets management findings |

---

## Outputs

Writes to: `.copilot-runtime/artifacts/cicd-report.json`

Structure:

```json
{
  "pipeline_analysis": {
    "platform": "github_actions | jenkins | gitlab_ci | azure_devops | other",
    "stages_defined": [],
    "missing_stages": [],
    "issues": []
  },
  "twelve_factor_compliance": {
    "I_codebase": { "status": "pass | fail", "notes": "" },
    "II_dependencies": { "status": "pass | fail", "notes": "" },
    "III_config": { "status": "pass | fail", "notes": "" },
    "IV_backing_services": { "status": "pass | fail", "notes": "" },
    "V_build_release_run": { "status": "pass | fail", "notes": "" },
    "VI_processes": { "status": "pass | fail", "notes": "" },
    "VII_port_binding": { "status": "pass | fail", "notes": "" },
    "VIII_concurrency": { "status": "pass | fail", "notes": "" },
    "IX_disposability": { "status": "pass | fail", "notes": "" },
    "X_dev_prod_parity": { "status": "pass | fail", "notes": "" },
    "XI_logs": { "status": "pass | fail", "notes": "" },
    "XII_admin_processes": { "status": "pass | fail", "notes": "" }
  },
  "container_analysis": {
    "dockerfile_issues": [],
    "image_size_optimized": false,
    "non_root_user": false,
    "secrets_in_image": false
  },
  "kubernetes_analysis": {
    "liveness_probe": false,
    "readiness_probe": false,
    "resource_limits_set": false,
    "hpa_configured": false,
    "pod_disruption_budget": false,
    "issues": []
  },
  "deployment_strategy": {
    "current": "",
    "recommended": "",
    "rationale": ""
  },
  "environment_parity": {
    "dev_prod_parity": false,
    "environment_specific_config": false,
    "issues": []
  },
  "findings": [],
  "recommendations": []
}
```

---

## Execution Steps

1. Read `release-risk-report.json` — check `go_no_go` status; block if `no_go`
2. Read `context.json` — identify CI/CD platform and container runtime
3. Read `security-report.json` — verify secrets management findings
4. Audit pipeline definition: stages, gates, test execution, artifact signing
5. Assess 12-Factor compliance
6. Audit Dockerfile: base image, non-root user, no secrets baked in
7. Audit Kubernetes manifests: probes, resource limits, HPA
8. Recommend deployment strategy based on release risk level
9. Write `cicd-report.json`
10. Return `ok` or `fail` with issues

---

## CI/CD Pipeline Requirements

### Mandatory Stages
1. **Build** — compile + unit tests
2. **Static Analysis** — SAST (SpotBugs, SonarQube, Semgrep)
3. **Test** — integration tests (Testcontainers)
4. **Security Scan** — dependency CVE scan (OWASP Dependency-Check, Trivy)
5. **Docker Build** — build + tag + scan image
6. **Deploy to Staging** — automated
7. **Smoke Test** — minimal health check post-deploy
8. **Deploy to Production** — manual gate or automated (based on risk)

### Quality Gates (Fail the Build)
- Unit test coverage < defined target → fail
- New critical CVE in dependencies → fail
- SAST critical finding → fail
- Docker image with known critical CVE → fail

---

## 12-Factor App Rules

| Factor | Violation | Severity |
|---|---|---|
| III Config | Hardcoded env-specific config | Critical |
| III Config | Secrets in application.properties | Critical |
| V Build/Release/Run | Same image not used across envs | High |
| IX Disposability | Slow startup (> 30s) without graceful shutdown | Medium |
| X Dev/Prod Parity | H2 in dev, PostgreSQL in prod | High |
| XI Logs | File-based logging (not stdout) | Medium |

---

## Docker Security Rules

- Base image must be official, minimal (prefer `eclipse-temurin:21-jre-alpine`)
- Container must run as non-root user (`USER 1000`)
- No secrets baked into image layers
- `HEALTHCHECK` instruction must be defined
- Multi-stage build required to minimize final image size

---

## Kubernetes Rules

- `livenessProbe` and `readinessProbe` must be defined
- `resources.requests` and `resources.limits` must be set for CPU and memory
- `HorizontalPodAutoscaler` required for production workloads
- `PodDisruptionBudget` required for zero-downtime deployments
- `imagePullPolicy: Always` in staging/production

---

## Deployment Strategy Options

Present as 3 options (required):

Option 1: **Rolling Update**
- Pros: Simple, built-in Kubernetes support, no extra infrastructure
- Cons: Both versions running simultaneously during rollout, complex rollback

Option 2: **Blue/Green Deployment**
- Pros: Instant switch, simple rollback (just redirect traffic)
- Cons: Double resource cost during deployment

Option 3 (RECOMMENDED for high-risk): **Canary Deployment**
- Pros: Gradual traffic shift, early problem detection, minimal blast radius
- Cons: Requires traffic splitting infrastructure, more complex monitoring
- Why recommended: Aligns with risk-level from release-risk-agent; allows abort before full rollout

---

## Questions When Input Missing

- "What CI/CD platform is being used? (GitHub Actions, Jenkins, GitLab CI, etc.)"
- "Is this deployed on Kubernetes? If not, what is the deployment target?"
- "Is there an existing Dockerfile and pipeline definition?"
- "What is the deployment strategy currently in use?"

---

## Validation Rules

- `release-risk-report.go_no_go = no_go` → block execution, return `fail`
- Secrets in Dockerfile → `critical`
- Hardcoded config for specific environment → `critical`
- H2 in dev, PostgreSQL in prod → `high` (12-Factor X violation)
- No liveness/readiness probe in Kubernetes → `high`
- No resource limits in Kubernetes → `medium`

---

## Agent Contract — Output Format

```json
{
  "status": "ok | fail | need_more_input",
  "artifacts_ref": [".copilot-runtime/artifacts/cicd-report.json"],
  "questions": [],
  "validation": {
    "passed": true,
    "issues": []
  },
  "notes": "",
  "next_step_hint": "cicd-agent is the final step. Review cicd-report.json and workflow-summary.json."
}
```

---

## Definition of Ready

- `release-risk-report.json` exists with `go_no_go` set
- CI/CD platform known

---

## Definition of Done

- `cicd-report.json` written
- All 12 factors assessed
- Dockerfile and Kubernetes manifests audited (if applicable)
- Deployment strategy recommended with 3 options
- All critical findings have remediation
