# Exploration

Output from exploratory work — investigations that gather evidence for a real decision, and
low-ceremony scratch work — that doesn't belong in the shipped project (`src/`, `infra/`, `nifi/`),
the formal test suite (`tests/`), or the pipeline's own runtime output (`data/`). None of the
content under this folder is tracked in git except the `README.md` guide files themselves — see
`.gitignore`. This is deliberate: exploration output can be large (raw API captures), messy, or
simply not worth a permanent place in git history, but the *conventions* for organising it are
worth keeping and are exactly what these READMEs are for.

## The two subfolders, and how to pick between them

- **`investigations/`** — a directed exercise to answer a specific open question with real
  evidence, in support of a decision that gets written up somewhere durable (an ADR, a
  `research.md` note, a runbook's "Result:" line). The GitHub Events API volume check is the first
  example of this.
- **`scratch/`** — quick, disposable exploration and manual testing with no expectation of lasting
  value: does this NiFi processor config work, does the consumer handle this edge case if I poke
  it by hand, is this library worth using. Can be wiped at any time.

**If you're not sure which one a piece of work belongs in, ask: "will I want to point back at this
later to justify a decision?"** Yes → `investigations/`. No → `scratch/`. See each subfolder's own
`README.md` for the specific conventions.

## Extending this structure

If a third category emerges that genuinely doesn't fit either of the above (this hasn't happened
yet), add a new top-level subfolder here rather than stretching `investigations/` or `scratch/` to
cover it — give it its own `README.md` explaining its purpose the same way this one and the two
below do, and add a matching block to `.gitignore` following the same shape as the existing two
(`/exploration/<new-folder>/*` plus `!/exploration/<new-folder>/README.md`).
