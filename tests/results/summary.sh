#!/usr/bin/env bash
#
# summary.sh — Display migration score trends from history.jsonl
#
# Usage: ./summary.sh [--model MODEL] [--project PROJECT]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HISTORY="$SCRIPT_DIR/history.jsonl"

if [ ! -f "$HISTORY" ]; then
    echo "No results yet. Run ./tests/harness.sh first."
    exit 0
fi

MODEL_FILTER=""
PROJECT_FILTER=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --model)   MODEL_FILTER="$2"; shift 2 ;;
        --project) PROJECT_FILTER="$2"; shift 2 ;;
        *)         shift ;;
    esac
done

python3 -c "
import json
from collections import defaultdict

model_filter = '$MODEL_FILTER' or None
project_filter = '$PROJECT_FILTER' or None

# Group results by (project, model)
groups = defaultdict(list)

with open('$HISTORY') as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            r = json.loads(line)
        except:
            continue

        if model_filter and r.get('model', '') != model_filter:
            continue
        if project_filter and r.get('project', '') != project_filter:
            continue

        key = (r.get('project', '?'), r.get('model', '?'))
        groups[key].append(r)

if not groups:
    print('No matching results found.')
    exit()

print()
print('=== Quarkus Migration Score Trends ===')
print()
print(f'{\"Project\":<25} {\"Model\":<30} {\"Scores\":<25} {\"Last Run\"}')
print('-' * 110)

for (project, model), runs in sorted(groups.items()):
    scores = ' → '.join(r['score'] for r in runs)
    last = runs[-1]
    tokens = last.get('usage', {}).get('total_tokens', 0)
    cost = last.get('usage', {}).get('total_cost', 0)
    api_calls = last.get('usage', {}).get('api_calls', 0)
    duration = last.get('duration_seconds', 0)
    date = last.get('date', '?')[:10]

    print(f'{project:<25} {model:<30} {scores:<25} {date}  tokens:{tokens:>7}  cost:\${cost:<7}  calls:{api_calls}  time:{duration}s')

    # Show check details for last run
    checks = last.get('checks', {})
    details = '    '
    for check, passed in checks.items():
        icon = '✅' if passed else '❌'
        details += f'{icon}{check}  '
    print(details)
    print()

# Summary stats
total_runs = sum(len(v) for v in groups.values())
print(f'Total runs: {total_runs}')
print(f'Projects tested: {len(set(k[0] for k in groups))}')
print(f'Models tested: {len(set(k[1] for k in groups))}')
"
