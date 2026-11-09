# Kafka command reference

A running collection of `docker exec` commands for inspecting the local Kafka broker from the
terminal — same motivation as `nifi/scripts/` (terminal-first over clicking through a UI, though
Kafka has no UI here at all to click through in the first place), but kept as a plain reference
document rather than wrapped in custom shell scripts: Kafka's own CLI tools
(`kafka-topics.sh`, `kafka-console-consumer.sh`, etc.) are already well-parameterized and ergonomic
as direct one-liners, so there's less to gain from wrapping them the way `nifi/scripts/` had to
wrap NiFi's REST API (which needed real JSON parsing/auth boilerplate to be usable at all).

Add to this as you go, the same way `nifi/scripts/` grew — when a new Kafka CLI command turns out
to be useful, add it here with a short explanation of what it does and why, rather than leaving it
as a one-off in a terminal scrollback.

## Prerequisites

The Kafka container running (`docker compose up -d kafka` from `infra/`). Every command below runs
*inside* the `gitpulse-kafka` container via `docker exec` — the Kafka CLI tools live at
`/opt/kafka/bin/` in that image, not on your Mac.

## Topics

**List every topic that actually exists:**
```bash
docker exec gitpulse-kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list
```
An empty result means `infra/create_topics.py` hasn't been run against this broker yet (or the
topics were lost some other way, e.g. the `infra_kafka-data` volume being recreated) — this is
exactly what caught that gap on 2026-09-18, ahead of configuring `Publish to Kafka`'s Kafka
Connection Service in NiFi.

**Describe one topic** — partition count, replication factor, and per-partition leader/replica
detail. Worth checking against `config/topic-map.properties`' three category topics (plus the
`other-activity` fallback) to confirm `infra/create_topics.py` created them with the deliberate
one-partition/replication-factor-1 choice (ADR-0005 — single-broker setup, no cluster to
replicate to):
```bash
docker exec gitpulse-kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 \
  --describe --topic github-events.code-activity
```

## Consuming messages

**Read the first N messages from a topic, from the beginning** — the direct way to confirm NiFi
(or anything else) actually published something real, rather than trusting that publishing
"succeeded" from NiFi's side alone. Already documented in
`docs/runbooks/nifi-flow-import.md` section 5 as the way to verify `Publish to Kafka` is working:
```bash
docker exec gitpulse-kafka /opt/kafka/bin/kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 --topic github-events.code-activity --from-beginning --max-messages 5
```
Swap the topic name for `github-events.discussion-activity` / `-review-activity` / `-other-activity`
to check the others. Drop `--max-messages 5` (and add `Ctrl+C` to stop) to watch new messages arrive
live rather than just reading what's already there.

## Broker health

**Confirm the broker is actually accepting client connections** — cheap, no side effects, the same
check this project's own healthcheck in `infra/docker-compose.yml` uses (a broker that's merely
"running" isn't necessarily accepting connections yet — this is what actually confirms it is):
```bash
docker exec gitpulse-kafka /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092
```
A working broker prints its supported API versions; a broker that's still starting or unreachable
hangs or errors instead.

## Adding to this document

Same pattern as `nifi/scripts/README.md`'s "Adding a new script": when a new Kafka CLI command
turns out to be useful, add it under the right heading (or a new one, if it doesn't fit an
existing category — consumer groups and producing test messages are both likely future additions,
just not needed yet) with a short "what this does and why you'd reach for it" note, not just the
bare command. If a command reveals a genuine gotcha (a flag that doesn't behave as documented, a
default that surprises you), write that into the explanation right here rather than only in a
separate notes file.
