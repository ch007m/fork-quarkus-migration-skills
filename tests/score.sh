#!/usr/bin/env bash
#
# score.sh — Evaluate a migrated project against standard checks
#
# Usage: ./score.sh <project-dir> [checks...]
# Checks: builds, tests-pass, no-spring-deps, has-quarkus, starts-up, no-thymeleaf
#
# Outputs JSON object with check results to stdout.

set -euo pipefail

PROJECT_DIR="$1"
shift
CHECKS=("$@")

cd "$PROJECT_DIR"

declare -A RESULTS

run_check() {
    local check="$1"
    case "$check" in
        builds)
            if ./mvnw -q compile -DskipTests 2>/dev/null; then
                RESULTS[$check]="true"
            else
                RESULTS[$check]="false"
            fi
            ;;

        tests-pass)
            if ./mvnw -q test 2>/dev/null; then
                RESULTS[$check]="true"
            else
                RESULTS[$check]="false"
            fi
            ;;

        no-spring-deps)
            if grep -q "org.springframework" pom.xml 2>/dev/null; then
                RESULTS[$check]="false"
            else
                RESULTS[$check]="true"
            fi
            ;;

        has-quarkus)
            if grep -q "io.quarkus" pom.xml 2>/dev/null; then
                RESULTS[$check]="true"
            else
                RESULTS[$check]="false"
            fi
            ;;

        starts-up)
            # Start the app, wait for health or root endpoint, then kill
            ./mvnw -q quarkus:dev -Dquarkus.http.port=18080 -Dquarkus.devservices.enabled=false &>/dev/null &
            local PID=$!
            local started=false

            for i in $(seq 1 30); do
                sleep 2
                if curl -sf http://localhost:18080/q/health/ready >/dev/null 2>&1 || \
                   curl -sf http://localhost:18080/ >/dev/null 2>&1; then
                    started=true
                    break
                fi
                # Check if process is still alive
                if ! kill -0 "$PID" 2>/dev/null; then
                    break
                fi
            done

            # Kill the dev process and its children
            kill "$PID" 2>/dev/null || true
            wait "$PID" 2>/dev/null || true

            if $started; then
                RESULTS[$check]="true"
            else
                RESULTS[$check]="false"
            fi
            ;;

        no-thymeleaf)
            if grep -rq "thymeleaf\|th:" pom.xml src/ 2>/dev/null; then
                RESULTS[$check]="false"
            else
                RESULTS[$check]="true"
            fi
            ;;

        *)
            echo "Unknown check: $check" >&2
            RESULTS[$check]="false"
            ;;
    esac
}

# Run all checks
for check in "${CHECKS[@]}"; do
    echo "  Running check: $check ..." >&2
    run_check "$check"
done

# Count passed
passed=0
total=${#CHECKS[@]}
for check in "${CHECKS[@]}"; do
    if [ "${RESULTS[$check]}" = "true" ]; then
        ((passed++)) || true
    fi
done

# Output JSON
echo "{"
echo "  \"checks\": {"
first=true
for check in "${CHECKS[@]}"; do
    if $first; then first=false; else echo ","; fi
    printf "    \"%s\": %s" "$check" "${RESULTS[$check]}"
done
echo ""
echo "  },"
echo "  \"passed\": $passed,"
echo "  \"total\": $total,"
echo "  \"score\": \"$passed/$total\""
echo "}"
