# Runbook — checking real GitHub Events API volume against the 300-event window

Context: GitHub's public `/events` timeline caps at 300 events and only covers the last 30 days
(and event latency can run 30s–6h) — a hard ceiling, not a tunable setting. ADR-0002 assumed
"lower volume" than Wikipedia EventStreams when choosing this source, but that was never checked
against real numbers. This runbook is how to check it directly, before trusting SC-001 ("zero
events lost") and SC-003 ("catches up without gaps") as achievable — per Constitution Principle I,
a decision without evidence is treated as unresolved, so this closes that gap with real data
instead of an assumption.

## 1. A one-off empirical check (do this before implementation, and again before Phase 1 is considered done)

No pipeline needed for this — it's two plain requests against the live API.

**Steps:**
1. `curl -sD- https://api.github.com/events -o /tmp/gh-events-1.json`
   The `-D-` flag prints response headers to stdout; redirect the body to a file so you can
   inspect both separately.  The `-o /tmp/gh-events-1.json`: Writes the response body to `/tmp/gh-events-1.json`.
   Result: HTTP response headers appear in the terminal, while the JSON event payload is saved to `/tmp/gh-events-1.json`.
2. Note from the headers: `X-Poll-Interval` (the interval GitHub expects you to honour — likely
   60, in seconds), `X-RateLimit-Remaining`, and `ETag`.
3. Count the events actually returned: `jq 'length' /tmp/gh-events-1.json` (or, without `jq`,
   `grep -o '"id"' /tmp/gh-events-1.json | wc -l`). If this is at or near 300, the window is
   already tight even on a single poll.
4. Wait exactly the `X-Poll-Interval` value from step 2 (e.g. 60s), then repeat step 1 into
   `/tmp/gh-events-2.json`, this time sending the ETag from the first response as a conditional
   header: `curl -sD- -H "If-None-Match: <etag-from-step-2>" https://api.github.com/events -o /tmp/gh-events-2.json`.
5. Compare the two responses' `id` sets: `jq -r '.[].id' /tmp/gh-events-1.json | sort > /tmp/ids1.txt`,
   same for the second file, then `comm -13 /tmp/ids1.txt /tmp/ids2.txt | wc -l` gives the count of
   genuinely *new* event ids that appeared in one poll interval — this is the real turnover rate to
   compare against the 300-event cap, not a guess.
6. Repeat steps 4–5 a handful of times across different times of day (activity is very unlikely to
   be uniform across a 24-hour period) before drawing a conclusion from a single sample.

**What to look for:** if the new-ids-per-interval count from step 5 is comfortably under 300 across
multiple samples (including your busiest observed interval), the assumption in ADR-0002 holds and
Phase 1 can proceed as planned. If it's regularly close to or at 300, the pipeline will lose events
under normal operation, not just during outages — worth reading `research.md`'s volume note for the
options at that point (narrower scope, faster polling within rate-limit headroom, or documenting
the loss as a known, accepted limitation rather than letting SC-001 overpromise).

**Result:** New events returned per poll: **30**.

Conclusion:

- **Poll interval behaviour:** the `X-Poll-Interval` header returned a value of **60 seconds**.
  Polling again before that interval has elapsed returns the **same JSON body** — i.e. the
  identical set of events — rather than fresh data.
- **Rate limit behaviour:** `x-ratelimit-limit` was **60**, meaning the API allows a maximum of
  60 requests per rate-limit window. `x-ratelimit-reset` is set to exactly **one hour after the
  first request of that window** (i.e. the first request that started the current 60-request
  allowance).
- **The two are independent, and that has a real cost:** the rate limit is consumed by every
  request sent, regardless of whether it falls inside or outside the 60-second poll interval.
  The API does **not** deduplicate or reject early requests — it simply returns the same (stale)
  event set and still counts the request against the quota. The server enforces no minimum
  spacing itself; honouring the 60-second interval is entirely the caller's responsibility, and
  failing to do so both wastes a request and yields no new data.
- **Practical ceiling:** if every request were spaced at exactly 60 seconds, 60 requests would
  fit within the hour before the limit resets. In practice, timing precision (clock drift,
  network latency, scheduler jitter) makes hitting that exact cadence unreliable, so the
  realistic, sustainable throughput is closer to **59 requests per hour**.

With 30 new events per poll at roughly 59 achievable polls per hour, observed turnover is nowhere
near the 300-event cap per poll, so the assumption in ADR-0002 holds against this sample. Note
this is throughput, not a substitute for genuinely busy-period sampling — see the note in "What to
look for" above about checking multiple times of day before treating this as final.

## 2. An ongoing detection mechanism (not just a one-off check)

A one-off check only proves the assumption held *at the time it was run* — GitHub's own traffic can
grow over the life of this project. The consumer (or NiFi) should log a warning, with a running
count, every time a poll response returns exactly 300 events — the documented maximum — since
that's a reliable, cheap signal the window may already be truncating real data, without needing to
know the true turnover rate at runtime. This is a task-level implementation detail (see
`research.md`), not solved by this runbook, but the runbook's own check in Part 1 is what tells you
whether that signal is ever likely to fire in practice.

## 3. Review step, once the pipeline is actually running locally

Once Phase 1's Docker Compose stack has been running for real (see `quickstart.md`'s validation
scenarios), re-run Part 1's check once more and cross-reference it against the warning log from
Part 2 over the same period — confirm the two agree (no warnings logged, and the empirical new-ids
count stayed well under 300), or investigate if they don't.

**Result:** _(fill in once Phase 1 has run locally for a meaningful period)_ Warnings logged: `___`.
Empirical re-check still consistent with Part 1: `___`.
