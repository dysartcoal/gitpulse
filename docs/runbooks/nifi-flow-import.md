# Runbook — building, verifying, and exporting the NiFi flow

Context: `nifi/flow/github-events-flow.xml` (T009) was hand-authored without a running NiFi
instance available to import it into. A structural comparison against a real NiFi export (see
`exploration/investigations/2026-09-14-compare-nifi-basic-w-claude-generated/`) later showed the
file uses a fundamentally wrong Template XML schema — not a minor fixable gap — so import-then-fix
was abandoned as an approach. Separately, this project moved from NiFi 1.27.0 to 2.12.0
(`infra/docker-compose.yml`), and NiFi 2.0 **removes Templates entirely** — so the old
import-a-template mechanism this runbook originally described isn't just superseded, it no longer
exists in the running NiFi's UI at all.

Per Constitution Principle I (Evidence Over Assumption), a decision/artifact without verification
is treated as unresolved even though the file already exists. This runbook is how to close that
gap on NiFi 2.12.0: build the flow directly on the canvas (using
`exploration/scratch/2026-09-14-nifi-flow-build/build-guide.md` as the processor-by-processor
checklist), run it against the real GitHub Events API and local Kafka, then export NiFi's own
verified flow definition to replace the hand-written draft — so the committed file is something
NiFi actually produced and ran, not something typed and guessed at.

Do this manually via the NiFi UI (not scripted) — the goal is to build familiarity with how NiFi
processors, controller services, and Parameter Contexts are actually configured, not just to get a
working file out the other end.

## Prerequisites

- Docker and Docker Compose installed locally.
- `infra/create_topics.py` already run once against a live broker (T008), so the three Kafka
  topics exist before anything tries to publish to them.
- `config/topic-map.properties` (T007) present — mounted read-only into the NiFi container per
  `infra/docker-compose.yml`.
- Optional: a GitHub PAT exported as `GITHUB_TOKEN` in your shell before `docker compose up`, if
  you want to test the authenticated path (5,000 req/hour) rather than unauthenticated (60/hour).
  Unset is fine for a first pass — the flow is designed to work either way.

## 1. Bring up the stack and reach the NiFi UI

1. `cd infra && docker compose up -d`
2. Wait for both healthchecks to pass: `docker compose ps` should show `kafka` and `nifi` as
   `healthy` (NiFi's JVM startup is genuinely slow — give it the full 90s `start_period` before
   worrying).
3. Open `https://localhost:8443/nifi/` in a browser. Expect a self-signed cert warning (accept it
   — this is `ADR-0003`'s local-only stack, not exposed beyond localhost).
4. Log in with `admin` / the value of `NIFI_ADMIN_PASSWORD` if you set one, otherwise the
   compose file's default (`gitpulse-local-12345` — see `infra/docker-compose.yml`).

## 2. Build the flow

Follow `exploration/scratch/2026-09-14-nifi-flow-build/build-guide.md` processor by processor —
it's the checklist derived from this flow's design intent (processor types, property values,
wiring, the reasoning behind each step), built for NiFi 2.12.0 specifically (the `Kafka Connection
Service` controller service `PublishKafka` now requires, in place of 1.x's direct
`bootstrap.servers` property, is the one real behavioural difference from the original design).

## 3. Create the Parameter Context for `GITHUB_TOKEN`

1. Hamburger menu → **Parameter Contexts** → **+** to create one, named e.g.
   `github-ingestion`.
2. Add a parameter named `GITHUB_TOKEN`. Two ways to populate it:
   - **Preferred** — configure NiFi's `EnvironmentVariableParameterProvider` (Controller Settings
     → Parameter Providers) to read the container's `GITHUB_TOKEN` env var (passed through from
     your shell by `infra/docker-compose.yml`'s `GITHUB_TOKEN: ${GITHUB_TOKEN:-}`), then fetch/apply
     parameters from it.
   - **Manual fallback** — type the token directly into the parameter's value (mark it
     "sensitive" if NiFi offers that toggle) if the provider route doesn't behave as expected on
     first try.
3. Assign the `github-ingestion` context to wherever you're building the flow (the root canvas, or
   the process group if you nested one) via **Configure** → **Parameter Context** tab → **Apply**.
4. **What to look for:** `Poll GitHub Events API`'s `Authorization` header property should show
   `token #{GITHUB_TOKEN}` resolving without an "unknown parameter" error once the context is
   assigned — check this before moving on, since every downstream step depends on it.

## 4. Create (or confirm) the controller services this flow depends on

Two controller services, both **scoped to the `GitHub Events Flow` process group** (right-click
empty canvas space *inside* that group → **Configure** → **Controller Services** tab → **+** —
not the root-canvas/instance-wide controller services under the hamburger menu):

1. **`topic-map-lookup`** (`PropertiesFileLookupService`) — needed before you configure `Resolve
   Kafka topic` (build guide step 12). This is purely a local file lookup — no actual Kafka broker
   connectivity involved, despite the name.
   - Add a `PropertiesFileLookupService`, rename it `topic-map-lookup`.
   - Properties tab: `Configuration File` = `/opt/nifi/topic-map/topic-map.properties` (the
     read-only bind mount from `../config` in `infra/docker-compose.yml` — nothing to change on
     the host side, the file already exists there from T007).
   - If NiFi can't read it once enabled, the mount path or file permissions are the first thing to
     check, not the processor config.
2. **The Kafka Connection Service** (`Kafka3ConnectionService`) — needed before you configure
   `Publish to Kafka` (build guide step 15), *not* before `Resolve Kafka topic` — don't set this
   one up until you actually reach step 15.
   - `bootstrap.servers` = `kafka:9092` (the Compose **service** name, not `gitpulse-kafka` — see
     `exploration/notes/2026-09-11-docker-compose-networking.md` for why).

Whichever one you're setting up, **enable it** (bolt icon) once configured — a disabled controller
service blocks any processor that references it from starting, and won't even appear as a
selectable option in a processor's own property dropdown until it's been added at this level.

## 5. Start the flow and watch it run

1. Select all processors on the canvas (Ctrl/Cmd+A) and click **Start** (the play icon), or start
   them individually in dependency order if you want to watch each stage settle.
2. Watch the **Bulletin Board** (bell icon, top right) for warnings/errors as `InvokeHTTP` begins
   polling. A successful first poll should show flowfiles queuing on the connection into
   `Track ETag and rate-limit headers` within the 60s scheduling period.
3. Confirm events actually land in Kafka: from the host,
   ```
   docker exec gitpulse-kafka /opt/kafka/bin/kafka-console-consumer.sh \
     --bootstrap-server localhost:9092 --topic github-events.code-activity --from-beginning --max-messages 5
   ```
   (swap the topic name to check `github-events.discussion-activity` / `-review-activity` /
   `-other-activity` too).
4. **What to look for:** messages appearing with the expected JSON event payload, keyed by event
   `id` (per `kafka-topic-contract.md`) — if nothing appears after a couple of poll intervals,
   check the Bulletin Board first.

## 6. Export the verified flow and replace the hand-written file

Once the flow runs cleanly end to end (events observed in all relevant Kafka topics, no bulletin
errors):

1. Select everything (or the process group, if nested) → right-click → **Download flow
   definition** — NiFi 2.12.0 exports this as flow definition JSON; there's no Template XML option
   any more, so this is the only export path.
2. Save it as `nifi/flow/github-events-flow.json`, updating any reference to the old
   `.xml` filename (`plan.md`'s Project Structure, `tasks.md` T009) to match, and remove the old
   hand-written `.xml` file.
3. Give the new file a header comment recording that it was exported from a running, verified
   `apache/nifi:2.12.0` instance, plus the date — replacing the old file's "hand-authored,
   unverified" warning.
4. Update `docs/phases/phase-1-log.md` with what actually happened while building — especially any
   processor property or relationship that turned out to differ from the build guide's expectation,
   since that's exactly the kind of "assumption vs. reality" gap Constitution Principle I exists to
   catch and record, not silently fix and move on from.

## Result

_(fill in as you go)_

- Build completed without unresolved processor validation warnings: `___`
- Kafka Connection Service configured and working: `___`
- Stateful Usage configured on both `UpdateAttribute` processors: `___`
- Events observed in all four Kafka topics: `___`
- Flow definition exported and committed as `nifi/flow/github-events-flow.json`: `___`

## Other ways to generate this file (not used here, noted for later)

Hand-authoring the template was the unusual path — worth knowing the alternatives if this
project's NiFi usage grows past a single local instance:

- **NiFi Registry** — version process groups into a Registry instance instead of exporting static
  files by hand; other NiFi instances (a future CI/staging NiFi) pull a versioned flow directly.
  The natural next step if this flow needs to move beyond one developer's laptop.
- **`nipyapi`** (Python client for NiFi's REST API) — define/apply the flow programmatically,
  closer to how `infra/create_topics.py` already treats Kafka topics as code rather than a manual
  console step. Worth considering if this flow needs to be rebuilt reproducibly (e.g. in CI)
  rather than configured once by hand.

Neither is needed for this runbook's purpose — getting one verified, working flow definition
committed — but either would remove the "was this ever actually re-verified" question this
runbook exists to answer, going forward.
