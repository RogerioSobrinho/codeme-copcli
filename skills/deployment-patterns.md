---
name: deployment-patterns
description: Deployment and release patterns for Java/Spring Boot. Blue-green, canary, rolling deployments, Kubernetes health probes, and rollback procedures.
tools: ["Read", "Bash", "Grep", "Glob"]
model: claude-sonnet-4-5
activation: ["deploy", "deployment strategy", "blue green", "canary", "kubernetes deploy", "k8s", "rollback", "rolling update"]
---

# Deployment Patterns

## Purpose

Deployment and release strategy reference for Java/Spring Boot services on Kubernetes. Covers blue-green deployments, canary releases, rolling updates, Kubernetes health probe configuration, graceful shutdown, zero-downtime deployment checklists, rollback procedures, ConfigMap/Secret integration, and container resource sizing. Use this skill when designing a deployment strategy or troubleshooting release issues.

---

## Blue-Green Deployment

### How It Works
Two identical environments (blue = current, green = new). Traffic switches atomically from blue to green. Blue remains available for immediate rollback.

### Kubernetes Pattern
```yaml
# Service routes to active deployment via label selector
apiVersion: v1
kind: Service
metadata:
  name: orders-service
spec:
  selector:
    app: orders
    slot: blue  # Switch to "green" for cutover
  ports:
    - port: 80
      targetPort: 8080
```

```bash
# Deploy new version to green slot
kubectl apply -f deployment-green.yaml
kubectl rollout status deployment/orders-green

# Verify green health
kubectl run smoke-test --image=curlimages/curl --rm -it --restart=Never \
  -- curl http://orders-green-service/actuator/health

# Switch traffic: update service selector
kubectl patch service orders-service -p '{"spec":{"selector":{"slot":"green"}}}'

# After validation, decommission blue
kubectl delete deployment orders-blue
```

### Rollback Procedure
```bash
# Instant rollback: switch selector back to blue
kubectl patch service orders-service -p '{"spec":{"selector":{"slot":"blue"}}}'
```

### Pros/Cons
- **Pros:** Zero-downtime cutover; instant rollback; full isolation between versions
- **Cons:** Doubles infrastructure cost during deployment window; requires backward-compatible DB migrations

---

## Canary Deployment

### How It Works
Route a percentage of traffic to the new version. Gradually increase to 100% if error rates are acceptable. Roll back if metrics degrade.

### Traffic Split Pattern (Nginx Ingress)
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: orders-canary
  annotations:
    nginx.ingress.kubernetes.io/canary: "true"
    nginx.ingress.kubernetes.io/canary-weight: "10"  # 10% to canary
spec:
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /orders
            pathType: Prefix
            backend:
              service:
                name: orders-canary-service
                port:
                  number: 80
```

### Promotion Criteria
```
Canary at 10% for 30 minutes:
- Error rate < 0.1% → promote to 25%
- P99 latency increase < 10% → promote to 25%
- Error rate ≥ 0.1% OR P99 latency increase ≥ 10% → automatic rollback

Repeat at 25%, 50%, 100%
```

### Automatic Rollback
```bash
# Flagger (GitOps canary controller) example metric check
# If error_rate > 0.01 for 2 consecutive checks → rollback automatically
```

---

## Rolling Update — Kubernetes

### Deployment Config
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orders
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1          # +1 new pod beyond desired count during update
      maxUnavailable: 0    # Never reduce below desired count (zero-downtime)
  template:
    spec:
      containers:
        - name: orders
          image: orders:v2.0.0
          readinessProbe:
            httpGet:
              path: /actuator/health/readiness
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
            failureThreshold: 3
```

### `maxSurge`/`maxUnavailable` Guide
| Scenario | `maxSurge` | `maxUnavailable` |
|---|---|---|
| Zero-downtime (recommended) | 1 | 0 |
| Faster rollout, brief degradation OK | 1 | 1 |
| Resource-constrained, no extra pods | 0 | 1 |

---

## Kubernetes Health Probes

### Three Probe Types

| Probe | Purpose | Failure Action |
|---|---|---|
| `livenessProbe` | "Is the app alive?" — deadlock/hung check | Restart the container |
| `readinessProbe` | "Is the app ready to receive traffic?" | Remove from Service endpoints |
| `startupProbe` | "Has the app finished starting?" | Block liveness/readiness until started |

### Spring Boot Actuator Probe Mapping
```yaml
# application.yml
management:
  endpoint:
    health:
      probes:
        enabled: true
# Endpoints:
# /actuator/health/liveness  → livenessProbe
# /actuator/health/readiness → readinessProbe
```

### Kubernetes Probe Configuration
```yaml
startupProbe:
  httpGet:
    path: /actuator/health/liveness
    port: 8080
  failureThreshold: 30      # 30 × 10s = 5 minutes max startup window
  periodSeconds: 10

livenessProbe:
  httpGet:
    path: /actuator/health/liveness
    port: 8080
  initialDelaySeconds: 0    # startupProbe handles the delay
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /actuator/health/readiness
    port: 8080
  initialDelaySeconds: 0
  periodSeconds: 5
  failureThreshold: 3
```

### Pitfalls
- `livenessProbe` checking DB connectivity will restart the pod on DB outage — not the intended behavior. Liveness should only check internal app health (deadlocks, OOM states).
- Missing `startupProbe` on slow-starting apps causes `livenessProbe` to kill the pod before it finishes starting.

---

## Graceful Shutdown

### Configuration
```yaml
# application.yml
server:
  shutdown: graceful  # Wait for in-flight requests before shutdown

spring:
  lifecycle:
    timeout-per-shutdown-phase: 30s  # Max time to wait for requests to complete
```

### How It Works
1. Pod receives `SIGTERM`
2. Spring Boot marks `readinessProbe` as DOWN (pod removed from Service endpoints)
3. Load balancer stops routing new traffic to pod
4. Application processes remaining in-flight requests (up to `timeout-per-shutdown-phase`)
5. Application shuts down cleanly

### Kubernetes `terminationGracePeriodSeconds`
```yaml
spec:
  terminationGracePeriodSeconds: 60  # Must be > timeout-per-shutdown-phase + buffer
```

---

## Zero-Downtime Deployment Checklist

Before every deployment:
- [ ] DB migration is backward-compatible (old app version can run against new schema)
- [ ] New API changes are additive (no removed/renamed fields without versioning)
- [ ] `readinessProbe` configured and returns DOWN during startup
- [ ] `startupProbe` configured with sufficient `failureThreshold` for startup time
- [ ] `server.shutdown=graceful` enabled
- [ ] `terminationGracePeriodSeconds` ≥ `timeout-per-shutdown-phase` + 10s
- [ ] `maxUnavailable: 0` in rolling update strategy
- [ ] Feature flags enabled for risky behavioral changes

---

## Rollback Procedure

### Fast Rollback (Rolling)
```bash
# Undo last deployment
kubectl rollout undo deployment/orders

# Undo to specific revision
kubectl rollout history deployment/orders
kubectl rollout undo deployment/orders --to-revision=3

# Monitor rollback
kubectl rollout status deployment/orders
```

### Database Migration Rollback Constraints
- If the new version ran a BACKWARD-INCOMPATIBLE migration: rollback requires a fix-forward migration.
- If the migration was additive-only (new nullable column): rollback is safe.

### Rollback Decision
```
1. Is the issue in the application code? → kubectl rollout undo (safe)
2. Is the issue in a DB migration that was backward-compatible? → kubectl rollout undo (safe)
3. Is the issue in a DB migration that was NOT backward-compatible? → Fix forward, do NOT rollback app
```

---

## ConfigMaps & Secrets

### Spring Boot Config via ConfigMap
```yaml
# configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: orders-config
data:
  application.yml: |
    spring:
      datasource:
        url: jdbc:postgresql://postgres:5432/ordersdb
    app:
      feature-flags:
        new-pricing: false
```

```yaml
# deployment.yaml
spec:
  containers:
    - name: orders
      volumeMounts:
        - name: config
          mountPath: /config
          readOnly: true
  volumes:
    - name: config
      configMap:
        name: orders-config
```

```yaml
# application.yml
spring:
  config:
    import: optional:file:/config/application.yml
```

### Sealed Secrets Pattern (Bitnami Sealed Secrets)
```bash
# Encrypt secret for GitOps storage
echo -n "supersecret" | kubectl create secret generic db-password --dry-run=client --from-literal=password=- -o json | kubeseal --format yaml > sealed-db-password.yaml
```

---

## Resource Requests/Limits — JVM Sizing

### Container Memory Formula
```
container_limit = JVM_heap + metaspace + threads + JIT_code_cache + direct_buffers
container_limit ≈ heap_max / 0.75

Example: Want 512Mi heap
  container_limit = 512Mi / 0.75 = 682Mi → round up to 768Mi
```

### Kubernetes Resource Config
```yaml
resources:
  requests:
    memory: "512Mi"   # Minimum for scheduling
    cpu: "250m"       # 0.25 CPU cores
  limits:
    memory: "768Mi"   # JVM MaxRAMPercentage=75% × 768Mi ≈ 576Mi heap
    cpu: "1000m"      # 1 CPU core max
```

### CPU Throttling Risk
When a pod exceeds its `cpu.limits`, Kubernetes throttles it. JVM GC and JIT compilation are CPU-intensive bursts. Set `cpu.limits` at least 4× `cpu.requests` for JVM apps, or omit `cpu.limits` and rely on namespace LimitRange.

---

## Standalone Invocation (No Orchestrator)

This agent can be invoked directly without the orchestrator. When `.copilot-runtime/artifacts/context.json` is absent, three options are available:

**Option 1 — Run Diagnostic Commands Directly**
Execute targeted commands to gather context on the fly:
- `kubectl get deployments -o yaml | grep -A5 "strategy:\|probe:"` — check current deployment strategy and probes
- `find . -name "*.yaml" -o -name "*.yml" | xargs grep -l "Deployment\|RollingUpdate" 2>/dev/null | head -5`
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
