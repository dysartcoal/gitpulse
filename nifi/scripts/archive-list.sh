#!/usr/bin/env bash
# List every archived flow.json.gz NiFi has saved to conf/archive/, with size
# and (optionally) a processor/connection count for a named process group at
# that point in time. This is what actually found the right restore point
# during the 2026-09-17 accidental mass-deletion recovery: a sudden file-size
# drop (~3400 bytes to ~1500) flagged roughly where it happened, and the
# processor count on the candidate file either side confirmed it precisely -
# see exploration/notes/2026-09-17-nifi-config-file-ownership.md.
#
# Usage: ./archive-list.sh [--inspect "<Process Group Name>"] [--tail N]
#   --inspect: decompress each archived file and print how many processors
#   and connections the named group had in it at that point. Slower (one
#   decompress+parse per file) but this is what you actually want when
#   hunting for a specific "right before it broke" restore point rather than
#   just browsing sizes.
#   --tail N: only look at the N most recent archives (default 20). NiFi
#   saves on nearly every UI change, so this can genuinely reach hundreds of
#   entries on an actively-worked flow (confirmed: 200+ during Phase 1) -
#   --inspect against all of them would mean that many decompress calls.
#   Pass --tail 0 for no limit if you really need the full history.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./common.sh

INSPECT_GROUP=""
TAIL_N=20
while [ $# -gt 0 ]; do
  case "$1" in
    --inspect) INSPECT_GROUP="$2"; shift 2 ;;
    --tail) TAIL_N="$2"; shift 2 ;;
    -h|--help)
      grep '^#' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

# Parsed from plain `ls -la` rather than `stat`, so this doesn't depend on
# which stat flavour (GNU/BusyBox) happens to be in this image - `$1 ~ /^-/`
# keeps only regular files, skipping the `.`/`..` entries `-la` includes.
ENTRIES=$(docker exec gitpulse-nifi sh -c \
  "ls -la /opt/nifi/nifi-current/conf/archive/ 2>/dev/null" \
  | awk '$1 ~ /^-/ {print $5, $NF}')

if [ -z "$ENTRIES" ]; then
  echo "No archived flow files found."
  exit 0
fi

SORTED=$(echo "$ENTRIES" | sort -k2)
if [ "$TAIL_N" != "0" ]; then
  SORTED=$(echo "$SORTED" | tail -n "$TAIL_N")
fi

echo "$SORTED" | while read -r SIZE NAME; do
  if [ -n "$INSPECT_GROUP" ]; then
    COUNTS=$(docker exec gitpulse-nifi sh -c "zcat '/opt/nifi/nifi-current/conf/archive/${NAME}'" | python3 -c "
import json, sys
target = '''$INSPECT_GROUP'''
def find_group(g):
    if g.get('name') == target:
        return g
    for pg in g.get('processGroups', []):
        found = find_group(pg)
        if found:
            return found
    return None
try:
    d = json.load(sys.stdin)
    root = d.get('rootGroup', d)
    g = find_group(root)
    print('group not found' if g is None else f\"{len(g.get('processors', []))} processors, {len(g.get('connections', []))} connections\")
except Exception as e:
    print(f'parse error: {e}')
")
    printf '%-34s  %8s bytes   %s\n' "$NAME" "$SIZE" "$COUNTS"
  else
    printf '%-34s  %8s bytes\n' "$NAME" "$SIZE"
  fi
done
