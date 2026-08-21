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

## Next

- Set up AWS Budgets and a billing alarm before touching any other AWS service.
- Run `specify init` and the Spec Kit Spec → Plan → Tasks cycle to formally spec Phase 1.
- Add branch protection on `main` once Phase 1's first CI check exists to require.

## Decisions / notes

- ADRs were written up in full now rather than deferred, since the reasoning already existed in the original planning document (`00_PROJECT_PLAN.md`, kept outside this repo in the personal job-search tracker) — no reason to retype it later from memory.
- ADR-0007 is a good example of the plan changing on contact with a real constraint: the "more correct" security option (IAM Identity Center) had a cost consequence that outweighed its benefit at this stage, so a documented, deliberate compromise was made instead.
- The runbook only reached its correct, working state through actually using it and hitting a real gap (the MFA-enforcement question) — worth remembering as a pattern: documentation written before first use is a draft, not a fact, until it's been run for real.
