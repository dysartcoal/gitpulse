# 0007 — IAM user with MFA and STS session tokens, not IAM Identity Center, for personal admin access

**Status:** Accepted
**Date:** 2026-08-21

## Context

ADR-0004 commits this project to no long-lived AWS credentials for GitHub Actions. The same principle was considered for Kim's own interactive/admin access: rather than a classic IAM user with a permanent access key, use AWS IAM Identity Center, which AWS's current documentation recommends even for standalone accounts, backed by temporary, short-lived credentials instead of long-term ones.

On attempting to enable IAM Identity Center, the AWS console surfaced a consequence that isn't prominently documented: enabling it requires creating an AWS Organization (the "organization instance" is the only instance type that supports permission sets and AWS account access at all), and creating an Organization **immediately and irreversibly forfeits the account's Free Tier credit balance**, converting the account to standard pay-as-you-go billing with no confirmation step calling this out. This is confirmed, reported behavior, not a one-off glitch.

The alternative "account instance" of IAM Identity Center avoids creating an Organization, but explicitly does not support permission sets or AWS account access — it's scoped to SSO for a small set of AWS-managed applications only. It cannot serve as an admin-access mechanism for this project, Organization or not.

## Decision

Use a plain IAM user for administrative access, not IAM Identity Center:

- One IAM user (`gitpulse-admin`) with the AWS-managed `AdministratorAccess` policy, console access via a strong unique password, and **mandatory MFA** (virtual authenticator app) on the user itself.
- An access key exists for this user for CLI/Terraform access. Its only legitimate use is to authenticate the single `aws sts get-session-token` call (MFA-gated) that produces short-lived temporary credentials (up to 36 hours) — those temporary credentials, not the key, are what Terraform and the AWS CLI actually use day to day. See `docs/runbooks/aws-credentials.md` for the exact commands.
- **This is enforced, not just a habit to remember.** AWS's own documentation is explicit that MFA cannot be required on the `GetSessionToken` call itself (you can't require MFA to go and get MFA-backed credentials) — some standing credential has to authenticate that first call, whether via IAM Identity Center's federated login or, here, this access key. Left at that, though, the key would still work directly for *any* admin action with no MFA check at all, since `AdministratorAccess` carries no such condition — the "only ever used to bootstrap a session" story would just be a discipline, not a guarantee. To close that gap, a second inline policy (`RequireMFAForAllActions`) is attached to the same user: an explicit `Deny` on everything except a short list of self-service actions (viewing account info, managing the user's own MFA device, `sts:GetSessionToken`) whenever `aws:MultiFactorAuthPresent` is false. Since an explicit `Deny` always overrides an `Allow` in IAM's evaluation logic, this makes the raw key genuinely unusable for real work — the only path to doing anything is through a session token obtained with MFA. The policy JSON and attachment steps are in `docs/runbooks/aws-credentials.md`.
- The long-lived key itself lives in a password manager, never in this repository.
- Root user protections from account setup (MFA, no root access keys) remain unchanged and root continues to be used only for the small set of tasks that genuinely require it.

## Consequences

The account's $100 Free Tier credit stays intact — the entire reason this path was chosen over IAM Identity Center. Day-to-day AWS work still happens under credentials that expire and must be actively refreshed (a meaningful improvement over a static key used directly), even though this falls short of Identity Center's fully federated, no-standing-credential model.

This is a deliberate, documented compromise: a security best practice (IAM Identity Center) was evaluated first, found to carry a real and immediate cost consequence specific to a self-funded personal account, and traded off against a cheaper alternative that still meaningfully reduces exposure versus the naive approach (a static key used everywhere, or working as root). If this project or a future one has a real budget, or moves past the point where the Free Tier credit matters, revisiting IAM Identity Center is straightforward — nothing here is a dead end, just a scoped, budget-driven decision for this phase.

An earlier version of this ADR described the access key as "not used directly for day-to-day work" without the enforcing policy in place — at that point this was aspirational, since nothing technically stopped the key being used directly with full admin rights and no MFA. That gap was identified and closed by adding the `RequireMFAForAllActions` policy above, so the ADR now describes an enforced control rather than an intended-but-unverified one.

This ADR is specific to Kim's own human/interactive access. It does not change ADR-0004's treatment of GitHub Actions, which continues to authenticate via OIDC with no stored keys at all — a separate actor in the system, held to a stricter standard than personal interactive access.
