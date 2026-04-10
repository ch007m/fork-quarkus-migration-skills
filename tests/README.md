# Test Harness

The test harness runs migration skills against real Spring Boot / Jakarta EE projects and scores the results to track improvement over time.

## Prerequisites

- `pi` CLI installed and configured with at least one provider API key
- Java 21+ and Maven
- Python 3 (for result parsing)
- `git` (for cloning external test projects)

## Quick Start

```bash
# Run all in-repo test projects with default model
./tests/harness.sh

# Run a specific project
./tests/harness.sh --project spring-rest-api

# Run with a specific model
./tests/harness.sh --model anthropic/sonnet

# Run with compatibility strategy
./tests/harness.sh --strategy compatibility

# Compare models
./tests/harness.sh --model anthropic/sonnet --project spring-jpa-crud
./tests/harness.sh --model google/gemini-2.5-pro --project spring-jpa-crud
./tests/harness.sh --model openai/o3 --project spring-jpa-crud
```

## Test Projects

### In-Repo (self-contained, no external dependencies)

| Project | Description | Complexity |
|---------|-------------|-----------|
| `spring-rest-api` | Minimal REST API with validation, no DB | Trivial |
| `spring-jpa-crud` | JPA CRUD with H2, Spring Data, custom queries | Low |

### External (cloned at runtime)

| Project | Description | Complexity |
|---------|-------------|-----------|
| `spring-petclinic` | Classic PetClinic with Thymeleaf, JPA, caching | Medium |
| `spring-petclinic-rest` | REST-only PetClinic, no templates | Medium |

## Checks

Each project defines which checks to run in `project.yaml`:

| Check | What it verifies |
|-------|-----------------|
| `builds` | `./mvnw compile` succeeds |
| `tests-pass` | `./mvnw test` succeeds |
| `no-spring-deps` | No `org.springframework` in `pom.xml` |
| `has-quarkus` | `io.quarkus` present in `pom.xml` |
| `starts-up` | App starts and responds on HTTP |
| `no-thymeleaf` | No Thymeleaf references remain |

## Results

Results are appended to `tests/results/history.jsonl` — one JSON object per run:

```json
{
  "project": "spring-rest-api",
  "date": "2026-04-10T15:00:00Z",
  "model": "anthropic/claude-sonnet-4-20250514",
  "strategy": "full",
  "skill": "spring-boot-to-quarkus",
  "skill_version": "abc123",
  "duration_seconds": 180,
  "usage": {
    "total_tokens": 12500,
    "total_cost": 0.042,
    "api_calls": 8
  },
  "checks": {
    "builds": true,
    "tests-pass": true,
    "no-spring-deps": true,
    "has-quarkus": true,
    "starts-up": true
  },
  "score": "5/5"
}
```

View trends:

```bash
./tests/results/summary.sh

# Filter by model or project
./tests/results/summary.sh --model anthropic/sonnet
./tests/results/summary.sh --project spring-petclinic
```

## Adding a Test Project

### In-repo project

1. Create `tests/projects/<name>/source/` with the full project source
2. Create `tests/projects/<name>/project.yaml`:
   ```yaml
   name: my-project
   description: What this project tests
   type: spring-boot
   skill: spring-boot-to-quarkus
   source: local
   timeout: 300
   checks:
     - builds
     - tests-pass
     - no-spring-deps
     - has-quarkus
     - starts-up
   ```

### External project

1. Create `tests/projects/<name>/project.yaml`:
   ```yaml
   name: my-project
   description: What this project tests
   type: spring-boot
   skill: spring-boot-to-quarkus
   source: https://github.com/org/repo
   ref: main
   timeout: 600
   checks:
     - builds
     - tests-pass
     - no-spring-deps
     - has-quarkus
   ```

## Project Config Reference (`project.yaml`)

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Project identifier |
| `description` | No | What migration patterns this tests |
| `type` | Yes | `spring-boot` or `jakarta-ee` |
| `skill` | Yes | Skill directory name to use |
| `source` | Yes | `local` (uses `source/` subdir) or a git URL |
| `ref` | No | Git branch/tag for external repos |
| `timeout` | Yes | Max seconds for the migration agent |
| `checks` | Yes | List of checks to run |
