<!--
Sync Impact Report
- Version change: (none) → 1.0.0 (initial ratification)
- Modified principles: n/a (first version)
- Added sections: Core Principles (I. Evidence Over Assumption, II. Security by Enforcement Not
  Convention, III. Cost Is a Design Constraint Not an Afterthought, IV. Test and Validate at the
  Layer Where Data Changes, V. The Repository Is the Portfolio), Scope and Learning Priorities,
  Development Workflow, Governance
- Removed sections: n/a (first version)
- Derived from: README.md, docs/adr/0001 through 0007, and the original project plan
  (00_PROJECT_PLAN.md, kept in the personal job-search tracker outside this repo)
- Follow-up TODOs: none — all placeholders resolved from existing project context, no deferred
  fields
-->

# GitPulse Constitution

## Core Principles

### I. Evidence Over Assumption
Every significant technical decision is captured as an Architecture Decision Record (ADR) in
`docs/adr/`, using the Context/Decision/Consequences template, before or as the decision is acted
on — not reconstructed from memory afterward. A decision without a documented reason is treated as
unresolved, even if code has already been written to implement it. Decisions may be revised, but
revision happens by amending or superseding the ADR, never by silently drifting from what it says.

### II. Security by Enforcement, Not Convention
Where a security property matters, it is enforced by a technical control, not left as an
intention or a habit to remember. Long-lived AWS credentials are avoided wherever a temporary or
federated alternative exists (ADR-0004, ADR-0007); where a long-lived credential cannot be avoided
entirely, its blast radius is constrained by policy (e.g. `RequireMFAForAllActions`), not by
discipline alone. Secrets are never committed to version control, enforced by `.gitignore` from the
first commit, not retrofitted after a scare.

### III. Cost Is a Design Constraint, Not an Afterthought
This project runs on a self-funded, credit-limited AWS account (ADR-0003). Budgets, a billing
alarm, and Cost Explorer are configured before any billable AWS service is touched, not after
usage begins. Compute defaults to local or serverless/pay-per-use; anything that bills by the hour
regardless of use is a deliberate, time-boxed exception, not a default. A design that is
technically superior but meaningfully more expensive loses to one that is adequate and
affordable, unless the more expensive option is itself the specific thing being learned.

### IV. Test and Validate at the Layer Where Data Changes
Data quality and testing are built into each phase as that phase is built, not bolted on once the
pipeline mostly works (ADR-0006). Tooling is chosen per layer rather than forcing one framework to
cover the whole pipeline — `pytest` and `testcontainers` where code transforms or moves data,
schema/volume/profiling checks where Spark transforms it, `dbt` tests and `dbt source freshness`
where `dbt` models it. A broken transformation must fail a test before it reaches the gold layer.

### V. The Repository Is the Portfolio
This repository is built to be read by a hiring manager in ten minutes, not only to be run by its
author. The README is a narrative front door, not a wall of setup instructions. Every ADR is a
standalone file a reader can click into. Every phase gets a live working log while in progress and
a short retrospective once done, in `docs/phases/`. Git history uses feature branches and pull
requests for real chunks of work, even when working solo, with branch protection enforcing a
passing CI check before merge once one exists to require.

## Scope and Learning Priorities

This project deliberately trades a perfectly-wired, permanently-maintained end-to-end system for
genuine, documented hands-on breadth across a deliberately large set of named tools (NiFi, Kafka,
Spark, Iceberg, dbt, Terraform, Kubernetes, Argo CD, GitHub Actions, FastAPI, Secrets Manager). A
later phase quietly retiring or simplifying an earlier tool is not a failure of the plan, provided
the hands-on time with that tool happened and is documented in its phase log. The measure of
success for any phase is genuine learning evidence, not an unbroken, ever-running pipeline.

Any AI-facing or external-facing interface reads from the gold layer only (ADR-0001); this
governs data access regardless of which phase or feature is being built.

## Development Workflow

Each phase is specified with Spec Kit (`/speckit-constitution` once at the project level,
`/speckit-specify` → `/speckit-plan` → `/speckit-tasks` → `/speckit-implement` per phase) before
its implementation begins, rather than specifying the whole project upfront. Real chunks of work
land via pull request, with a description explaining what and why. Phase logs in `docs/phases/`
are updated as work happens, not reconstructed at the end — a log written after the fact is a
retrospective, not a log.

## Governance

This constitution supersedes ad hoc practice for this project. It is amended by updating this
file directly, following semantic versioning: MAJOR for a backward-incompatible removal or
redefinition of a principle, MINOR for a new principle or materially expanded guidance, PATCH for
wording or clarification only. Every ADR should be consistent with this constitution at the time
it is written; where a new ADR reveals a gap or conflict in a principle here, this constitution is
amended alongside it, not left to quietly diverge.

**Version**: 1.0.0 | **Ratified**: 2026-08-22 | **Last Amended**: 2026-08-22
