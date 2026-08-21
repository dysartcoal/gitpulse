# Runbook — getting AWS credentials for local CLI/Terraform work

Context and reasoning: see [ADR-0007](../adr/0007-iam-user-with-mfa-over-identity-center.md). The `gitpulse-admin` IAM user's access key exists only to bootstrap a session token via MFA — and per step 6 below, that's enforced by policy, not just a habit to remember.

## One-time setup (do this once, before any of this project's Terraform/CLI work)

1. In the AWS Console → IAM → Users, create a user named `gitpulse-admin`.
2. Attach the AWS-managed `AdministratorAccess` policy directly (or via an `Administrators` group).
3. Enable console access with a strong, unique password.
4. Add an MFA device to this user (Security credentials tab → Assign MFA device → virtual authenticator app such as Google Authenticator, 1Password, or Authy). Note the device's ARN — it looks like `arn:aws:iam::<account-id>:mfa/gitpulse-admin`.
5. Create an access key for this user (Security credentials tab → Create access key → "Command Line Interface (CLI)" use case). Store the Access Key ID and Secret Access Key in a password manager.
6. **Attach the MFA-enforcement policy** — this is what makes step 5's key actually safe to have. IAM → Users → gitpulse-admin → Add permissions → Create inline policy → JSON tab → paste the policy below → name it `RequireMFAForAllActions`:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Sid": "AllowViewAccountInfo",
         "Effect": "Allow",
         "Action": ["iam:GetAccountSummary", "iam:ListVirtualMFADevices"],
         "Resource": "*"
       },
       {
         "Sid": "AllowManageOwnUserMFA",
         "Effect": "Allow",
         "Action": ["iam:DeactivateMFADevice", "iam:EnableMFADevice", "iam:GetUser", "iam:ListMFADevices", "iam:ResyncMFADevice"],
         "Resource": "arn:aws:iam::*:user/${aws:username}"
       },
       {
         "Sid": "AllowGetSessionTokenWithMFA",
         "Effect": "Allow",
         "Action": "sts:GetSessionToken",
         "Resource": "*"
       },
       {
         "Sid": "DenyAllExceptListedIfNoMFA",
         "Effect": "Deny",
         "NotAction": ["iam:GetAccountSummary", "iam:ListVirtualMFADevices", "iam:DeactivateMFADevice", "iam:EnableMFADevice", "iam:GetUser", "iam:ListMFADevices", "iam:ResyncMFADevice", "sts:GetSessionToken"],
         "Resource": "*",
         "Condition": { "BoolIfExists": { "aws:MultiFactorAuthPresent": "false" } }
       }
     ]
   }
   ```
   With this attached alongside `AdministratorAccess`, the explicit `Deny` wins whenever MFA isn't present on the request — the raw access key stops working for anything except the handful of self-service actions listed, including the `GetSessionToken` call itself. Real work is only possible through an MFA-backed session token from here on.
7. Configure a bootstrap-only AWS CLI profile with the access key:
   ```
   aws configure --profile gitpulse-longlived
   ```
   (enter the access key, secret key, default region `eu-west-2`, output format `json`)

## Every working session (credentials expire — repeat this when they do)

1. Get an MFA code from your authenticator app for the `gitpulse-admin` device.
2. Mint a session token (36 hours is the maximum for a plain `get-session-token` call with no role involved):
   ```
   aws sts get-session-token \
     --profile gitpulse-longlived \
     --serial-number arn:aws:iam::<account-id>:mfa/gitpulse-admin \
     --token-code <code-from-authenticator-app> \
     --duration-seconds 129600
   ```
3. This returns an `AccessKeyId`, `SecretAccessKey`, and `SessionToken`. Put these into a separate working profile, e.g. by editing `~/.aws/credentials`:
   ```
   [gitpulse]
   aws_access_key_id = <from step 2>
   aws_secret_access_key = <from step 2>
   aws_session_token = <from step 2>
   ```
4. Use this profile for everything — AWS CLI (`--profile gitpulse`) and Terraform (`AWS_PROFILE=gitpulse terraform plan`). When it expires (after up to 36 hours), repeat steps 1–3.

## What this is not

This is not AWS Secrets Manager, and doesn't replace it. This runbook is about *Kim's own* human credentials for driving AWS from her laptop. Secrets Manager (from Phase 4 onward, per ADR-0004) is about credentials that a *running service* needs at its own runtime — a different problem, addressed separately.
