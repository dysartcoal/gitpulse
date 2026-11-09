#!/usr/bin/env bash
# Show every processor's state/validation/task count and every connection's
# queued FlowFile count for a process group - the single most-used check
# during the Phase 1 debugging session (confirming whether processors are
# actually running, valid, and whether a specific queue is stuck).
#
# Usage: ./flow-status.sh [process-group-id] [--ids]
#   process-group-id: optional positional argument, falls back to
#   $NIFI_PG_ID, falls back to the GitHub Events Flow group used throughout
#   Phase 1. Find a different group's id with process-groups-list.sh.
#   --ids: also print each processor's and connection's own id - hidden by
#   default to keep the common "just eyeball status" case readable, but
#   these are what set-processor-state.sh and queue-list.sh's --connection want.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./common.sh

PG_ID="${NIFI_PG_ID:-a492cb1b-01a0-1000-33b2-ef002a3cb5fe}"
SHOW_IDS=false

for arg in "$@"; do
  case "$arg" in
    --ids) SHOW_IDS=true ;;
    -h|--help)
      grep '^#' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
      exit 0
      ;;
    *) PG_ID="$arg" ;;
  esac
done

nifi_api GET "/nifi-api/flow/process-groups/${PG_ID}" | python3 -c "
import json, sys
show_ids = '$SHOW_IDS' == 'true'
data = json.load(sys.stdin)
pg = data['processGroupFlow']['flow']

print('Processors:')
for p in pg['processors']:
    c = p['component']
    s = p.get('status', {}).get('aggregateSnapshot', {})
    id_str = f\"  id={c['id']}\" if show_ids else ''
    print(f\"  {c['name']:<38} state={c['state']:<9} validation={str(c.get('validationStatus')):<9} tasks={s.get('tasks')}{id_str}\")
    for e in (c.get('validationErrors') or []):
        print(f'      ERROR: {e}')

print()
print('Connections:')
for conn in pg['connections']:
    c = conn['component']
    q = conn.get('status', {}).get('aggregateSnapshot', {}).get('flowFilesQueued')
    rels = ','.join(c.get('selectedRelationships', []))
    marker = '  <-- has items queued' if q else ''
    id_str = f\"  id={c['id']}\" if show_ids else ''
    print(f\"  {c['source']['name']} -> {c['destination']['name']} [{rels}] queued={q}{id_str}{marker}\")
"
