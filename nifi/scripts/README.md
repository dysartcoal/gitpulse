# NiFi diagnostics toolkit

Terminal/REST-API scripts for inspecting a running NiFi flow, built to replace clicking through
the UI one item at a time — the UI is fine for making changes, but tedious for the kind of
systematic checks debugging needs. Grew out of the Phase 1 debugging session
(2026-09-15 to 2026-09-17) that diagnosed a stopped-processor issue, an `InvokeHTTP` input-queue
deadlock, and a FlowFile-penalization bug almost entirely through `curl` + Python against NiFi's
REST API — see `exploration/notes/2026-09-17-nifi-rest-api-debugging.md` for the reasoning and
worked examples these scripts are distilled from.

## Prerequisites

- The NiFi container running (`docker compose up -d nifi` from `infra/`).
- `python3` on your `PATH` (used for JSON parsing/formatting — every script pipes NiFi's raw JSON
  through a small inline Python snippet rather than trying to do it in pure `bash`).

## Configuration

All scripts source `common.sh`, which reads these environment variables (sensible defaults for
this project's local stack built in — override only if you need to):

| Variable | Default | Notes |
|---|---|---|
| `NIFI_BASE_URL` | `https://localhost:8443` | |
| `NIFI_USER` | `admin` | |
| `NIFI_PASSWORD` | `$NIFI_ADMIN_PASSWORD`, else `gitpulse-local-12345` | Same fallback chain as `infra/docker-compose.yml`, so one `export NIFI_ADMIN_PASSWORD=...` covers both. |
| `NIFI_PG_ID` | the GitHub Events Flow process group's id | Used by `flow-status.sh`/`queue-list.sh` as their default process group — override once via `export` rather than passing it to every call, if you're working in a different group. |

## The scripts

| Script | What it does |
|---|---|
| `common.sh` | Not run directly — sourced by every other script for auth/config. |
| `process-groups-list.sh` | Find a process group's id by listing its children (root, by default). |
| `flow-status.sh` | Every processor's state/validation/tasks and every connection's queued count, for one process group. The single most-used check. Add `--ids` to also print processor/connection ids — what `set-processor-state.sh` and `queue-list.sh --connection` want. |
| `queue-list.sh` | What's actually *in* a connection's queue right now — uuid, size, and penalization status. Different from `flow-status.sh`'s queued *count*. Look a connection up by `--source`/`--dest` name instead of `--connection <id>` if you don't have the id handy. |
| `provenance-search.sh` | Search Data Provenance history (what already happened), filterable by FlowFile UUID or component name. |
| `controller-services-list.sh` | Every controller service in the instance, recursively across every process group, with state/validation/properties. Checks *everywhere* by default rather than needing a process-group id up front — controller services can be scoped to a specific group or instance-wide (the "Management" screen), and it's easy to be unsure which one a given service landed in. |
| `archive-list.sh` | List NiFi's own archived `flow.json.gz` snapshots (`conf/archive/`), with size and — via `--inspect "<group name>"` — a processor/connection count at each point. `--tail N` bounds how many are inspected (default 20; can reach hundreds on an actively-worked flow). |
| `set-processor-state.sh` | Start or stop one processor by id. |
| `restore-flow-config.sh` | **Mutating, stops the container**: overwrite the current flow config with one of `archive-list.sh`'s snapshots, backing up the current one first. See its header comment before running it live. |

Every script supports `-h`/`--help` where it takes flag-style arguments (`queue-list.sh`,
`provenance-search.sh`); the simpler positional ones document their one argument in a header
comment instead.

## Adding a new script

This is meant to grow — when a new REST endpoint or check turns out to be useful, add it here
rather than leaving it as a one-off `curl` in a terminal scrollback. The pattern every script
follows:

```bash
#!/usr/bin/env bash
# One-paragraph comment: what this checks, and *why* it exists (what
# debugging session or question it came from) - not just what the code does.
#
# Usage: ./your-script.sh <required-arg> [optional-flag]
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./common.sh

# ... parse args (positional for one simple required value, a `while`/`case`
# getopts-style loop for anything with multiple or optional flags - see
# flow-status.sh vs. queue-list.sh for one example of each) ...

nifi_api GET "/nifi-api/whatever/endpoint" | python3 -c "
import json, sys
d = json.load(sys.stdin)
# ... pull out and print just the fields that matter for this check ...
"
```

Then:
1. `chmod +x your-script.sh`.
2. Add a row to the table above.
3. If you hit a genuine NiFi REST API gotcha while building it (a search-term field name that
   doesn't work as documented, a field that means something different than its name suggests —
   `queue-list.sh`'s `--connection` note about `Component Name` search terms is an example already
   here) — write it into the script's own header comment, right where the next person (including
   future-you) will actually see it while editing that script, not just in a separate notes file.

## A note on scope

These scripts read and (in `set-processor-state.sh`'s case) start/stop processors — they don't build
or modify flow structure. Building the flow itself (adding processors, wiring connections,
configuring properties) stays a UI task, deliberately — see
`exploration/scratch/2026-09-14-nifi-flow-build/build-guide.md`'s own reasoning for building
hands-on rather than scripting flow construction. This toolkit is for *looking*, not *building*.

## `archive-list.sh`/`restore-flow-config.sh` vs. NiFi's own version control

These two scripts are a safety net against NiFi itself (a crash, a bad flow definition apply,
mass-deletion by accident) — undirected, timestamp-based snapshots with no commit message and no
diff. NiFi 2.x also has a genuinely native, purpose-built alternative for *deliberate* versioning
of a process group's own edits: Git-backed Flow Registry Clients (GitHub/GitLab/Bitbucket/Azure
DevOps), configurable under Controller Settings → Registry Clients, then "Start version control"
on a process group — real commit messages, a real diffable history, reachable right from the
canvas's "Version" menu. Worth setting up once the remaining Phase 1 processors are built and
stable, as the better tool for "I want to go back to yesterday's checkpoint" than digging through
`archive-list.sh`'s raw timestamps — not yet set up or verified hands-on in this project as of
2026-09-18.
