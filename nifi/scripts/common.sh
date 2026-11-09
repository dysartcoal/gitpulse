#!/usr/bin/env bash
# Shared config and auth helpers for the NiFi diagnostics toolkit. Source this
# from every other script here rather than repeating the auth/curl
# boilerplate in each one - see README.md's "Adding a new script" section.
#
# Grew out of the Phase 1 debugging session (2026-09-15 to 2026-09-17) that
# diagnosed a stopped-processor issue, an InvokeHTTP input-queue deadlock, and
# a FlowFile-penalization bug almost entirely through this REST API rather
# than clicking through the UI - see exploration/notes/2026-09-17-nifi-rest-api-debugging.md
# for the reasoning and worked examples this toolkit is distilled from.

# Every value below can be overridden by exporting it before calling a
# script, e.g.: NIFI_BASE_URL=https://localhost:8443 ./flow-status.sh
: "${NIFI_BASE_URL:=https://localhost:8443}"
: "${NIFI_USER:=admin}"
# Falls back to NIFI_ADMIN_PASSWORD (the same env var infra/docker-compose.yml
# reads) before the stack's own hardcoded default, so one export covers both
# bringing up the stack and using these scripts against it.
: "${NIFI_PASSWORD:=${NIFI_ADMIN_PASSWORD:-gitpulse-local-12345}}"

# Fetches a fresh bearer token. Tokens expire after a while - each script
# calls this itself rather than caching a token across separate invocations,
# so there's nothing to go stale between one script run and the next.
nifi_token() {
  curl -sk -X POST "${NIFI_BASE_URL}/nifi-api/access/token" \
    -d "username=${NIFI_USER}&password=${NIFI_PASSWORD}"
}

# Thin wrapper around an authenticated NiFi API call - handles fetching the
# token and setting both required headers, so callers only think about the
# method/path/body they actually care about.
#
# Usage: nifi_api <METHOD> <path-starting-with-/nifi-api/...> [json-body]
nifi_api() {
  local method="$1" path="$2" body="${3:-}"
  local token
  token=$(nifi_token)
  if [ -n "$body" ]; then
    curl -sk -X "$method" "${NIFI_BASE_URL}${path}" \
      -H "Authorization: Bearer ${token}" -H "Content-Type: application/json" \
      -d "$body"
  else
    curl -sk -X "$method" "${NIFI_BASE_URL}${path}" \
      -H "Authorization: Bearer ${token}"
  fi
}
