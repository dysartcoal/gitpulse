# Scratch

Quick, low-ceremony exploration and manual testing with no expectation of lasting value: trying
whether a NiFi processor configuration behaves as expected before it goes into the exported flow,
manually poking the consumer with a hand-crafted event to see how it handles an edge case, a
spike checking whether a library does what its docs claim before committing to it in `plan.md`,
or ad hoc debug output captured while chasing down a bug. This is genuinely disposable — nothing
here is tracked in git (see `.gitignore`), and it's fine to delete any of it at any time without
asking.

**If something in here turns out to actually matter, promote it** — move a real finding into
`../investigations/` if it answers a real open question worth a durable write-up, or straight into
real implementation (`src/`, `tests/`, `nifi/flow/`) if it's ready to become the real thing. Don't
let scratch work quietly become load-bearing by staying here.

## Naming

Loosely `YYYY-MM-DD-short-topic/`, the same convention as `../investigations/`, purely so an `ls`
of this folder stays navigable over time — not enforced, since low ceremony is the whole point.

## Extending this

Nothing to extend, deliberately — if scratch work starts wanting more structure than "a dated
folder with whatever's useful in it," that's usually a sign it's actually an investigation (see
`../investigations/README.md`) or ready to become real code, not a sign this folder needs its own
sub-conventions.
