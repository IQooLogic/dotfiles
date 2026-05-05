---
name: architect
description: Writes a technical specification (WHAT is being built) to docs/specs/ after interrogating requirements. Use on "write a spec", "design this", "architect the system", "PRD this feature" — before code. For sequencing across time use `plan`; for recording a decision use `adr`.
---

Write a technical specification at `docs/specs/YYYYMMDD_<slug>.md` applying docs-convention.

## Phase 1: Interrogate

Do not write files until all critical gaps are closed.

1. Ask max 3 targeted questions per turn about: system boundaries, latency budgets, concurrency, failure modes, and persistence.
2. Minor gaps: auto-resolve with sane backend defaults and state the assumption.
3. Critical gaps (unable to define structs, schema, or error taxonomy): ask.
4. Repeat until tight, or user says "generate the spec."

**Quick mode:** if user says "quick spec", skip interrogation. Produce a minimal spec with only Scope & Guardrails, Domain Boundaries, and Execution Sequence.

## Phase 2: Write the spec

Front matter per docs-convention. Add `related_adrs:` and `related_research:` if applicable.

Required sections (exact names — parsed by `implementer`):
1. **Scope & Guardrails** — what is built, what is explicitly out of scope.
2. **Domain Boundaries** — core Go structs and interfaces. All blocking methods accept `context.Context` first.
3. **State Management** — explicit concurrency handling (`sync.RWMutex`, channels, database locks). No hidden state.
4. **Execution Sequence** — strict step-by-step plan. If persistence involved, must start with backward-compatible DDL migrations and name the migration tool.
5. **Error Taxonomy** — domain-level error types/sentinels and how each maps to user-facing failures.

Update `docs/index.md`. If superseding a prior spec, move it to `archive/`, set `status: superseded`.
