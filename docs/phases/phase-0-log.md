# Phase 0 log — Foundations

**Status:** In progress
**Started:** 2026-08-21

## Done

- 2026-08-21 — Repo created on GitHub (public), cloned locally.
- 2026-08-21 — Scaffolded repo structure: `README.md`, MIT `LICENSE`, `.gitignore`, `docs/adr/` (with ADR-0001 through ADR-0006 written up from the original project plan), `docs/phases/` (this log and its README).
- 2026-08-21 — Created AWS account, $100 Free Tier credit active.
- 2026-08-21 — Evaluated IAM Identity Center for personal admin access; rejected after discovering it forces an AWS Organization, which immediately forfeits Free Tier credit. Decided on an IAM user with MFA plus `aws sts get-session-token` for working credentials instead. See ADR-0007 and `docs/runbooks/aws-credentials.md`.
- 2026-08-21 — Created the `gitpulse-admin` IAM user with MFA, an access key, and the `RequireMFAForAllActions` inline policy (ADR-0007's enforcement fix, so the access key genuinely can't be used for real work without MFA). Generated a working session token via `aws sts get-session-token` and confirmed it's live with `aws sts get-caller-identity` — the credentials workflow in `docs/runbooks/aws-credentials.md` is proven end to end, not just documented.
- 2026-08-21 — Refined the runbook twice based on actually using it: closed the MFA-enforcement gap Kim spotted by asking "why do I need an access key if it's never used", then synced the documented profile names (`gitpulse-admin-longlived`, `gitpulse-admin-session`) to what was actually typed, plus added a Finder tip for finding the hidden `~/.aws` folder.
- 2026-08-22 — Documented AWS cost guardrails (two AWS Budgets, a CloudWatch billing alarm, and Cost Explorer + Anomaly Detection tightening) in `docs/runbooks/aws-cost-guardrails.md`, with fill-in-the-blank "Configured:" lines for each control. Documentation is written; actual configuration in the AWS console is still being finished — see Next.
- 2026-08-22 — Removed explicit name from the README's opening line at Kim's request, keeping first-person voice.
- 2026-08-22 — Installed GitHub Spec Kit (`specify init --integration claude`), scaffolding `.claude/skills/speckit-*` and `.specify/`. Drafted and ratified the project constitution (v1.0.0, `.specify/memory/constitution.md`), deriving 5 core principles from the existing ADRs and README. Drafted and self-validated the Phase 1 spec (`specs/001-github-events-ingestion/spec.md`) — reliable ingestion of public activity events — against the spec quality checklist with no `[NEEDS CLARIFICATION]` markers needed, since existing ADRs already resolved the scope-significant questions.
- 2026-08-23 — Confirmed the two AWS Budgets (`gitpulse-free-tier-credit`, `gitpulse-monthly`) and the `gitpulse-billing-alarm` CloudWatch alarm are all created in the AWS console; `docs/runbooks/aws-cost-guardrails.md` now records the actual configured values rather than placeholders.
- 2026-08-23 — Ran `/speckit-plan` for Phase 1: filled in Technical Context (Python 3.12 consumer, local-filesystem raw/quarantine stores in Phase 1 — both resolved as research decisions grounded in existing ADRs rather than new ones), passed the Constitution Check with no violations, and produced `research.md`, `data-model.md`, three interface contracts (NiFi-to-Kafka-to-consumer, raw store, quarantine store), and `quickstart.md` under `specs/001-github-events-ingestion/`.

## Next

- Check back on AWS Cost Explorer once it's populated (~24h after enabling) and tighten Cost Anomaly Detection from its $100/40% default down to ~$10-15 — also flagged in `00_PROJECT_PLAN.md`'s Phase 1 section as an easy-to-forget item.
- Review the Phase 1 plan (`specs/001-github-events-ingestion/plan.md` and its research/data-model/contracts), then run `/speckit-tasks` to turn it into a concrete task list.
- Add branch protection on `main` once Phase 1's first CI check exists to require.

## Decisions / notes

- ADRs were written up in full now rather than deferred, since the reasoning already existed in the original planning document (`00_PROJECT_PLAN.md`, kept outside this repo in the personal job-search tracker) — no reason to retype it later from memory.
- ADR-0007 is a good example of the plan changing on contact with a real constraint: the "more correct" security option (IAM Identity Center) had a cost consequence that outweighed its benefit at this stage, so a documented, deliberate compromise was made instead.
- The runbook only reached its correct, working state through actually using it and hitting a real gap (the MFA-enforcement question) — worth remembering as a pattern: documentation written before first use is a draft, not a fact, until it's been run for real.
