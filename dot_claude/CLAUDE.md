# Global Claude Directives

## General

- Never include "Generated with Claude Code" or similar attribution in commit messages, PR descriptions, or any generated content
- Prefer explicit over clever — code should be readable without context
- Fail loudly: never suppress errors silently; log or return them, always
- Do not make autonomous decisions in stop hooks or automated phases — report findings only, never revert, modify, or act unilaterally
- When referencing project docs, read `docs/index.md` first to avoid scanning the full tree
- When a task is ambiguous, ask once with a concrete proposal rather than proceeding on assumption

## Never

- Silent error suppression (`_ = err`, `err != nil { return }` with no log)
- Attribution lines in any generated output
- Autonomous action in hooks or post-phase gates — report only
- Retroactive renaming or re-dating of docs
- Deleting docs — archive them instead
- Generating `docs/index.md` or applying the docs convention in repos that do not already use the `docs/` structure below

## Go

- See `code_style.md` for full conventions — treat it as binding
- `go test -race` requires `CGO_ENABLED=1`
- Use `log/slog` for structured logging — no `fmt.Println` or bare `log.Printf` in production code
- Prefer stdlib; pull in a dependency only when the stdlib alternative is genuinely insufficient
- Table-driven tests with `t.Run`; hand-written mocks, no mock-gen frameworks
- All errors wrapped with context: `fmt.Errorf("component: action: %w", err)`
- `golangci-lint` must pass before any phase gate closes
- Verification order: `go mod tidy` → `go build ./...` → `go vet ./...` → `go fix ./...` → `golangci-lint run` → `go test -race ./...`

## Docs Convention

### Structure

```
docs/
  plans/       # phased build plans, roadmaps
  specs/       # functional and technical specifications
  adrs/        # architecture decision records (project-scoped, point-in-time)
  research/    # technology comparisons, tradeoffs, reusable cross-project reference
  benchmarks/  # performance results, profiling data, comparisons
  notes/       # catch-all for everything else
  archive/     # superseded docs — move here, never delete
  index.md     # flat index of all docs with one-line summaries
```

### Naming

```
docs/<dir>/YYYYMMDD_<slug>.md
```

- Date = creation date, never changed retroactively
- Slug: lowercase, hyphen-separated, no spaces

Examples:

```
docs/specs/20260319_mantis-fingerprinting.md
docs/adrs/20260319_logdrop-transport-format.md
docs/research/20260319_json-vs-syslog-framing.md
docs/benchmarks/20260319_archibald-ingest-throughput.md
```

### Front-matter

Every doc must open with:

```
# Title
status: draft | active | superseded
date: YYYY-MM-DD
supersedes: <filename>  # if applicable
```

### index.md

Maintain as a flat list sorted by date descending:

```
| Date       | File                                        | Summary                              |
|------------|---------------------------------------------|--------------------------------------|
| 2026-03-19 | specs/20260319_mantis-fingerprinting.md     | JA4/JA4T TLS fingerprinting spec     |
| 2026-03-19 | research/20260319_json-vs-syslog-framing.md | Why NDJSON over syslog for transport |
```

Update `index.md` every time a doc is created, renamed, or archived.

### Rules

- Apply this convention automatically when creating any plan, spec, ADR, research doc, or benchmark — no confirmation needed
- Only apply this convention in repos where `docs/` already follows this structure
- ADRs are project-specific and point-in-time; research docs are reusable and cross-project
- When a decision is superseded: move old doc to `archive/`, update its status to `superseded`, update `index.md`

## Commit Convention

Format: `<type>(<optional scope>): <short summary>`

Types: `feat` `fix` `docs` `refactor` `test` `chore` `ci` `perf` `style` `build`

Scope: short area identifier — `api`, `worker`, `auth`, `pipeline`, `docker`, etc.

Rules: lowercase imperative summary, no period, ≤72 chars total, header only.

Examples:

- `feat(api): add prometheus metrics endpoint`
- `fix(worker): prevent duplicate alert emails during cooldown`
- `refactor(pipeline): extract prefilter into separate package`
