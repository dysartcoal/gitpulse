# Runbook — importing, verifying, and re-exporting the NiFi flow

Context: `nifi/flow/github-events-flow.xml` (T009) was hand-authored without a running NiFi
instance available to import it into, so processor types, bundle versions, and property names are
a best effort, not a confirmed-working flow — the file's own header comment says as much. Per
Constitution Principle I (Evidence Over Assumption), a decision/artifact without verification is
treated as unresolved even though the file already exists. This runbook is how to close that gap:
import the hand-written template into a real NiFi instance, fix whatever doesn't wire up as
intended, run it against the real GitHub Events API and local Kafka, then export NiFi's own
verified flow definition to replace the hand-written draft — so the committed file is something
NiFi actually produced and ran, not something typed and guessed at.

Do this manually via the NiFi UI (not scripted) the first time through — the goal is to build
familiarity with how NiFi processors, controller services, and Parameter Contexts are actually
configured, not just to get a working file out the other end.

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

## 2. Import the template

1. On the NiFi canvas, open the hamburger menu (top right) → **Templates**, then **Upload
   Template** and select `nifi/flow/github-events-flow.xml`.
2. Drag the **Template** icon from the top toolbar onto the canvas, select "GitHub Events
   Ingestion" from the dropdown, and click **Add**.
3. **What to look for:** if NiFi rejects the import outright (rather than placing processors on
   the canvas with warning triangles), the file has a structural problem — the "Result" section
   below is where you record what actually happened. A partial import with individual processors
   showing a warning icon is expected and fine; that's what the rest of this runbook walks through
   fixing.

## 3. Create the Parameter Context for `GITHUB_TOKEN`

The template intentionally does **not** encode this — the file's header comment (and T009) leaves
it to be done by hand, since Template XML's parameter-context support is version-dependent.

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
3. On the canvas, right-click the imported process group → **Configure** → **Parameter Context**
   tab → select `github-ingestion` → **Apply**.
4. **What to look for:** the `Poll GitHub Events API` processor's `Request Header Authorization`
   property should show `token #{GITHUB_TOKEN}` resolving without an "unknown parameter" error
   once the context is assigned — check this before moving on, since every downstream step
   depends on the process group actually having a context attached.

## 4. Walk each processor against the file's inline documentation

Go through every processor and controller service on the canvas, right-click → **Configure**, and
compare what NiFi actually populated against the description in the XML's comments (the flow
summary in the header, plus each processor's own `<comment>`). Fix anything that differs. Two
spots the header comment specifically flags as unverified:

1. **`Publish to Kafka`** — the file uses `PublishKafka_2_6`
   (`nifi-kafka-2-6-nar`). Confirm this processor type actually exists in the `apache/nifi:1.27.0`
   image's available processor list (type `PublishKafka` into the "Add Processor" filter and see
   what versions are offered) — NiFi's Kafka-client-versioned processor class names have changed
   across releases, and this is the single highest-risk guess in the file.
2. **Stateful Usage on the two `UpdateAttribute` processors** — Template XML has no way to encode
   processor *state* (as opposed to properties), so these need manual configuration after import:
   - `Track ETag and rate-limit headers`: open **Advanced** → **Stateful Usage**, add a mapping
     that stores `${invokehttp.response.header.ETag}` under the state key `previous.etag` — this
     is what lets `Poll GitHub Events API`'s `Request Header If-None-Match` (which reads
     `${previous.etag}`) actually carry the ETag forward between scheduled runs, not just within a
     single execution.
   - `Increment 300-event counter`: same **Advanced** → **Stateful Usage** panel, incrementing a
     state key `poll.max.window.count` by 1 each time a flowfile reaches this processor.
3. For every other processor, confirm the **Scheduling**, **Properties**, and **Relationships**
   tabs match the `<properties>`/`<autoTerminatedRelationships>`/`<comment>` block for that
   processor's `<id>` in the XML — record any mismatch you had to correct in the Result section
   below.

## 5. Confirm the controller service resolves the shared routing file

1. Hamburger menu → **Controller Settings** → **Controller Services**, find `topic-map-lookup`
   (`PropertiesFileLookupService`).
2. Confirm its `Configuration File` property (`/opt/nifi/topic-map/topic-map.properties`) is
   readable — this is the read-only bind mount from `../config` in `infra/docker-compose.yml`
   (line 91). If NiFi can't read it, the mount path or file permissions are the first thing to
   check, not the processor config.
3. Enable the controller service (bolt icon) before starting the flow — a disabled controller
   service will block `Resolve Kafka topic` from starting.

## 6. Start the flow and watch it run

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
   check the Bulletin Board first (most likely: the `PublishKafka` processor type from Step 4.1
   wasn't actually valid and the process group failed to start cleanly).

## 7. Export the verified flow and replace the hand-written file

Once the flow runs cleanly end to end (events observed in all relevant Kafka topics, no bulletin
errors):

1. Select the `GitHub Events Ingestion` process group → right-click → **Download flow
   definition** (NiFi 1.27.0 exports this as flow definition JSON, not the older Template XML
   format — that's expected and fine; it supersedes the hand-written template either way).
2. Save it over `nifi/flow/github-events-flow.xml` — or alongside it as
   `nifi/flow/github-events-flow.json` if the format changed, updating any reference to the old
   filename (`plan.md`'s Project Structure, `tasks.md` T009) to match.
3. Replace the file's header comment: remove the "hand-authored, unverified" warning and record
   instead that it was exported from a running, verified `apache/nifi:1.27.0` instance, plus the
   date.
4. Update `docs/phases/phase-1-log.md` with what actually happened during import — especially any
   processor type/property that turned out to differ from the hand-written guess, since that's
   exactly the kind of "assumption vs. reality" gap Constitution Principle I exists to catch and
   record, not silently fix and move on from.

## Result

_(fill in as you go)_

- Import succeeded without modification: `___` / required fixes: `___`
- `PublishKafka` processor type that actually worked: `___`
- Stateful Usage configured on both `UpdateAttribute` processors: `___`
- Events observed in all four Kafka topics: `___`
- Flow definition re-exported and committed: `___`

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
