---
name: adr
description: Records point-in-time architectural decisions (why X over Y) to docs/adrs/. Use on "write an ADR", "record this decision", "document the choice". Immutable post-acceptance — supersession is by archival, not edit. For "what we're building" use `architect`; for "when, in what order" use `plan`.
---

Record a point-in-time architectural decision at `docs/adrs/YYYYMMDD_<slug>.md` applying docs-convention. ADRs are never edited after acceptance — they are superseded.

## Phase 1: Interrogate

Ask max 3 questions per turn:
1. What decision is being recorded? (one sentence)
2. What options were considered? (at least 2)
3. What forces drove it? (constraints, deadlines, commitments)
4. Does it supersede a prior ADR?

## Phase 2: Write

Front matter per docs-convention. Sections (exact names):
1. **Context** — situation and forces at play
2. **Decision** — what was decided, one paragraph
3. **Options Considered** — at least 2, each with pros/cons
4. **Consequences** — what becomes easier, harder, or closed off

## Phase 3: Supersession + index

If superseding another ADR:
1. Move old ADR to `docs/archive/`, set `status: superseded`, add `superseded_by: docs/adrs/<new>.md`.
2. Update `docs/index.md`: remove old row, add new row, add archived row.

Otherwise, just append to `docs/index.md`. Sort by date desc.
