#!/usr/bin/env bash
# List the direct child process groups of a given group, with their ids -
# use this to find the process-group-id argument flow-status.sh and
# queue-list.sh need, e.g. when a new flow is added alongside GitHub Events
# Flow.
#
# Usage: ./process-groups-list.sh [parent-process-group-id]
#   Defaults to "root" (the top-level canvas). Only lists direct children of
#   the given group, not nested grandchildren - pass a child's id as the
#   argument to descend further, one level at a time.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./common.sh

PARENT_ID="${1:-root}"

nifi_api GET "/nifi-api/flow/process-groups/${PARENT_ID}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
groups = data['processGroupFlow']['flow']['processGroups']
if not groups:
    print('(no child process groups under this one)')
for pg in groups:
    c = pg['component']
    print(f\"{c['id']}  {c['name']}\")
"
