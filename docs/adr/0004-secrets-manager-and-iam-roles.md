# 0004 — Credentials via Secrets Manager + IAM roles, never long-lived AWS access keys

**Status:** Accepted
**Date:** 2026-08-20

## Context

The platform needs to authenticate to AWS from GitHub Actions, and needs runtime credentials for services it operates (API tokens, DB credentials). Long-lived AWS access keys stored as repo secrets are a common but avoidable risk, especially in a public repository.

## Decision

GitHub Actions authenticates to AWS via OIDC federation, assuming a scoped IAM role per workflow — no stored access keys. Any secrets the platform needs at runtime live in AWS Secrets Manager, retrieved by the service's own IAM role, not environment variables or repo secrets where avoidable.

## Consequences

No long-lived AWS credentials exist anywhere in this repository or its CI configuration, which matters more than usual given the repo is public. This is current best practice and one of the more specific, concrete interview talking points this project produces — it demonstrates the practice rather than just naming it.
