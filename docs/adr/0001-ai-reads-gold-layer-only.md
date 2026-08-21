# 0001 — AI interface reads from the gold layer only

**Status:** Accepted
**Date:** 2026-08-20

## Context

The platform has three layers: raw (unvetted, may carry quality or sensitivity issues), curated (an internal engineering working layer), and gold (the governed, documented, quality-checked contract layer). Phase 3 adds an AI-facing interface over this data. A decision is needed about which layer(s) it may read from.

## Decision

Any AI-facing or external-facing interface reads from the gold layer only. Internal ML/feature pipelines that need curated-layer richness are a separate, internally-scoped exception — not the general rule.

## Consequences

External and AI consumers only ever see governed, quality-checked data, which is the right default for privacy, security and trust. This does add a constraint during development — the AI interface can't be pointed at whatever's convenient — but that constraint is the point, and Phase 3 includes an automated test asserting the AI service's database role has no grant on raw or curated tables, so the boundary is enforced, not just documented.
