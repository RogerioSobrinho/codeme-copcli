---
name: docker-patterns
description: >
  Load when writing a Dockerfile for Spring Boot, building multi-stage Docker images (FROM
  eclipse-temurin as builder), tuning JVM heap for containers (-Xmx, -XX:MaxRAMPercentage,
  -XX:+UseContainerSupport), writing Docker Compose for local dev with depends_on and
  healthcheck, optimizing layer caching with Spring Boot layertools (jarmode layertools),
  or fixing container security issues (non-root USER, read-only filesystem, no-new-privileges).
---

# Docker Patterns

## Multi-Stage Dockerfile — Build + Runtime

```dockerfile
# ---- Stage 1: Build ----
FROM eclipse-temurin:21-jdk-alpine AS builder
WORKDIR /workspace

COPY pom.xml .
COPY .mvn/ .mvn/
COPY mvnw .
RUN ./mvnw dependency:go-offline -q

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

# Copy layers in order of change frequency (least to most frequent)
COPY --from=builder --chown=spring:spring /workspace/target/extracted/dependencies/ ./
COPY --from=builder --chown=spring:spring /workspace/target/extracted/spring-boot-loader/ ./
COPY --from=builder --chown=spring:spring /workspace/target/extracted/snapshot-dependencies/ ./
COPY --from=builder --chown=spring:spring /workspace/target/extracted/application/ ./

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget -qO- http://localhost:8080/actuator/health/readiness || exit 1

ENTRYPOINT ["java", \
    "-XX:+UseContainerSupport", \
    "-XX:MaxRAMPercentage=75.0", \
    "-XX:InitialRAMPercentage=50.0", \
    "-XX:+ExitOnOutOfMemoryError", \
    "-Djava.security.egd=file:/dev/./urandom", \
    "org.springframework.boot.loader.launch.JarLauncher"]
```

**Layer caching:** `pom.xml` + `mvnw` change rarely → dependency download is cached. Source code changes only invalidate the `application` layer (smallest). Rebuilds after code changes take seconds, not minutes.

---

## JVM Container Tuning

| Flag | Purpose |
|---|---|
| `-XX:+UseContainerSupport` | JVM reads container CPU/memory limits (always set explicitly) |
| `-XX:MaxRAMPercentage=75.0` | Heap = 75% of container limit (leaves room for metaspace, threads) |
| `-XX:InitialRAMPercentage=50.0` | Pre-allocate 50% at startup (reduces GC pressure) |
| `-XX:+ExitOnOutOfMemoryError` | Crash fast instead of limping on OOM (let Kubernetes restart) |
| `-Djava.security.egd=file:/dev/./urandom` | Fast random seed on Linux containers |

Memory sizing (512Mi container): MaxRAMPercentage=75% → Heap ≈ 384Mi. Remaining ≈ 128Mi for Metaspace (~100Mi), threads, JIT code cache.

GC selection:
| Container Size | GC | Reason |
|---|---|---|
| < 1Gi | G1GC (default JDK 17+) | Good latency/throughput balance |
| > 4Gi | ZGC (`-XX:+UseZGC`) | Ultra-low pause for large heaps |
| < 256Mi | SerialGC (`-XX:+UseSerialGC`) | Minimal overhead |

---

## Docker Compose — Local Development Stack

```yaml
services:
  app:
    build: .
    ports: ["8080:8080"]
    environment:
      SPRING_DATASOURCE_URL: jdbc:postgresql://postgres:5432/appdb
      SPRING_DATASOURCE_USERNAME: app
      SPRING_DATASOURCE_PASSWORD: secret
      SPRING_DATA_REDIS_HOST: redis
      SPRING_KAFKA_BOOTSTRAP_SERVERS: kafka:9092
    depends_on:
      postgres: { condition: service_healthy }
      redis: { condition: service_healthy }

  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: appdb
      POSTGRES_USER: app
      POSTGRES_PASSWORD: secret
    ports: ["5432:5432"]
    volumes: [postgres-data:/var/lib/postgresql/data]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U app -d appdb"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s

  kafka:
    image: confluentinc/cp-kafka:7.6.0
    ports: ["9092:9092"]
    environment:
      KAFKA_PROCESS_ROLES: broker,controller
      KAFKA_NODE_ID: 1
      KAFKA_LISTENERS: PLAINTEXT://0.0.0.0:9092,CONTROLLER://0.0.0.0:9093
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092
      KAFKA_CONTROLLER_QUORUM_VOTERS: 1@kafka:9093
      KAFKA_CONTROLLER_LISTENER_NAMES: CONTROLLER
      CLUSTER_ID: MkU3OEVBNTcwNTJENDM2Qg

volumes:
  postgres-data:
```

---

## Health Checks

Spring Boot Actuator config:
```yaml
management:
  endpoints:
    web:
      exposure:
        include: health, info, metrics
  endpoint:
    health:
      probes:
        enabled: true  # enables /actuator/health/liveness and /actuator/health/readiness
```

`start-period` must be ≥ application startup time (JVM warm-up + Flyway migrations). Container is not marked unhealthy during this period.

---

## Container Security

- Run as non-root user (`addgroup -S spring && adduser -S spring -G spring`)
- Use `eclipse-temurin:21-jre-alpine` for runtime (smaller attack surface than JDK)
- Do not store secrets in Docker image layers — use environment variables or secrets management
- Scan image with `trivy image <image>` before deploying

---

## .dockerignore

```
.git
target/
*.md
*.log
.mvn/wrapper/maven-wrapper.jar
!mvnw
```

Excludes source artifacts and git history from the build context, reducing transfer time.
