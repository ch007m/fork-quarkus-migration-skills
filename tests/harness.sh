#!/usr/bin/env bash
#
# harness.sh — Run migration skills against test projects and score the results
#
# Usage:
#   ./harness.sh                                    # Run all projects with defaults
#   ./harness.sh --project spring-rest-api           # Run specific project
#   ./harness.sh --model anthropic/sonnet            # Use specific model
#   ./harness.sh --strategy full                     # full or compatibility
#   ./harness.sh --model google/gemini-2.5-pro --project spring-jpa-crud
#
# Environment:
#   HARNESS_TIMEOUT  — Override per-project timeout (seconds)
#   PI_CMD           — Path to pi binary (default: pi)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECTS_DIR="$SCRIPT_DIR/projects"
RESULTS_DIR="$SCRIPT_DIR/results"
SKILLS_DIR="$REPO_ROOT/skills"

# Defaults
MODEL=""
PROJECT_FILTER=""
STRATEGY="full"
PI_CMD="${PI_CMD:-pi}"
SESSION_BASE_DIR=$(mktemp -d)

usage() {
    echo "Usage: $0 [--project NAME] [--model PROVIDER/MODEL] [--strategy full|compatibility]"
    echo ""
    echo "Options:"
    echo "  --project NAME     Run only this project (directory name under tests/projects/)"
    echo "  --model MODEL      Model to use (e.g., anthropic/sonnet, google/gemini-2.5-pro)"
    echo "  --strategy TYPE    Migration strategy: full (default) or compatibility"
    echo "  --help             Show this help"
    exit 0
}

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --project)  PROJECT_FILTER="$2"; shift 2 ;;
        --model)    MODEL="$2"; shift 2 ;;
        --strategy) STRATEGY="$2"; shift 2 ;;
        --help)     usage ;;
        *)          echo "Unknown arg: $1" >&2; exit 1 ;;
    esac
done

mkdir -p "$RESULTS_DIR"

# Read a YAML value (simple single-line values only)
yaml_val() {
    grep "^${2}:" "$1" | head -1 | sed "s/^${2}:[[:space:]]*//"
}

# Read YAML list values
yaml_list() {
    sed -n "/^${2}:/,/^[^ ]/p" "$1" | grep "^  - " | sed 's/^  - //'
}

# Extract token usage from a pi session JSONL file
extract_usage() {
    local session_file="$1"
    # Sum up usage from all assistant messages
    python3 -c "
import json, sys

total_tokens = 0
total_cost = 0.0
api_calls = 0

for line in open('$session_file'):
    try:
        entry = json.loads(line)
        if entry.get('type') == 'message' and entry.get('message', {}).get('role') == 'assistant':
            usage = entry['message'].get('usage', {})
            total_tokens += usage.get('totalTokens', 0)
            cost = usage.get('cost', {})
            total_cost += cost.get('total', 0.0)
            api_calls += 1
    except:
        pass

print(json.dumps({
    'total_tokens': total_tokens,
    'total_cost': round(total_cost, 4),
    'api_calls': api_calls
}))
" 2>/dev/null || echo '{"total_tokens": 0, "total_cost": 0, "api_calls": 0}'
}

run_project() {
    local project_dir="$1"
    local project_name=$(basename "$project_dir")
    local config="$project_dir/project.yaml"

    if [ ! -f "$config" ]; then
        echo "SKIP: $project_name (no project.yaml)" >&2
        return
    fi

    local name=$(yaml_val "$config" "name")
    local source=$(yaml_val "$config" "source")
    local ref=$(yaml_val "$config" "ref")
    local skill_name=$(yaml_val "$config" "skill")
    local timeout=$(yaml_val "$config" "timeout")
    local checks=($(yaml_list "$config" "checks"))

    timeout="${HARNESS_TIMEOUT:-$timeout}"

    echo "============================================" >&2
    echo "PROJECT: $name" >&2
    echo "  skill:    $skill_name" >&2
    echo "  strategy: $STRATEGY" >&2
    echo "  model:    ${MODEL:-default}" >&2
    echo "  timeout:  ${timeout}s" >&2
    echo "  checks:   ${checks[*]}" >&2
    echo "============================================" >&2

    # Create working directory
    local work_dir=$(mktemp -d)
    echo "  workdir:  $work_dir" >&2

    # Prepare source
    if [ "$source" = "local" ]; then
        cp -r "$project_dir/source/." "$work_dir/"
    else
        echo "  Cloning $source ..." >&2
        git clone --depth 1 ${ref:+--branch "$ref"} "$source" "$work_dir" 2>/dev/null
    fi

    # Resolve skill path
    local skill_path="$SKILLS_DIR/$skill_name"
    if [ ! -d "$skill_path" ]; then
        echo "  ERROR: skill directory not found: $skill_path" >&2
        return
    fi

    # Build the migration prompt
    local prompt="Migrate this Spring Boot project to Quarkus using the $STRATEGY migration strategy. "
    prompt+="Work entirely within this directory. "
    prompt+="Do a full migration — convert all source files, build files, config, and tests. "
    prompt+="After migration, verify the project compiles with ./mvnw compile and fix any errors. "
    prompt+="Then run ./mvnw test and fix any test failures."

    # Build pi command
    local pi_args=(
        --print
        --no-skills
        --no-extensions
        --no-prompt-templates
        --skill "$skill_path"
        --session-dir "$SESSION_BASE_DIR"
    )

    if [ -n "$MODEL" ]; then
        pi_args+=(--model "$MODEL")
    fi

    # Run pi
    local start_time=$(date +%s)
    echo "  Running migration agent ..." >&2

    local log_file="$work_dir/.migration.log"
    (
        cd "$work_dir"
        timeout "${timeout}" "$PI_CMD" "${pi_args[@]}" "$prompt" > "$log_file" 2>&1
    ) || true

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    echo "  Migration completed in ${duration}s" >&2

    # Find the session file for usage extraction
    local session_file=""
    if [ -d "$SESSION_BASE_DIR" ]; then
        session_file=$(find "$SESSION_BASE_DIR" -name "*.jsonl" -type f | sort | tail -1)
    fi

    # Extract usage stats
    local usage='{"total_tokens": 0, "total_cost": 0, "api_calls": 0}'
    if [ -n "$session_file" ] && [ -f "$session_file" ]; then
        usage=$(extract_usage "$session_file")
    fi

    # Score the result
    echo "  Scoring ..." >&2
    local score_json
    score_json=$("$SCRIPT_DIR/score.sh" "$work_dir" "${checks[@]}" 2>&2)

    # Determine actual model used from session
    local actual_model="${MODEL:-unknown}"
    if [ -n "$session_file" ] && [ -f "$session_file" ]; then
        actual_model=$(python3 -c "
import json
for line in open('$session_file'):
    try:
        e = json.loads(line)
        if e.get('type') == 'message' and e.get('message',{}).get('role') == 'assistant':
            print(e['message'].get('provider','?') + '/' + e['message'].get('model','?'))
            break
    except: pass
" 2>/dev/null || echo "$actual_model")
    fi

    # Build result JSON
    local result_file="$RESULTS_DIR/history.jsonl"
    local date_str=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local skill_version=$(cd "$REPO_ROOT" && git rev-parse --short HEAD 2>/dev/null || echo "unknown")

    local result=$(python3 -c "
import json

score = json.loads('''$score_json''')
usage = json.loads('''$usage''')

result = {
    'project': '$name',
    'date': '$date_str',
    'model': '$actual_model',
    'strategy': '$STRATEGY',
    'skill': '$skill_name',
    'skill_version': '$skill_version',
    'duration_seconds': $duration,
    'usage': usage,
    'checks': score['checks'],
    'score': score['score']
}

print(json.dumps(result))
")

    echo "$result" >> "$result_file"

    # Print summary
    echo "" >&2
    echo "  RESULT: $(echo "$score_json" | python3 -c "import json,sys; s=json.load(sys.stdin); print(s['score'])")" >&2
    local tokens=$(echo "$usage" | python3 -c "import json,sys; u=json.load(sys.stdin); print(u['total_tokens'])")
    local cost=$(echo "$usage" | python3 -c "import json,sys; u=json.load(sys.stdin); print(u['total_cost'])")
    local api_calls=$(echo "$usage" | python3 -c "import json,sys; u=json.load(sys.stdin); print(u['api_calls'])")
    echo "  TOKENS: $tokens  COST: \$$cost  API_CALLS: $api_calls  TIME: ${duration}s" >&2
    echo "  Details:" >&2
    echo "$score_json" | python3 -c "
import json, sys
s = json.load(sys.stdin)
for k, v in s['checks'].items():
    icon = '✅' if v else '❌'
    print(f'    {icon} {k}')
" >&2
    echo "" >&2

    # Clean up work dir (keep session for debugging)
    # rm -rf "$work_dir"
    echo "  Work dir preserved at: $work_dir" >&2
}

# Main
echo "Quarkus Migration Skills — Test Harness" >&2
echo "=======================================" >&2
echo "" >&2

if [ -n "$PROJECT_FILTER" ]; then
    project_path="$PROJECTS_DIR/$PROJECT_FILTER"
    if [ ! -d "$project_path" ]; then
        echo "ERROR: Project not found: $PROJECT_FILTER" >&2
        echo "Available projects:" >&2
        ls "$PROJECTS_DIR" >&2
        exit 1
    fi
    run_project "$project_path"
else
    for project_path in "$PROJECTS_DIR"/*/; do
        run_project "$project_path"
    done
fi

echo "" >&2
echo "Results appended to: $RESULTS_DIR/history.jsonl" >&2
echo "Run ./tests/results/summary.sh to see trends." >&2
