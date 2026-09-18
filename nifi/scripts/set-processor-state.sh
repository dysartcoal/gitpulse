#!/usr/bin/env bash
# Start or stop a single processor by id - handles fetching its current
# revision first, since every NiFi write (this one included) is optimistic-
# locked and needs the revision it last saw to avoid clobbering a change made
# elsewhere (e.g. someone editing the same processor in the UI at the same
# time).
#
# Usage: ./set-processor-state.sh <processor-id> <RUNNING|STOPPED>
#   Find a processor's id with: ./flow-status.sh --ids
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./common.sh

if [ $# -ne 2 ]; then
  echo "Usage: $0 <processor-id> <RUNNING|STOPPED>" >&2
  exit 1
fi

PID="$1"
TARGET_STATE="$2"

case "$TARGET_STATE" in
  RUNNING|STOPPED) ;;
  *) echo "State must be RUNNING or STOPPED, got: $TARGET_STATE" >&2; exit 1 ;;
esac

REVISION=$(nifi_api GET "/nifi-api/processors/${PID}" | python3 -c "import json,sys; print(json.load(sys.stdin)['revision']['version'])")

nifi_api PUT "/nifi-api/processors/${PID}" \
  "{\"revision\":{\"clientId\":\"nifi-scripts-toolkit\",\"version\":${REVISION}},\"component\":{\"id\":\"${PID}\",\"state\":\"${TARGET_STATE}\"}}" \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
c = d.get('component', {})
print('state:', c.get('state'))
errs = c.get('validationErrors')
if errs:
    for e in errs:
        print('  validation error:', e)
"
