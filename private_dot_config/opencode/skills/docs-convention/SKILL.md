---
name: docs-convention
description: Use whenever creating, naming, moving, or referencing any file under a docs/ directory — plans, specs, ADRs, research, benchmarks, postmortems, notes. Trigger on "write a spec", "create a plan", "document this decision", "write up research on", "record a benchmark", or questions about where to put a doc or how to name it. Only applies in repos where docs/ already follows the structure below.
---

# Docs Convention

> **Guard:** This convention only applies in repos where `docs/` already exists with this structure. If a repo has no `docs/` tree, do **not** create one to satisfy a doc request — surface the absence to the user and let them decide.

## Directory Structure

```
docs/
  plans/        # phased build plans, roadmaps
  specs/        # functional and technical specifications
  adrs/         # architecture decision records (project-scoped, irreversible choices)
  research/     # technology comparisons, tradeoff analysis, reusable cross-project reference
  benchmarks/   # performance results, profiling data, comparisons
  postmortems/  # wrong decisions, bad assumptions, wasted effort — anything costing >1 day
  notes/        # catch-all for everything else
  archive/      # superseded docs only — move here, never delete
  index.md      # flat index of all active docs with one-line summaries
```

## Naming

```
docs/<dir>/YYYYMMDD_<slug>.md
```

- Date = creation date, never changed retroactively
- Slug: lowercase, hyphen-separated, no spaces

**Examples:**
```
docs/specs/20260319_mantis-fingerprinting.md
docs/adrs/20260319_logdrop-transport-format.md
docs/research/20260319_json-vs-syslog-framing.md
docs/benchmarks/20260319_archibald-ingest-throughput.md
```

## Required Front Matter

Every doc must open with:

```
# Title

status: draft | active | superseded
date: YYYY-MM-DD
supersedes: <filename>  # only if replacing an older doc
```

## Cross-Skill Fields

Optional front-matter fields produced by some skills and consumed by others. The producer writes the field on creation; the consumer reads it to discover related artifacts. **Field names are a contract — do not rename without updating every producer and consumer.**

| Field              | Doc type           | Producer skill | Consumer skill(s)             | Points to                                    |
|--------------------|--------------------|----------------|-------------------------------|----------------------------------------------|
| `supersedes`       | any                | adr/architect/plan | docs-index, docs-lint     | filename of older doc being replaced         |
| `superseded_by`    | archived doc       | adr/architect/plan | docs-index, docs-lint     | filename of replacement                      |
| `related_adrs`     | spec               | architect      | docs-lint                     | list of `docs/adrs/*.md`                     |
| `related_research` | spec               | architect      | docs-lint                     | list of `docs/research/*.md`                 |
| `related_specs`    | plan, migration note | plan, migrate | docs-lint                    | list of `docs/specs/*.md`                    |
| `related_spec`     | migration note     | migrate        | docs-lint                     | single `docs/specs/*.md`                     |
| `audits`           | redteam audit      | redteam        | implementer, telemetry, docs-lint | the audited `docs/specs/*.md` (REQUIRED)  |
| `commit`           | benchmark          | benchmark      | (none — provenance)           | short SHA at run time                        |
| `target`           | benchmark          | benchmark      | (none — provenance)           | `<package>:<pattern>`                        |
| `incident_start`   | postmortem         | postmortem     | docs-lint                     | timestamp `YYYY-MM-DD HH:MM TZ`              |
| `incident_end`     | postmortem         | postmortem     | docs-lint                     | timestamp `YYYY-MM-DD HH:MM TZ`              |
| `severity`         | postmortem         | postmortem     | (none — triage)               | `SEV-<n>`                                    |
| `target_completion`| plan               | plan           | (none — schedule)             | date or `open`                               |
| `project`          | postmortem (template) | postmortem  | (none — scoping)              | project name                                 |
| `audit_status`     | telemetry alerts   | telemetry      | (none — provenance)           | `missing` if `--no-audit` override used      |

**Section names are also a contract.** Downstream skills parse named sections by exact title. The most load-bearing:

- redteam audits → section `Critical Vulnerabilities` is parsed by `telemetry` (alert generation) and `implementer` (Phase 0 gate). Each entry follows the `- [ ] CV-<n>: <title>` checklist format with `Trigger:`, `Impact:`, `Detection:` sub-bullets.
- specs → sections `Domain Boundaries`, `State Management`, `Execution Sequence`, `Error Taxonomy` are parsed by `implementer` (contract extraction) and `telemetry` (additional failure modes).

## index.md Format

Flat table, sorted by date descending:

```
| Date       | File                                        | Summary                              |
|------------|---------------------------------------------|--------------------------------------|
| 2026-03-19 | specs/20260319_mantis-fingerprinting.md     | JA4/JA4T TLS fingerprinting spec     |
| 2026-03-19 | research/20260319_json-vs-syslog-framing.md | Why NDJSON over syslog for transport |
```

## Postmortem Template

Every file under `docs/postmortems/` must use this structure — no exceptions:

```markdown
# Title

status: active
date: YYYY-MM-DD
project: <project>

## What happened

## Why it happened
<!-- Root cause only. Not symptoms, not timeline. One or two sentences. -->

## Cost
<!-- Time lost, rework required, downstream impact. Be specific. -->

## What changes as a result
<!-- Concrete actions: code, process, tooling. If nothing changes, don't write the doc. -->

## How to detect this earlier next time
<!-- The detection heuristic. This is the most important field. -->
```

The last field is mandatory. A postmortem without a detection heuristic is a confession, not a learning.

## Rules

- Apply this convention automatically — no confirmation needed
- ADRs are project-scoped and point-in-time. Research docs are reusable and cross-project
- Postmortems cover any wrong decision or bad assumption costing more than one day — not just production incidents
- When superseding a doc: update its status header, move to `archive/`, update `index.md`
- When looking for relevant docs: always read `docs/index.md` first before scanning the tree
- When creating any doc: add a row to `docs/index.md` immediately