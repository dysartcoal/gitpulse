# Investigations

A directed exercise to answer a specific open question with real evidence — not a quick poke
around (that's `../scratch/`), and not the permanent record of the conclusion either. The
conclusion belongs somewhere tracked and durable: an ADR if it's an architecturally significant
decision, a note in the relevant `research.md`, or a runbook's own fill-in-the-blank "Result:"
line. **This folder is where you show your working — the raw evidence and the reasoning that got
you to the conclusion — not where the conclusion itself lives long-term**, since nothing in here is
committed to git (see `.gitignore`).

The GitHub Events API volume check (`docs/runbooks/github-events-volume-check.md`) is the first
real example: the runbook is the tracked, permanent record of *how* to run the check and *what* was
concluded; the matching folder under here is where the actual captured API responses, computed
diffs, and working notes for a specific run of that check live.

## Folder naming

`YYYY-MM-DD-short-topic/`, e.g. `2026-09-10-github-events-volume-check/`. The date is the date the
investigation was run, not the date it started (rerun the same investigation later — e.g. the
volume check's own "re-check once operational" step — and it gets a new dated folder, not an
overwrite of the old one, so you can compare runs against each other if it's ever useful).

Since these folders aren't tracked in git, this naming discipline is the *only* record of what's
been investigated and when unless it's cross-referenced from a tracked document — so it's worth
being genuinely disciplined about it, not just decorative.

## Shape of a typical investigation folder

- **`notes.md`** — the narrative: what question was being answered, what was tried, what was
  found, and (important) a pointer to exactly where the durable conclusion got written up.
- **`raw/`** — the actual evidence: captured command output, saved API responses, logs.
- Anything else that helped produce the above (a throwaway script, an intermediate file) — no
  fixed schema beyond `notes.md` and `raw/`; add what a given investigation actually needs.

## Extending this

No fixed schema beyond the two items above is enforced or expected — if a future investigation
needs a different shape (e.g. several `raw/` captures from different environments), that's fine;
the folder-per-investigation, dated-name convention is the only part worth keeping consistent.
