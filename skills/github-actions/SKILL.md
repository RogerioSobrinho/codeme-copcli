---
name: github-actions
description: >
  Load when writing GitHub Actions workflows (.yml files in .github/workflows/), configuring
  CI/CD pipelines, setting up build/test/deploy jobs, using matrix builds, caching dependencies,
  managing secrets and environment variables in Actions, writing reusable workflows, configuring
  branch protection rules, or when asked "how do I set up CI for this project",
  "how do I cache Maven/npm/pip in Actions", "how do I deploy from a workflow",
  "how do I run tests on pull requests".
---

# GitHub Actions Patterns

## File Location

All workflows live in `.github/workflows/*.yml`. Common filenames:
- `ci.yml` — build + test on every push/PR
- `cd.yml` — deploy on merge to main
- `release.yml` — tag-triggered release
- `security.yml` — scheduled security scans

## Workflow Anatomy

```yaml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up JDK 21
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '21'
      - name: Build
        run: mvn -B package --no-transfer-progress
```

## Java / Spring Boot CI

```yaml
name: CI — Spring Boot

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_DB: testdb
          POSTGRES_PASSWORD: test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports: ['5432:5432']

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '21'
          cache: maven       # auto-cache ~/.m2

      - name: Test
        run: mvn -B verify --no-transfer-progress
        env:
          SPRING_DATASOURCE_URL: jdbc:postgresql://localhost:5432/testdb
          SPRING_DATASOURCE_PASSWORD: test

      - name: Upload coverage report
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: jacoco-report
          path: target/site/jacoco/
```

## Node.js / TypeScript CI

```yaml
name: CI — Node

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node-version: ['20', '22']

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: npm          # auto-cache node_modules

      - run: npm ci
      - run: npm run lint
      - run: npm test -- --coverage
```

## Python CI

```yaml
name: CI — Python

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: ['3.11', '3.12']

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}
          cache: pip

      - run: pip install -r requirements.txt
      - run: pip install -r requirements-dev.txt
      - run: pytest --cov=src --cov-report=xml
```

## Dependency Caching (Manual)

```yaml
- name: Cache Maven packages
  uses: actions/cache@v4
  with:
    path: ~/.m2
    key: ${{ runner.os }}-m2-${{ hashFiles('**/pom.xml') }}
    restore-keys: ${{ runner.os }}-m2-
```

**Tip:** `actions/setup-java@v4`, `actions/setup-node@v4`, and `actions/setup-python@v5` have built-in `cache:` options. Use those instead of manual cache steps.

## Secrets and Environment Variables

```yaml
- name: Deploy
  env:
    DATABASE_URL: ${{ secrets.DATABASE_URL }}
    API_KEY: ${{ secrets.API_KEY }}
  run: ./deploy.sh
```

- Store secrets in repo Settings → Secrets and variables → Actions
- Never hardcode secrets in workflow files
- Use `${{ vars.VARIABLE_NAME }}` for non-sensitive config values
- Use environments (`production`, `staging`) to gate secrets per deployment target

## Docker Build and Push

```yaml
- name: Build and push Docker image
  uses: docker/build-push-action@v5
  with:
    context: .
    push: ${{ github.ref == 'refs/heads/main' }}
    tags: |
      ghcr.io/${{ github.repository }}:latest
      ghcr.io/${{ github.repository }}:${{ github.sha }}
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

## Reusable Workflows

```yaml
# .github/workflows/reusable-test.yml
on:
  workflow_call:
    inputs:
      java-version:
        required: false
        type: string
        default: '21'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: ${{ inputs.java-version }}
          distribution: temurin
          cache: maven
      - run: mvn -B verify
```

```yaml
# Caller workflow
jobs:
  test:
    uses: ./.github/workflows/reusable-test.yml
    with:
      java-version: '21'
```

## Concurrency Control

```yaml
# Cancel in-progress runs when a new push arrives on the same branch
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

## Best Practices

- Pin action versions with SHA (`uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683`) in production — avoids supply chain attacks
- Use `if: always()` on report/notification steps so they run even after failures
- Separate CI (fast, on every PR) from CD (deploy, on main merge) workflows
- Add `timeout-minutes` to jobs to prevent runaway workflows
- Use `workflow_dispatch` for manual triggers on release workflows
