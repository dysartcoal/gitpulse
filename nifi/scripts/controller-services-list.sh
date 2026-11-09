#!/usr/bin/env bash
# List every controller service in the whole NiFi instance, recursively
# across every process group, with its state/validation and properties -
# controller services can be scoped either to a specific process group or to
# the whole instance (via the "Management" screen, reached from the
# hamburger menu), and the 2026-09-18 topic-map-lookup mix-up showed it's
# easy to end up unsure which scope a given service actually landed in.
# Checking "everywhere at once" sidesteps that ambiguity entirely rather than
# needing to guess a process-group id up front.
#
# Usage: ./controller-services-list.sh [process-group-id]
#   process-group-id: optional, defaults to root (walks every descendant
#   group from there). Pass a specific group's id to start the walk deeper
#   instead - find one with process-groups-list.sh.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./common.sh

START_ID="${1:-root}"

python3 << PYEOF
import subprocess, json

def api(path):
    token = subprocess.run(
        ["curl", "-sk", "-X", "POST", "${NIFI_BASE_URL}/nifi-api/access/token",
         "-d", "username=${NIFI_USER}&password=${NIFI_PASSWORD}"],
        capture_output=True, text=True
    ).stdout
    r = subprocess.run(
        ["curl", "-sk", f"${NIFI_BASE_URL}{path}", "-H", f"Authorization: Bearer {token}"],
        capture_output=True, text=True
    )
    return json.loads(r.stdout)

def walk(pg_id, depth=0):
    data = api(f"/nifi-api/flow/process-groups/{pg_id}")
    flow = data['processGroupFlow']['flow']
    breadcrumb = data['processGroupFlow'].get('breadcrumb', {}).get('breadcrumb', {})
    label = breadcrumb.get('name', pg_id)
    cs = api(f"/nifi-api/flow/process-groups/{pg_id}/controller-services")
    services = cs.get('controllerServices', [])
    indent = '  ' * depth
    print(f"{indent}[{label}] ({pg_id})")
    if not services:
        print(f"{indent}  (no controller services scoped here)")
    for s in services:
        c = s['component']
        print(f"{indent}  - {c.get('name')}  type={c.get('type', '').rsplit('.', 1)[-1]}  state={c.get('state')}  validation={c.get('validationStatus')}")
        for e in (c.get('validationErrors') or []):
            print(f"{indent}      ERROR: {e}")
        props = c.get('properties') or {}
        for k, v in props.items():
            if v is not None:
                print(f"{indent}      {k} = {v}")
    for child in flow.get('processGroups', []):
        walk(child['component']['id'], depth + 1)

walk("$START_ID")
PYEOF
