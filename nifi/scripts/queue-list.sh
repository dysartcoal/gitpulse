#!/usr/bin/env bash
# List the actual FlowFiles currently sitting in a connection's queue - their
# uuid, size, and (importantly) whether each one is penalized and for how
# much longer. This is what finally caught the Sept 2026 FlowFile-
# penalization bug; a plain queued-count (flow-status.sh) can't show this,
# only a queue *listing* can.
#
# Uses flag-style arguments (unlike flow-status.sh's plain positional one) -
# a second style deliberately kept in this toolkit as a worked example for
# whichever pattern suits a new script you add.
#
# Usage:
#   ./queue-list.sh --connection <connection-id>
#   ./queue-list.sh --pg <process-group-id> --source "<name>" --dest "<name>"
#
# The second form looks the connection id up for you by matching the source
# and destination processor *names* within that process group - convenient
# when you know the two processors' names but not the connection's own id
# (which flow-status.sh's output does print, if you already have it handy).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./common.sh

CONNECTION_ID=""
PG_ID="${NIFI_PG_ID:-a492cb1b-01a0-1000-33b2-ef002a3cb5fe}"
SOURCE_NAME=""
DEST_NAME=""

while [ $# -gt 0 ]; do
  case "$1" in
    --connection) CONNECTION_ID="$2"; shift 2 ;;
    --pg) PG_ID="$2"; shift 2 ;;
    --source) SOURCE_NAME="$2"; shift 2 ;;
    --dest) DEST_NAME="$2"; shift 2 ;;
    -h|--help)
      grep '^#' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [ -z "$CONNECTION_ID" ]; then
  if [ -z "$SOURCE_NAME" ] || [ -z "$DEST_NAME" ]; then
    echo "Either --connection <id>, or both --source and --dest, are required." >&2
    exit 1
  fi
  CONNECTION_ID=$(nifi_api GET "/nifi-api/flow/process-groups/${PG_ID}" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for conn in data['processGroupFlow']['flow']['connections']:
    c = conn['component']
    if c['source']['name'] == '$SOURCE_NAME' and c['destination']['name'] == '$DEST_NAME':
        print(c['id'])
        break
")
  if [ -z "$CONNECTION_ID" ]; then
    echo "No connection found from '$SOURCE_NAME' to '$DEST_NAME' in process group $PG_ID" >&2
    exit 1
  fi
fi

# Listing a queue is a submit-then-fetch request, the same shape as a
# provenance search (see provenance-search.sh) but a different endpoint
# family (flowfile-queues, not provenance) - NiFi treats "list what's in this
# queue right now" as a job, not a plain GET, even though it only takes a
# moment for a queue this size.
LISTING=$(nifi_api POST "/nifi-api/flowfile-queues/${CONNECTION_ID}/listing-requests")
REQUEST_ID=$(echo "$LISTING" | python3 -c "import json,sys; print(json.load(sys.stdin)['listingRequest']['id'])")
sleep 1
nifi_api GET "/nifi-api/flowfile-queues/${CONNECTION_ID}/listing-requests/${REQUEST_ID}" | python3 -c "
import json, sys
d = json.load(sys.stdin)['listingRequest']
print('queue size:', d['queueSize']['objectCount'], f\"({d['queueSize']['byteCount']} bytes)\")
for f in d.get('flowFileSummaries', []):
    pen = f.get('penalized')
    pen_str = f'penalized, {f.get(\"penaltyExpiresIn\")}ms remaining' if pen else 'not penalized'
    print(f\"  {f['uuid']}  {f['size']:>8} bytes  queued {f['queuedDuration']}ms  {pen_str}\")
"
