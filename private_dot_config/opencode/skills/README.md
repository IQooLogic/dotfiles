# Skills

A collection of opinionated skills that shape how Claude assists on Go-backend, docs, and ops work in this user's environment. Each skill lives in its own directory with a single `SKILL.md`.

## Canonical pipeline

For a multi-week feature build, the skills are designed to compose into a strict pipeline. Each step has an explicit input artifact, output artifact, and gate condition.

```
                                    ┌─ adr ─────────► docs/adrs/        (decisions, immutable)
                                    │
   user intent ──► architect ──► docs/specs/ ──► redteam ──► docs/notes/*-redteam.md
                       ▲              │                          │ (audits: <spec>, CVs)
                       │              ▼                          ▼
                  brutal-advisor   plan ──► docs/plans/      telemetry ──► infra/monitoring/alerts/
                  (challenges                                     │ (one alert per CV)
                   reasoning)                                     ▼
                                                            implementer
                                                                  │ Phase 0: refuses if
                                                                  │ - no audit references spec
                                                                  │ - any CV unchecked
                                                                  ▼
                                                            test ──► verify ──► commit ──► pr
                                                                            (race-clean)
```

**Stage gates:**

| Stage           | Input                            | Output                                    | Gate                                               |
|-----------------|----------------------------------|-------------------------------------------|----------------------------------------------------|
| `architect`     | user requirements                | `docs/specs/YYYYMMDD_<slug>.md`           | all critical gaps closed via interrogation         |
| `redteam`       | a `docs/specs/*.md`              | `docs/notes/*-redteam.md` with `audits:`  | every section populated, CVs in checklist form     |
| `telemetry`     | spec + audit                     | `infra/monitoring/alerts/<slug>.yml`      | one alert per CV, `promtool` or YAML check passes  |
| `implementer`   | spec + audit (CVs ticked)        | Go code + tests                           | Phase 0 audit gate, then `verify` green            |
| `verify`        | Go module                        | PASS / FAIL                               | mod tidy → build → vet → fix → lint → test -race   |
| `commit`        | staged diff                      | `git commit` command                      | conventional commit format                         |
| `pr`            | feature branch                   | `gh pr create` command                    | branch differs from base; commits coherent         |

## Side branches

Skills that don't sit on the main pipeline but plug into it:

- **`adr`** — record a decision (why X over Y) when chosen during `architect` interrogation. Lives in `docs/adrs/`. Immutable post-acceptance; superseded by archival.
- **`plan`** — sequence multiple specs across time. Produces `docs/plans/`. Cross-references specs via `related_specs:`.
- **`benchmark`** — measure performance, paired `.md`/`.txt` under `docs/benchmarks/`. Used to validate spec performance claims or before/after a `perf` change.
- **`migrate`** — design backward-compatible schema changes. Produces `migrations/*.sql` + a note under `docs/notes/`. Splits breaking changes into multi-deploy sequences.
- **`postmortem`** — blameless incident review. Produces `docs/notes/*-postmortem.md`. Action items feed into future specs/plans.
- **`docs-convention`** — schema for everything under `docs/`. Producer/consumer matrix for cross-skill front-matter fields lives here.
- **`docs-index`** — reconciler. Walks `docs/`, rewrites `docs/index.md` from disk truth.
- **`docs-lint`** — validator. Walks `docs/`, checks cross-references and front-matter consistency without rewriting anything.

## Gates (review skills)

Two distinct review skills, intentionally separated:

- **`boundary-cop`** — narrow, mechanical: hexagonal-architecture leaks + CLAUDE.md "Never" rule violations. Use before commit.
- **`review`** — broad, judgment-based: correctness, naming, tests, observability, security smells. Use before merge.

For challenging *reasoning* (not code), use **`brutal-advisor`** (conversational) — distinct from `redteam`, which audits *specs*.

## Cross-skill contracts

Two contracts tie the pipeline together. Both are documented in `docs-convention/SKILL.md`:

1. **Front-matter fields** — `audits:`, `related_adrs`, `related_specs`, `supersedes`, etc. The producer skill writes the field; the consumer skill reads it to discover related artifacts. See `docs-convention` "Cross-Skill Fields" table for the full map.
2. **Section names** — downstream parsing depends on exact section titles. Most load-bearing: `Critical Vulnerabilities` in redteam audits (parsed by `telemetry` and `implementer`), and `Domain Boundaries`/`State Management`/`Execution Sequence`/`Error Taxonomy` in specs (parsed by `implementer`).

Renaming a field or section without updating every producer and consumer breaks the pipeline silently. `docs-lint` exists to detect these breakages.

## Conventions inherited from `~/.claude/CLAUDE.md`

The skills assume the user's global CLAUDE.md is in scope. Key bindings:

- Verification order: `go mod tidy` → `go build` → `go vet` → `go fix` → `golangci-lint` → `go test -race`.
- `log/slog` only in production; no `fmt.Println` / `log.Printf`.
- Errors wrapped with `fmt.Errorf("component: action: %w", err)`.
- No attribution lines ("Generated with Claude Code", etc.) in commits, PRs, or generated content.
- Docs convention applies only where `docs/` already exists with the structure in `docs-convention/SKILL.md`.

Skills do not restate these rules — they reference the CLAUDE.md sections instead. To change a rule, change CLAUDE.md, not the skills.
