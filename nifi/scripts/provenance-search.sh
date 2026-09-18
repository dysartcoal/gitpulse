#!/usr/bin/env bash
# Search NiFi's Data Provenance history - what already happened to FlowFiles,
# not what's currently queued (see queue-list.sh for that). Two filter modes,
# because the two server-side search-term field names behaved differently
# during testing (2026-09-17):
#   - "FlowFile UUID" worked reliably server-side - use --flowfile-uuid.
#   - "Component Name" was accepted (no error) but silently matched nothing
#     even when matching events genuinely existed - so --component filters
#     client-side in Python instead, against a wider unfiltered fetch. If a
#     future NiFi version fixes server-side component filtering, this is the
#     place to simplify it back down.
#
# Usage:
#   ./provenance-search.sh [--max N] [--flowfile-uuid <uuid>] [--component "<name>"]
#   Defaults: --max 30, no filtering (just the N most recent events).
#   --max applies to the raw fetch in both modes - if --component finds
#   nothing, try a larger --max before concluding the event isn't there; see
#   the note in exploration/notes/2026-09-17-nifi-rest-api-debugging.md about
#   needing maxResults:1000 when other components are generating volume.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./common.sh

MAX=30
FLOWFILE_UUID=""
COMPONENT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --max) MAX="$2"; shift 2 ;;
    --flowfile-uuid) FLOWFILE_UUID="$2"; shift 2 ;;
    --component) COMPONENT="$2"; shift 2 ;;
    -h|--help)
      grep '^#' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [ -n "$FLOWFILE_UUID" ]; then
  BODY="{\"provenance\":{\"request\":{\"maxResults\":${MAX},\"searchTerms\":{\"FlowFile UUID\":{\"value\":\"${FLOWFILE_UUID}\",\"inverse\":false}},\"summarize\":false}}}"
else
  BODY="{\"provenance\":{\"request\":{\"maxResults\":${MAX},\"searchTerms\":{},\"summarize\":false}}}"
fi

nifi_api POST "/nifi-api/provenance" "$BODY" | python3 -c "
import json, sys
component_filter = '$COMPONENT'
d = json.load(sys.stdin)
events = d['provenance']['results']['provenanceEvents']
if component_filter:
    events = [e for e in events if e['componentName'] == component_filter]
events.sort(key=lambda e: e['eventTime'])
print(f'{len(events)} event(s)')
for e in events:
    print(f\"  {e['eventTime']}  {e['componentName']:<30} {e['eventType']:<12} {e['flowFileUuid'][:8]}  {e.get('fileSizeBytes', 0)} bytes\")
"
