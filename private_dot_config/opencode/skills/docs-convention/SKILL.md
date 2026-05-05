---
name: docs-convention
description: Use whenever creating, naming, moving, or referencing any file under a docs/ directory — plans, specs, ADRs, research, benchmarks, postmortems, notes. Trigger on "write a spec", "create a plan", "document this decision", "write up research on", "record a benchmark", or questions about where to put a doc or how to name it. Only applies in repos where docs/ already follows the structure below.
---

# Docs Convention

Only applies in repos where `docs/` already exists with this structure. If absent, surface to the user — do not create it.

## Directory structure

```
docs/
  plans/        # phased build plans, roadmaps
  specs/        # functional and technical specifications
  adrs/         # architecture decision records (immutable post-acceptance)
  research/     # technology comparisons, cross-project tradeoff analysis
  benchmarks/   # performance results, profiling data
  postmortems/  # incidents / bad decisions costing >1 day
  notes/        # catch-all: redteam audits, migration notes, advisories
  archive/      # superseded docs — move here, never delete
  index.md      # flat table of all docs sorted by date desc
```

## Naming

`docs/<dir>/YYYYMMDD_<slug>.md` — date is creation date, slug is lowercase-hyphen-separated. Never change dates retroactively.

## Front matter (required on every doc)

```yaml
# Title
status: draft | active | superseded
date: YYYY-MM-DD
```

## Cross-skill front-matter fields (contract — do not rename)

| Field              | Producer skill     | Consumer skill(s)                    | Points to                                  |
|--------------------|--------------------|--------------------------------------|--------------------------------------------|
| `supersedes`       | adr/architect/plan | docs-index, docs-lint                | filename of replaced doc                   |
| `superseded_by`    | adr/architect/plan | docs-index, docs-lint                | filename of replacement (on archived doc)  |
| `related_adrs`     | architect          | docs-lint                            | list of `docs/adrs/*.md`                   |
| `related_research` | architect          | docs-lint                            | list of `docs/research/*.md`               |
| `related_specs`    | plan, migrate      | docs-lint                            | list of `docs/specs/*.md`                  |
| `related_spec`     | migrate            | docs-lint                            | single `docs/specs/*.md`                   |
| `audits`           | redteam            | implementer, telemetry, docs-lint    | the audited `docs/specs/*.md` (REQUIRED)   |
| `commit`           | benchmark          | (provenance)                         | short SHA at run time                      |
| `target`           | benchmark          | (provenance)                         | `<package>:<pattern>`                      |
| `incident_start`   | postmortem         | docs-lint                            | `YYYY-MM-DD HH:MM TZ`                      |
| `incident_end`     | postmortem         | docs-lint                            | `YYYY-MM-DD HH:MM TZ`                      |
| `severity`         | postmortem         | (triage)                             | `SEV-<n>`                                  |
| `target_completion`| plan               | (schedule)                           | date or `open`                             |

## Section name contracts (do not rename)

- Redteam audits: `Critical Vulnerabilities` — each entry: `- [ ] CV-<n>: <title>` with `Trigger:`, `Impact:`, `Detection:` sub-bullets. Parsed by `telemetry` and `implementer` Phase 0 gate.
- Specs: `Domain Boundaries`, `State Management`, `Execution Sequence`, `Error Taxonomy` — parsed by `implementer`.

## index.md format

Flat table sorted by date desc:

```
| Date       | File                              | Summary                          |
|------------|-----------------------------------|----------------------------------|
| YYYY-MM-DD | <subdir>/<file>.md                | <one-line summary>               |
```

Archived docs appear in the same table with `archive/` prefix in the File column.

## Rules

- ADRs are project-scoped, point-in-time, immutable post-acceptance. Research docs are reusable cross-project.
- Postmortems cover any wrong decision costing >1 day — not just production incidents.
- Supersession: update old doc's status to `superseded`, move to `archive/`, update `index.md`. Never delete.
- When creating any doc: add a row to `docs/index.md` immediately.
- When looking for docs: read `docs/index.md` first before scanning the tree.
