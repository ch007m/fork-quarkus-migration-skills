# Quarkus Migration Skills

AI agent skills for migrating Java applications to [Quarkus](https://quarkus.io/), with a test harness to measure and track migration quality over time.

## Skills

| Skill | Description |
|-------|-------------|
| [spring-boot-to-quarkus](skills/spring-boot-to-quarkus/) | Migrate Spring Boot applications to Quarkus |
| [jakarta-ee-to-quarkus](skills/jakarta-ee-to-quarkus/) | Migrate Jakarta EE applications to Quarkus |

Each skill supports two migration strategies:
- **Full migration** — rewrite to idiomatic Quarkus (JAX-RS, CDI, Panache, Qute, etc.)
- **Compatibility migration** — use Quarkus Spring compatibility extensions (`quarkus-spring-web`, `quarkus-spring-data-jpa`, etc.) for faster migration with less rewriting

## Using a Skill

```bash
# Install locally
cd your-spring-project
pi --skill /path/to/skills/spring-boot-to-quarkus "Migrate this project to Quarkus"

# Or copy the skill directory to ~/.pi/agent/skills/ for global access
```

## Test Harness

The test harness runs migrations against real projects and scores the results to track whether skills are improving or regressing.

See [tests/README.md](tests/README.md) for full details.

```bash
# Run all test projects with default model
./tests/harness.sh

# Run a specific project
./tests/harness.sh --project spring-rest-api

# Run with a specific model
./tests/harness.sh --model anthropic/sonnet

# Compare across models
./tests/harness.sh --model anthropic/sonnet
./tests/harness.sh --model google/gemini-2.5-pro
./tests/harness.sh --model openai/o3
```

## Results

Results are stored in `tests/results/` as JSONL and can be viewed with:

```bash
./tests/results/summary.sh
```

Example output:
```
=== Migration Score Trends ===
spring-rest-api      anthropic/sonnet   5/5 → 5/5 → 5/5   (tokens: 12k, cost: $0.04)
spring-jpa-crud      anthropic/sonnet   3/5 → 4/5 → 5/5   (tokens: 18k, cost: $0.06)
spring-petclinic     anthropic/sonnet   2/7 → 3/7 → 4/7   (tokens: 45k, cost: $0.15)
```

## Repository Structure

```
skills/
├── spring-boot-to-quarkus/    # Spring Boot → Quarkus migration skill
├── jakarta-ee-to-quarkus/     # Jakarta EE → Quarkus migration skill
└── shared/references/         # Common mapping tables (deps, annotations, config)

tests/
├── harness.sh                 # Main test runner
├── score.sh                   # Evaluates migration results
├── projects/                  # Test project definitions
│   ├── spring-rest-api/       # Minimal REST API (in-repo)
│   ├── spring-jpa-crud/       # JPA CRUD app (in-repo)
│   ├── spring-petclinic/      # Classic petclinic (cloned)
│   └── spring-petclinic-rest/ # REST-only petclinic (cloned)
├── results/                   # Score history (JSONL)
└── README.md
```

## Contributing

1. Improve a skill's SKILL.md with better instructions
2. Run the test harness to verify scores don't regress
3. Add new test projects to cover more migration patterns
