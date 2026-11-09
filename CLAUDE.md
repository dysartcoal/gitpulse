# CLAUDE.md

Guidance for Claude (Claude Code and claude.ai sessions) working in this repository.

## What this repository is

GitPulse is Kim's self-directed data engineering learning project and portfolio. It ingests
GitHub's public event stream (live via NiFi → Kafka → a Python consumer, plus GH Archive's hourly
dumps for volume), builds a bronze/silver/gold lakehouse on Databricks, and is operated the way a
production platform would be. The repository (README, ADRs, phase logs, investigations) is meant
to be read by a hiring manager, not just run.

**Current state: don't trust this file for it.** The authoritative record of what is done and what
is next is the live log in `docs/phases/` (currently `phase-1-log.md`). Read it before assuming
anything is built. This file deliberately doesn't restate status, because restated status drifts.
If you notice this file contradicting the phase log or the code, say so and suggest a fix.

## How Claude works here — the AI working agreement (ADR-0008)

This project's purpose is to build and evidence Kim's own skill (constitution Principle VI: the
author can defend every line). That changes the default behaviour expected of Claude.

**Learning mode is the default.**

- Do **not** create or edit files under `src/`, `tests/`, `infra/*.py`, pipeline or notebook code
  unless Kim explicitly delegates that specific task in the current session.
- Explain concepts, review code Kim has written, point out bugs, risks and missing tests, and ask
  questions that lead her to the answer. Prefer a hint first, then a fuller explanation if asked,
  before ever giving the full solution.
- Short illustrative snippets in chat are fine when they teach a concept. They must not be a
  ready-to-paste solution to the task Kim is working on.
- When reviewing, be direct: name what is wrong and why, rank issues by severity, and say clearly
  when something is good enough to merge.

**Compare mode** (only when Kim asks): Kim builds a piece first; Claude then builds the same thing
from the same brief, on a separate branch or in `exploration/scratch/`. Help Kim write up the
differences.

**Delegate-and-verify mode** (only when Kim explicitly delegates): Claude may write the delegated
files — typically boilerplate such as Declarative Automation Bundle YAML, GitHub Actions workflows
or scaffolding. Before handing back, list what Kim should check. The pull request description must
record what was delegated, what was checked and what had to be fixed.

**Documentation** (ADRs, runbooks, phase-log entries, READMEs): Claude may draft these when asked.
Kim reviews and commits them. Flag anything uncertain or unverified rather than presenting it as
fact.

**Attribution:** commits containing Claude-written content carry a `Co-Authored-By` trailer, so
authorship is visible in history.

## Governing rules — read `docs/constitution.md`

Every decision traces back to the project constitution (v2.0.0). The principles that most affect
day-to-day work:

- **Evidence Over Assumption:** a significant technical decision gets an ADR in `docs/adr/`
  (Context / Decision / Consequences, template `0000-template.md`) before or as it is acted on.
- **Security by Enforcement, Not Convention:** no long-lived credentials where a temporary
  alternative exists; secrets never committed (enforced by gitleaks, below).
- **Cost Is a Design Constraint:** Databricks Free Edition and local compute by default; AWS or a
  full Databricks trial only as a deliberate, time-boxed, torn-down burst (ADR-0003).
- **Test and Validate at the Layer Where Data Changes:** `pytest` + `testcontainers` for the
  consumer, PySpark unit tests for transforms, Lakeflow expectations at each lakehouse layer.
- **The Repository Is the Portfolio:** phase logs updated as work happens; work lands via feature
  branch and pull request; every PR states any AI involvement.
- **The Author Can Defend Every Line:** see the working agreement above.

**Any AI-facing or external-facing interface reads from the gold layer only** (ADR-0001), enforced
through Unity Catalog grants.

## Workflow for a chunk of work

Spec Kit was retired by ADR-0008; its Phase 1 artefacts are archived in `docs/archive/`. Instead:

1. **Brief:** a few lines in the phase log or a GitHub issue — what this chunk delivers, how it
   will be tested, what is out of scope.
2. **Branch:** one branch per chunk, off `main`.
3. **Build with tests:** tests written alongside the code, not afterwards.
4. **Pull request:** description covers what, why, how it was tested, and AI involvement.
5. **Review:** Claude reviews on request; Kim merges.
6. **Log:** a dated entry in the phase log. A real problem found and fixed gets an investigation
   write-up in `exploration/investigations/` — these become interview stories.

## Code comments — self-documenting code

Every function, class and non-trivial block carries a comment stating its expected outcome or the
reason a particular approach was taken — not a restatement of what the code literally does. The
bar: reading this repository alone should answer "why is it built this way?". This applies to
infrastructure config (NiFi flows, Docker Compose, CI, bundle YAML) as well as application code.

- Above a function or class, say what it produces or guarantees, not a restatement of its name.
- Where a specific choice was made over an obvious alternative, say why at that point in the code,
  even if the reasoning also lives in an ADR.
- Tests get the same treatment: a comment above each test says what behaviour it verifies and why
  it matters — which requirement, edge case or past bug it guards against.
- When reviewing Kim's code, check it against this standard and point out gaps; don't silently
  rewrite her comments.

## Secret scanning — gitleaks pre-commit hook

`.pre-commit-config.yaml` runs [gitleaks](https://github.com/gitleaks/gitleaks) on every commit
(constitution Principle II).

```bash
.venv/bin/pip install pre-commit   # once, into the project venv
.venv/bin/pre-commit install       # wires .git/hooks/pre-commit for this clone
pre-commit run --all-files         # scan the whole repo, not just staged changes
```

Verified against a real detection (a randomly generated AWS-shaped access key). Two known false
negatives, both explained by the test input: a malformed fake GitHub PAT, and AWS's published
placeholder `AKIAIOSFODNN7EXAMPLE`, which gitleaks allowlists. Confirm with a genuinely
secret-shaped value before trusting an unexpectedly clean result.

## Architecture (design — check the phase log for what is built)

```text
GitHub Events API ─▶ NiFi ─▶ Kafka ─▶ Python consumer ─▶ local NDJSON (raw / quarantine)
                                                              │ upload (Databricks CLI)
GH Archive hourly dumps ──────────────────────────────────────▼
                                         Unity Catalog volume ─▶ Auto Loader ─▶ bronze
                                         ─▶ silver (dedupe across sources, flatten, late data)
                                         ─▶ gold ─▶ AI / external interfaces (gold only)
```

- **Phases** (ADR-0008): 1 local ingestion (NiFi → Kafka → consumer, Kim-written, tested);
  2 Databricks lakehouse + GH Archive + local Spark investigations; 3 production practices
  (Lakeflow Declarative Pipelines with expectations, Lakeflow Jobs, Bundles via GitHub Actions,
  Unity Catalog governance, incident drills); 4 the AI boundary (an LLM step inside a pipeline, a
  natural-language interface over gold). Stretch: Kubernetes/Argo CD/Helm, FastAPI, dbt.
- **Local Spark:** PySpark + Delta Lake in Docker, for Spark UI work and reproducing skew, spill
  and out-of-memory problems that Free Edition's serverless compute hides.
- **Free Edition constraints to remember:** serverless only, one 2X-Small SQL warehouse, limited
  concurrent job tasks, one active pipeline per type, a daily usage quota, restricted outbound
  internet (wider after LinkedIn verification).

## Repository structure

- `docs/adr/` — architecture decision records. Read the relevant ADR before revisiting a decision.
- `docs/constitution.md` — the project's governing principles.
- `docs/phases/` — live log per in-progress phase, retrospective per completed phase. Authoritative
  for status.
- `docs/runbooks/` — step-by-step operational procedures.
- `docs/archive/` — retired material (Phase 1 Spec Kit artefacts), kept as a record.
- `exploration/` — gitignored investigations, notes and scratch work; only each folder's
  `README.md` is tracked.
- `src/consumer/`, `src/schemas/` — the Python consumer and the event JSON Schemas.
- `infra/` — Docker Compose (NiFi + Kafka), topic creation.
- `nifi/` — exported NiFi flow definition and terminal toolkit scripts.
- `config/topic-map.properties` — single source of truth for event-type → Kafka topic routing,
  read by both NiFi and the consumer.

## Environment setup

`pyproject.toml` requires Python 3.12, but the machine's default `python3` is 3.11 via `pyenv`, so
create the venv against 3.12 explicitly:

```bash
~/.pyenv/versions/3.12.7/bin/python3.12 -m venv .venv   # once, per machine
.venv/bin/pip install -e ".[test]"                      # package plus pytest/testcontainers
.venv/bin/python infra/create_topics.py                 # create the Kafka topics
```

`.venv/` is gitignored.
