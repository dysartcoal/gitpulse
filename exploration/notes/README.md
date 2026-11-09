# Notes

Personal reference notes — explanations worked through while building this project that are worth
being able to look back up, but aren't evidence for a repo decision (that's `../investigations/`)
and aren't disposable (that's `../scratch/`). Concept explanations, "how does X actually work"
write-ups, things figured out once during debugging that are worth not re-deriving from scratch
next time. Nothing here is tracked in git (see `.gitignore`) — it's for the author's own benefit,
not the portfolio the rest of this repo is written for (Constitution Principle V), so it's fine
for these to be informal, first-person, and to go stale without being maintained.

**If you're not sure this is the right folder:** does it back a decision someone else would want
to see justified? → `../investigations/`. Is it disposable, no-expectation-of-reuse spike work? →
`../scratch/`. Otherwise, if it's "I want to remember how this works," it belongs here.

## Naming

Loosely `YYYY-MM-DD-short-topic.md` — flat files, not subfolders, since these are typically a
single write-up rather than a bundle of captured output like `../investigations/` entries can be.

## Extending this

Nothing to extend, deliberately — same reasoning as `../scratch/README.md`: if a note starts
wanting more structure, that's a sign it should move somewhere durable instead (an ADR, a runbook,
a doc comment in the code it explains), not a sign this folder needs sub-conventions.
