---
name: docker-patterns
description: Docker patterns for Java/Spring Boot applications. Multi-stage builds, Docker Compose for local development, container security, health checks, and JVM tuning in containers.
tools: ["Read", "Bash", "Grep", "Glob"]
model: claude-sonnet-4-5
activation: ["docker", "dockerfile", "docker compose", "container", "containerize", "jvm container"]
---

# Docker Patterns

## Purpose

Docker best practices for Java/Spring Boot applications. Covers multi-stage Dockerfiles with layer caching, JVM container-aware tuning, Docker Compose local development stacks, container security hardening, health checks, image optimization with Spring Boot layertools, and networking patterns. Use this skill when containerizing a new service or reviewing an existing Dockerfile.

---

## Multi-Stage Dockerfile — Build + Runtime

### Pattern
```dockerfile
# ---- Stage 1: Build ----
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /workspace

# Copy dependency manifests first — cached unless pom.xml changes
COPY pom.xml .
COPY .mvn/ .mvn/
COPY mvnw .

# Download dependencies (cached layer)
RUN ./mvnw dependency:go-offline -q

# Copy source and build
COPY src/ src/
RUN ./mvnw package -DskipTests -q

# Extract layers for optimal caching
RUN java -Djarmode=layertools -jar target/*.jar extract --destination target/extracted

# ---- Stage 2: Runtime ----
FROM eclipse-temurin:21-jre-alpine AS runtime
WORKDIR /app

# Non-root user for security
RUN addgroup -S spring && adduser -S spring -G spring
USER spring

# Copy layers in order of change frequency (least to most)
COPY --from=builder --chown=spring:spring /workspace/target/extracted/dependencies/ ./
COPY --from=builder --chown=spring:spring /workspace/target/extracted/spring-boot-loader/ ./
COPY --from=builder --chown=spring:spring /workspace/target/extracted/snapshot-dependencies/ ./
COPY --from=builder --chown=spring:spring /workspace/target/extracted/application/ ./

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget -qO- http://localhost:8080/actuator/health || exit 1

ENTRYPOINT ["java", \
    "-XX:+UseContainerSupport", \
    "-XX:MaxRAMPercentage=75.0", \
    "-XX:InitialRAMPercentage=50.0", \
    "-Djava.security.egd=file:/dev/./urandom", \
    "org.springframework.boot.loader.launch.JarLauncher"]
```

### Layer Caching Strategy
- `pom.xml` + `mvnw` change rarely → dependency download is cached
- Source code changes invalidate only the `application` layer (the smallest)
- Result: rebuilds after code changes take seconds, not minutes

---

## JVM Container Tuning

### Critical Flags
| Flag | Purpose |
|---|---|
| `-XX:+UseContainerSupport` | JVM reads container CPU/memory limits (default ON in JDK 8u191+, always set explicitly) |
| `-XX:MaxRAMPercentage=75.0` | Heap = 75% of container memory limit (leaves room for metaspace, threads, off-heap) |
| `-XX:InitialRAMPercentage=50.0` | Pre-allocate 50% of container memory at startup (reduces GC pressure) |
| `-XX:+ExitOnOutOfMemoryError` | Crash fast instead of limping on OOM (let Kubernetes restart the pod) |
| `-Djava.security.egd=file:/dev/./urandom` | Fast random seed on Linux containers (avoids `/dev/random` blocking) |

### Memory Sizing Example
Container limit: 512Mi
- MaxRAMPercentage=75% → Heap max = ~384Mi
- Remaining ~128Mi for: Metaspace (~100Mi), threads (~10Mi), JIT code cache (~20Mi)

### GC Selection
| Container Size | GC | Reason |
|---|---|---|
| < 1Gi | G1GC (default JDK 17+) | Low latency, good throughput balance |
| > 4Gi | ZGC (`-XX:+UseZGC`) | Ultra-low pause time for large heaps |
| Tiny containers (< 256Mi) | SerialGC (`-XX:+UseSerialGC`) | Minimal overhead |

---

## Docker Compose — Local Development Stack

```yaml
# docker-compose.yml
services:
  app:
    build: .
    ports:
      - "8080:8080"
    environment:
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/appdb
      SPRING_DATASOURCE_USERNAME: app
      SPRING_DATASOURCE_PASSWORD: secret
      SPRING_DATA_REDIS_HOST: redis
      SPRING_KAFKA_BOOTSTRAP_SERVERS: kafka:9092
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - app-network

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: appdb
      POSTGRES_USER: app
      POSTGRES_PASSWORD: secret
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app -d appdb"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - app-network

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - app-network

  kafka:
    image: confluentinc/cp-kafka:7.6.0
    ports:
      - "9092:9092"
    environment:
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_NODE_ID: 1
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka:9093
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      CLUSTER_ID: MkU3OEVBNTcwNTJENDM2Qg
    networks:
      - app-network

volumes:
  postgres-data:

networks:
  app-network:
    driver: bridge
```

---

## Health Checks — Dockerfile + Actuator

### Actuator Configuration
```yaml
management:
  endpoints:
    web:
      exposure:
        include: health, info, metrics
  endpoint:
    health:
      show-details: when_authorized
      probes:
        enabled: true  # Enables /actuator/health/liveness and /actuator/health/readiness
```

### Dockerfile HEALTHCHECK
```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget -qO- http://localhost:8080/actuator/health/readiness || exit 1
```

### `start-period`
Set `start-period` to at least the application startup time (JVM warm-up + Flyway migrations). A container is not marked unhealthy during this period.

---

## Secrets — Never Bake into Image

### Environment Variable Pattern (Development)
```yaml
# docker-compose.yml
environment:
  DB_PASSWORD: ${DB_PASSWORD}  # from .env file or host environment
```

### Docker Secrets (Production Swarm)
```yaml
services:
  app:
    secrets:
      - db_password
    environment:
      DB_PASSWORD_FILE: /run/secrets/db_password

secrets:
  db_password:
    external: true
```

### Spring Boot — Reading from File
```yaml
spring:
  datasource:
    password: ${DB_PASSWORD:${DB_PASSWORD_FILE:}}
```

### Pitfalls
- Never use `ENV DB_PASSWORD=secret` in Dockerfile — visible in `docker inspect` and image history.
- Never commit `.env` files to version control. Add to `.gitignore`.

---

## Container Security Hardening

### Non-Root User
```dockerfile
RUN addgroup -S spring && adduser -S spring -G spring
USER spring
```

### Read-Only Filesystem
```dockerfile
# docker-compose.yml
read_only: true
tmpfs:
  - /tmp  # Spring Boot temp directory
```

### Drop All Capabilities
```yaml
# docker-compose.yml
cap_drop:
  - ALL
cap_add:
  - NET_BIND_SERVICE  # Only if binding to port < 1024
```

### Image Scanning
```bash
# Scan for CVEs before pushing
docker scout cves myapp:latest
# or
trivy image myapp:latest
```

---

## Layer Optimization — Spring Boot Layertools

### Build with Layertools (Maven)
```xml
<plugin>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-maven-plugin</artifactId>
    <configuration>
        <layers>
            <enabled>true</enabled>
        </layers>
    </configuration>
</plugin>
```

### Paketo Buildpacks Alternative
```bash
# Zero-Dockerfile image build
./mvnw spring-boot:build-image -Dspring-boot.build-image.imageName=myapp:latest
```
Paketo buildpacks auto-configure JVM flags, non-root user, and layer caching.

### Layer Order (least to most frequently changed)
1. `dependencies` — library JARs
2. `spring-boot-loader` — Spring Boot loader classes
3. `snapshot-dependencies` — SNAPSHOT JARs (if any)
4. `application` — your compiled classes (changes every commit)

---

## Networking — Bridge, Host, Service Discovery

### Container Name Resolution in Compose
Containers in the same `networks:` block can reach each other by service name:
- `jdbc:postgresql://postgres:5432/appdb` — `postgres` resolves to the `postgres` service
- `redis://redis:6379` — `redis` resolves to the `redis` service

### Bridge (Default)
Isolated network per Compose project. Containers on the same network communicate freely. Prefer bridge for local development.

### Host Network
Container shares the host network stack. Avoid unless network performance profiling requires it. Increases attack surface.

---

## Volumes — Data Persistence

| Pattern | Use When |
|---|---|
| Named volume (`postgres-data:/var/lib/postgresql/data`) | Production DB data — survives container restarts |
| Bind mount (`./src:/app/src`) | Dev mode hot-reload — bind local source into container |
| `tmpfs` (`/tmp`) | Ephemeral scratch space — fast, no persistence |

### Pitfalls
- Bind mounts in production are an anti-pattern — they couple the container to the host filesystem.
- Named volumes are NOT automatically backed up. Configure backup for data volumes in production.

---

## Standalone Invocation (No Orchestrator)

This agent can be invoked directly without the orchestrator. When `.copilot-runtime/artifacts/context.json` is absent, three options are available:

**Option 1 — Run Diagnostic Commands Directly**
Execute targeted commands to gather context on the fly:
- `find . -name "Dockerfile" -o -name "docker-compose*.yml" | head -10`
- `docker inspect <container> 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin)[0]; print(d['HostConfig']['Memory'], d['Config']['User'])"`
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
