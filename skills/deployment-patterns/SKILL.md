---
name: deployment-patterns
description: >
  Load when writing Kubernetes Deployment/Service/Ingress manifests, configuring liveness,
  readiness, and startup probes for Spring Boot Actuator (/actuator/health/liveness,
  /actuator/health/readiness), planning blue-green or canary deployments, setting HPA
  minReplicas/maxReplicas, mapping ConfigMap/Secret to spring.config.import or env vars,
  implementing graceful shutdown (server.shutdown=graceful, spring.lifecycle.timeout-per-
  shutdown-phase), or calculating resource requests/limits for JVM workloads.
---

# Deployment Patterns

## Blue-Green Deployment

Two identical environments (blue = current, green = new). Traffic switches atomically; blue stays for instant rollback.

```yaml
# Service routes via label selector
apiVersion: v1
kind: Service
metadata:
  name: orders-service
spec:
  selector:
    app: orders
    slot: blue  # switch to "green" for cutover
  ports:
    - port: 80
      targetPort: 8080
```

```bash
# Deploy new version to green
kubectl apply -f deployment-green.yaml
kubectl rollout status deployment/orders-green

# Switch traffic
kubectl patch service orders-service -p '{"spec":{"selector":{"slot":"green"}}}'

# Instant rollback
kubectl patch service orders-service -p '{"spec":{"selector":{"slot":"blue"}}}'
```

**Trade-offs:** Zero-downtime cutover, instant rollback, but doubles infrastructure cost during deployment window.

---

## Canary Deployment

Route a percentage of traffic to the new version. Increase gradually if metrics are acceptable.

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
            backend:
              service:
                name: orders-canary-service
                port: { number: 80 }
```

Promotion criteria: error rate < 0.1% AND P99 latency increase < 10% → promote from 10% → 25% → 50% → 100%.

---

## Rolling Update — Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  replicas: 4
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1          # +1 new pod beyond desired count
      maxUnavailable: 0    # never reduce below desired count (zero-downtime)
```

| Scenario | `maxSurge` | `maxUnavailable` |
|---|---|---|
| Zero-downtime (recommended) | 1 | 0 |
| Faster rollout, brief degradation OK | 1 | 1 |
| Resource-constrained, no extra pods | 0 | 1 |

---

## Kubernetes Health Probes

| Probe | Purpose | Failure Action |
|---|---|---|
| `startupProbe` | Has the app finished starting? | Block liveness/readiness until started |
| `livenessProbe` | Is the app alive (deadlock check)? | Restart the container |
| `readinessProbe` | Is the app ready to receive traffic? | Remove from Service endpoints |

```yaml
startupProbe:
  httpGet:
    path: /actuator/health/liveness
    port: 8080
  failureThreshold: 30      # 30 × 10s = 5 minutes max startup
  periodSeconds: 10

livenessProbe:
  httpGet:
    path: /actuator/health/liveness
    port: 8080
  periodSeconds: 10
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /actuator/health/readiness
    port: 8080
  periodSeconds: 5
  failureThreshold: 3
```

Spring Boot Actuator config:
```yaml
management:
  endpoint:
    health:
      probes:
        enabled: true
```

**Pitfall:** Liveness probe that checks DB connectivity restarts the pod on DB outage. Liveness should only check internal app health (deadlocks, OOM).

---

## Graceful Shutdown

```yaml
server:
  shutdown: graceful          # waits for active requests to complete
spring:
  lifecycle:
    timeout-per-shutdown-phase: 30s  # max time to drain

# application.properties equivalent
# server.shutdown=graceful
```

Kubernetes terminationGracePeriodSeconds must be > Spring's shutdown timeout:
```yaml
spec:
  terminationGracePeriodSeconds: 60  # > spring.lifecycle.timeout-per-shutdown-phase
```

---

## Resource Requests and Limits

```yaml
resources:
  requests:
    memory: "256Mi"   # guaranteed memory (used for scheduling)
    cpu: "250m"       # 0.25 vCPU guaranteed
  limits:
    memory: "512Mi"   # OOM kill threshold — set to 2× request
    cpu: "1000m"      # 1 vCPU max — throttled, not killed
```

Memory limit must align with JVM `-XX:MaxRAMPercentage`. With 512Mi limit and MaxRAMPercentage=75%, heap max ≈ 384Mi.

---

## ConfigMap and Secret Injection

```yaml
# ConfigMap for non-sensitive config
envFrom:
  - configMapRef:
      name: app-config

# Secret for sensitive values
env:
  - name: SPRING_DATASOURCE_PASSWORD
    valueFrom:
      secretKeyRef:
        name: app-secrets
        key: db-password
```

**Never hardcode** connection strings, passwords, or API keys in Deployment YAML or Docker images.

---

## Zero-Downtime Deployment Checklist

- [ ] Flyway migration is additive (no DROP, no NOT NULL without default)
- [ ] New version can run against old schema (during rolling update)
- [ ] Old version can run against new schema (for rollback)
- [ ] API changes are backward-compatible (no removed fields, no new required fields)
- [ ] `maxUnavailable: 0` in rolling update strategy
- [ ] `startupProbe` configured to cover full startup time
- [ ] Graceful shutdown enabled with adequate timeout
- [ ] Rollback procedure documented and tested
