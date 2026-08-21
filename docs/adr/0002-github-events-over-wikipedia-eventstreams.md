# 0002 — GitHub Events over Wikipedia EventStreams for the streaming source

**Status:** Accepted
**Date:** 2026-08-20

## Context

The project needs a public, real-world streaming data source. Two candidates were considered: Wikipedia EventStreams (true server-sent-event push, higher volume, no domain relevance to target roles) and the GitHub Events API (poll-based, with ETag caching and rate limits, lower volume, directly relevant domain).

## Decision

Use the GitHub Events API. Rate-limited polling integration is a very common real-world pattern in its own right, and the domain — software engineering activity — is more relevant to target-role interviews than Wikipedia edit content would be.

## Consequences

This project will not cover long-lived push-stream consumer patterns (backpressure, persistent-connection handling) — that gap is accepted knowingly, and worth a short local spike with Wikipedia's feed later if it ever matters for a specific application. In exchange, the ingestion pattern built here (polling, ETag caching, pagination, rate-limit handling) is one of the most transferable real-world integration patterns in data engineering.
