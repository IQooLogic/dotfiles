---
name: plan
description: Writes a phased execution plan (milestones, dependencies, sequence, critical path) to docs/plans/. Use on "write a plan", "roadmap", "phase this out", "lay out milestones". Answers WHEN and in what order — not WHAT (use `architect`) or WHY (use `adr`).
---

Write a time-phased execution plan at `docs/plans/YYYYMMDD_<slug>.md` applying docs-convention. Plans are dependency graphs, not designs.

## Phase 1: Interrogate

Max 3 questions per turn:
1. **Goal** — end state, one sentence, quantifiable if possible.
2. **Milestones** — 3–7 intermediate states, each observable from outside.
3. **Dependencies** — what blocks each milestone? External, internal, knowledge gaps.
4. **Deadline** — hard date, soft target, or none.
5. **Specs** — which `docs/specs/*.md` cover the WHAT? Flag if none exist.

## Phase 2: Write

Front matter per docs-convention. Add `related_specs:` if applicable, `target_completion:` date or `open`. Sections (exact names):
1. **Goal** — one sentence, measurable.
2. **Milestones** — numbered list, each with one-line definition of done.
3. **Dependencies** — list per milestone: `Milestone N: blocked by <item> (<type: external/internal/knowledge>)`.
4. **Sequence** — execution order with sizing per milestone (S ≤1d, M ≤1w, L >1w, XL needs split). Identify critical path.
5. **Risks** — top schedule risks with one-line mitigations.
6. **Out of Scope** — explicitly excluded to prevent drift.

## Phase 3: Supersession + index

If replacing a prior plan: move old to `archive/`, set `status: superseded`. Append to `docs/index.md`, sort by date desc.
