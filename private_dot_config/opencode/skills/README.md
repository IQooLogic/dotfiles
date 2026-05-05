# Skills

Opinionated skills for Go-backend, docs, and ops work. Each skill lives in its own directory with a single `SKILL.md`.

## Canonical pipeline

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
                                                                   │ Phase 1: BLOCKED if spec gap
                                                                   │ (user runs architect → amend)
                                                                   ▼
                                                             test ──► verify ──► commit ──► pr
                                                                             (race-clean)
```

**Stage gates:**

| Stage         | Input              | Output                                    | Gate                                                    |
|---------------|--------------------|-------------------------------------------|---------------------------------------------------------|
| `architect`   | user requirements  | `docs/specs/YYYYMMDD_<slug>.md`           | all critical gaps closed via interrogation              |
| `redteam`     | a `docs/specs/*.md`| `docs/notes/*-redteam.md` with `audits:`  | every section populated, CVs in checklist form          |
| `telemetry`   | spec + audit       | `infra/monitoring/alerts/<slug>.yml`      | one alert per CV, YAML validation passes                |
| `implementer` | spec + audit (CVs ticked)| Go code + tests                      | Phase 0 audit gate; Phase 1 contracts extractable; `verify` green |
| `verify`      | Go module          | PASS / FAIL                               | mod tidy → build → vet → fix → golangci-lint → test -race|
| `commit`      | staged diff        | `git commit` command                      | conventional commit format                              |
| `pr`          | feature branch     | `gh pr create` command                    | branch differs from base; commits coherent              |

## Side branches

- **`adr`** — record a decision (why X over Y). Immutable post-acceptance.
- **`plan`** — sequence multiple specs across time. Cross-references specs via `related_specs:`.
- **`benchmark`** — measure performance, paired `.md`/`.txt` under `docs/benchmarks/`.
- **`migrate`** — backward-compatible schema changes. Splits breaking changes across deploys.
- **`postmortem`** — blameless incident review. Action items feed into future specs/plans.
- **`docs-convention`** — single source of truth for file naming, front matter, cross-skill field contracts.
- **`docs-index`** — reconciler. Rewrites `docs/index.md` from disk truth.
- **`docs-lint`** — validator. Checks cross-references and front-matter consistency.

## Review skills

- **`boundary-cop`** — narrow: hexagonal leaks + CLAUDE.md Never-rule violations. Use before commit.
- **`review`** — broad: correctness, naming, tests, observability, security. Use before merge.
- **`brutal-advisor`** — conversational: challenges reasoning, not code.

## Cross-skill contracts

Two contracts tie the pipeline together (defined in `docs-convention/SKILL.md`):

1. **Front-matter fields** — `audits:`, `related_adrs`, `related_specs`, `supersedes`, etc. Producer skill writes; consumer reads. Do not rename without updating every producer/consumer.
2. **Section names** — downstream parsing depends on exact titles: `Critical Vulnerabilities` (parsed by `telemetry`, `implementer`), `Domain Boundaries`/`State Management`/`Execution Sequence`/`Error Taxonomy` (parsed by `implementer`).

## Conventions inherited from `~/.claude/CLAUDE.md`

Skills reference CLAUDE.md, do not restate. Key bindings:
- Verification order: `go mod tidy` → `go build` → `go vet` → `go fix` → `golangci-lint` → `go test -race`
- `log/slog` only in production; no `fmt.Println`/`log.Printf`
- Errors wrapped with `fmt.Errorf("component: action: %w", err)`
- No attribution lines in commits, PRs, or generated content
- Docs convention applies only where `docs/` already exists with this structure
