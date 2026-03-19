---
name: docs-convention
description: >
  Enforces a strict documentation directory structure and file naming convention.
  Use this skill automatically whenever creating, naming, moving, or referencing any
  file under a docs/ directory — including plans, specs, ADRs, research docs,
  benchmarks, and notes. Trigger on any request to "write a spec", "create a plan",
  "document this decision", "write up research on", "record a benchmark", or any
  similar documentation task. Also trigger when the user asks where to put a doc,
  how to name a doc, or wants to create or update docs/index.md.
---

# Docs Convention

## Directory Structure

```
docs/
  plans/       # phased build plans, roadmaps
  specs/       # functional and technical specifications
  adrs/        # architecture decision records (project-scoped, irreversible choices)
  research/    # technology comparisons, tradeoff analysis, reusable cross-project reference
  benchmarks/  # performance results, profiling data, comparisons
  notes/       # catch-all for everything else
  archive/     # superseded docs only — move here, never delete
  index.md     # flat index of all active docs with one-line summaries
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

## index.md Format

Flat table, sorted by date descending:

```
| Date       | File                                        | Summary                              |
|------------|---------------------------------------------|--------------------------------------|
| 2026-03-19 | specs/20260319_mantis-fingerprinting.md     | JA4/JA4T TLS fingerprinting spec     |
| 2026-03-19 | research/20260319_json-vs-syslog-framing.md | Why NDJSON over syslog for transport |
```

## Rules

- Apply this convention automatically — no confirmation needed
- ADRs are project-scoped and point-in-time. Research docs are reusable and cross-project
- When superseding a doc: update its status header, move to `archive/`, update `index.md`
- When looking for relevant docs: always read `docs/index.md` first before scanning the tree
- When creating any doc: add a row to `docs/index.md` immediately
