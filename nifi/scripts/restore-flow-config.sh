#!/usr/bin/env bash
# Restore NiFi's flow configuration from an archived snapshot - scripts the
# full procedure worked out (the hard way) during the 2026-09-17 accidental
# mass-deletion recovery, documented in
# exploration/notes/2026-09-17-nifi-config-file-ownership.md - including the
# ownership gotcha that broke the first manual attempt at this (a helper
# container writing as root, which NiFi then couldn't read).
#
# Usage: ./restore-flow-config.sh <archive-filename> [--yes]
#   archive-filename: exactly as archive-list.sh prints it, e.g.
#   20260917T152231+0000_flow.json.gz - a filename, not a full path.
#   --yes: skip the confirmation prompt (for scripting; leave it off for
#   interactive use so you get a chance to back out).
#
# Always backs up the current flow.json.gz first (timestamped .bak, left in
# the container's conf/ directory - clean it up yourself once you've
# confirmed the restore is what you wanted), and stops/restarts the
# gitpulse-nifi container around the swap, since NiFi must not be running
# while its own config file changes out from under it.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./common.sh

if [ $# -lt 1 ]; then
  echo "Usage: $0 <archive-filename> [--yes]" >&2
  echo "Run ./archive-list.sh to see what's available." >&2
  exit 1
fi

ARCHIVE_FILE="$1"
AUTO_YES=false
[ "${2:-}" = "--yes" ] && AUTO_YES=true

ARCHIVE_PATH="/opt/nifi/nifi-current/conf/archive/${ARCHIVE_FILE}"
if ! docker exec gitpulse-nifi test -f "$ARCHIVE_PATH"; then
  echo "No such archived file: ${ARCHIVE_FILE}" >&2
  echo "Run ./archive-list.sh to see what's available." >&2
  exit 1
fi

if [ "$AUTO_YES" != true ]; then
  read -r -p "This stops gitpulse-nifi and overwrites its current flow config with ${ARCHIVE_FILE}. Continue? [y/N] " CONFIRM
  case "$CONFIRM" in
    y|Y) ;;
    *) echo "Aborted."; exit 1 ;;
  esac
fi

echo "Backing up current flow.json.gz..."
BACKUP_NAME="flow.json.gz.before-restore-$(date +%s).bak"
docker exec gitpulse-nifi cp /opt/nifi/nifi-current/conf/flow.json.gz \
  "/opt/nifi/nifi-current/conf/${BACKUP_NAME}"
echo "  saved as conf/${BACKUP_NAME} (inside the container)"

echo "Stopping gitpulse-nifi..."
docker compose -f ../../infra/docker-compose.yml stop nifi

echo "Copying ${ARCHIVE_FILE} over flow.json.gz, as the nifi user (uid/gid 1000:1000 -"
echo "see exploration/notes/2026-09-17-nifi-config-file-ownership.md for why this matters)..."
docker run --rm --user 1000:1000 -v infra_nifi-conf:/conf alpine sh -c \
  "cp /conf/archive/${ARCHIVE_FILE} /conf/flow.json.gz"

echo "Starting gitpulse-nifi..."
docker compose -f ../../infra/docker-compose.yml up -d nifi

echo "Waiting for it to report healthy..."
for i in $(seq 1 30); do
  STATUS=$(docker inspect --format='{{.State.Health.Status}}' gitpulse-nifi 2>/dev/null || echo "unknown")
  if [ "$STATUS" = "healthy" ]; then
    echo "Healthy after ~$((i * 2))s. Restore looks successful."
    exit 0
  fi
  sleep 2
done
echo "Did not report healthy within 60s - check 'docker logs gitpulse-nifi' for errors." >&2
echo "('insufficient read/write privileges' would mean an ownership problem - see the note above)" >&2
exit 1
