# 0003 — Local-first for Kubernetes and compute; cloud spend is deliberate and time-boxed

**Status:** Accepted
**Date:** 2026-08-20

## Context

AWS's new-account offer at the time of writing is $200 in credits over 6 months, not unlimited free usage, and a running EKS control plane alone costs roughly $73/month. This project is self-funded during a period of job searching, so cost discipline matters from day one.

## Decision

Kubernetes work happens on `kind` locally by default. Real cloud Kubernetes (or a cheap single-node alternative) is used only for short, deliberate, torn-down-afterward bursts. Compute elsewhere prefers serverless/pay-per-use (Glue, Athena, Lambda, Fargate) over anything that bills by the hour regardless of use.

## Consequences

Almost all development and iteration is free. The trade-off is that "real cloud Kubernetes" experience is deliberately time-boxed rather than continuous — accepted, since a short, well-documented burst (see Phase 4) still produces genuine hands-on evidence without an open-ended bill. AWS Budgets and a billing alarm are configured before any AWS service is touched, as a hard backstop rather than relying on discipline alone.
