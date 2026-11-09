# 0008 — Databricks lakehouse for Phase 2 onward; Spec Kit retired for a lighter, human-authored workflow

**Status:** Proposed
**Date:** 2026-11-09

## Context

Three things changed between Phase 0's planning and the end of Phase 1's first build stretch.

**The target market points at Databricks.** Reviewing the job adverts I've actually applied against, Databricks appears for roughly a third of the employers (7 of about 20), and it is absent from this project's design entirely. The original Phase 2 stack (S3 + Iceberg, PySpark, dbt, Athena) is credible, but it doesn't close the gap employers are naming most often.

**The volume isn't big enough to produce big-data problems.** The 2026-09-10 volume check showed the GitHub Events API allows at most 60 requests an hour, and repeated calls within the 60-second poll interval return identical events. That ceiling — at most a few thousand events an hour — is ideal for learning ingestion, idempotency and backpressure, but too small to surface the problems a lakehouse exists to solve: data skew, small files, memory spill, schema drift at scale, safe backfills.

**The workflow wasn't building the skill it was meant to evidence.** Spec Kit produced genuinely useful review points (`/speckit-analyze` caught real contradictions before code existed), but `/speckit-implement` meant the Python in `src/` was AI-written and then read, not written. A portfolio project is only evidence of skill if its author can write and defend every line of it. The ceremony (spec, plan, research, data model, contracts, tasks, checklists per feature) is also heavy for one person, and the task list drifted from reality once hands-on NiFi work ran ahead of it (see `phase-1-log.md`, "Next").

Separately, how AI tools are used in data engineering is now a hiring question in its own right — one advert explicitly asks for engineers "already using AI coding tools day-to-day". The answer needs to show judgement: when to delegate to an agent, how its output is verified, and when not to delegate at all.

## Decision

**Platform from Phase 2 onward**

- **Databricks replaces S3 + Iceberg + Athena + dbt** as the lakehouse. Tables are Delta Lake, governed by Unity Catalog; bronze/silver/gold replaces raw/curated/gold as the layer names on the Databricks side.
- **Databricks Free Edition** is the default environment (serverless only, one small SQL warehouse, limited concurrent jobs, daily usage quota). A full Databricks trial on AWS is allowed only as a short, deliberate, torn-down burst, consistent with ADR-0003.
- **Local PySpark + Delta Lake in Docker** covers what serverless Free Edition can't show well: full Spark UI tuning, deliberately reproducing skew, spill and out-of-memory failures at volume.
- **Two sources, one model.** The existing NiFi → Kafka → Python consumer path stays as the live, low-volume trickle. **GH Archive's** hourly historical dumps of the same event stream are added as the high-volume batch source. Deduplicating across both is itself a silver-layer requirement.
- **Landing pattern.** Free Edition can't reach a Kafka broker on my laptop, so the consumer writes newline-delimited JSON files locally and these are uploaded into a Unity Catalog volume (Databricks CLI), where Auto Loader ingests them into bronze. This is a file-landing-zone pattern, not direct streaming from Kafka into Databricks — a knowingly accepted difference from a typical enterprise setup.
- **Orchestration, CI/CD and quality move to Databricks-native tools:** Lakeflow Spark Declarative Pipelines with expectations for data quality, Lakeflow Jobs for orchestration, Declarative Automation Bundles deployed through GitHub Actions, and Unity Catalog grants, column masking and row filters for governance.
- **ADR-0001 is unchanged and now enforced through Unity Catalog:** any AI-facing interface reads gold only, enforced by grants rather than convention.

**Deferred to stretch goals (not cancelled):** Kubernetes via `kind`, Argo CD and Helm (ADR-0005's Phase 4 migration), the FastAPI service, dbt, and cost-as-a-dataset. Airflow is dropped from this project's scope; I already use it professionally.

**Workflow**

- **Spec Kit is retired.** Phase 1's Spec Kit artefacts move to `docs/archive/` as a record; `.specify/` and the speckit skills are removed. The constitution moves to `docs/constitution.md` (v2.0.0).
- **Each chunk of work gets a lightweight cycle instead:** a short written brief (in the phase log or a GitHub issue), tests written alongside the code, one pull request per chunk with a description of what and why, and a review before merge.
- **AI working agreement, by phase of learning:**
  - *Learning mode (default):* I write the application code. Claude explains, reviews and challenges, and does not write files under `src/`, `tests/` or pipeline code unless I explicitly delegate a specific task.
  - *Compare mode:* for selected pieces, I build first, then an agent (Claude Code or Databricks Genie Code) builds from the same brief, and the differences are written up.
  - *Delegate-and-verify mode:* boilerplate (bundle YAML, CI workflow, scaffolding) can be delegated outright. The pull request records what was delegated, what I checked, and what I had to fix.
- `CLAUDE.md` is rewritten to state this agreement and to point at the phase logs as the source of truth for current state, rather than restating it.

## Consequences

**Easier:** the project now closes the skills gap employers name most; the high-volume source produces real investigations rather than hypothetical ones; the Databricks Certified Data Engineer Associate exam domains (ingestion, transformation, Lakeflow Jobs, CI/CD, troubleshooting, governance) map directly onto Phases 2–4, so study and build reinforce each other. Every line in `src/` becomes defensible in an interview.

**Harder or knowingly traded off:**

- Build pace slows while I write the Python myself. This is the point, not a cost to minimise.
- Free Edition is not an enterprise workspace: no account console, no custom compute, no private networking, a daily quota. Workspace administration and cluster sizing are learnt from documentation and a short trial burst, not continuous hands-on use.
- The landing pattern adds a file-upload hop that a production Kafka → Databricks integration wouldn't have.
- The Iceberg, Athena and dbt hands-on experience originally planned won't happen in this project. Databricks' own Iceberg support means the table-format concepts aren't wasted.
- **ADR-0006 is partially superseded:** pytest and testcontainers remain for the consumer; Great Expectations and dbt tests are replaced by Lakeflow pipeline expectations plus PySpark unit tests. **ADR-0005's Phase 4 Kubernetes migration** becomes a stretch goal.
- Losing Spec Kit loses its enforced cross-artifact consistency check. The replacement safeguard is smaller units of work, tests as the specification, and a review on every pull request.

Phase 1's remaining scope (consumer parsing, idempotency, raw and quarantine writers, tests, CI) carries forward unchanged. It is now written by me rather than generated. Outstanding security item T034 (mark `GITHUB_TOKEN` sensitive in the NiFi Parameter Context before a real token is set) carries forward as a blocking task.
