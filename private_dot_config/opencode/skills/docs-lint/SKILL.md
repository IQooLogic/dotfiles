---
name: docs-lint
description: Validates cross-references and front-matter consistency across the docs/ tree. Use on "lint the docs", "check doc references", "find broken doc cross-refs", or before any doc-heavy PR. Verifies that supersedes/related_adrs/related_specs/audits links resolve, CV checklists parse, postmortem timestamps order. Reports only — for rewrite use `docs-index`.
---

Validate cross-references and front-matter consistency. Reports only. Use `docs-index` to rewrite the index.

## Phase 1: Scan

Walk `docs/` recursively (including `archive/`). For each `*.md` (skip `index.md`), parse front matter into key→value(s). Multi-value fields accept YAML lists or comma-separated single lines.

If `docs/` missing: `SKIP: no docs/ tree at <cwd>`. Halt.

## Phase 2: Validate references

For each file:
1. `supersedes:` → resolves to existing file under `docs/`. Target's `status:` should be `superseded` in `archive/`.
2. `superseded_by:` → resolves to existing file. Current file must have `status: superseded`.
3. `related_adrs:` → every entry resolves to `docs/adrs/*.md`.
4. `related_research:` → every entry resolves to `docs/research/*.md`.
5. `related_specs:` / `related_spec:` → every entry resolves to `docs/specs/*.md`.
6. `audits:` (REQUIRED on redteam audits) → resolves to `docs/specs/*.md`.

Bare filename references (e.g. `20260319_foo.md`) resolve under the expected subdirectory for that field.

## Phase 3: Validate front matter

1. Every file: `# Title` heading, `status:`, `date:` (YYYY-MM-DD) present.
2. `status: superseded` → must be under `archive/`.
3. Under `archive/` → must have `status: superseded`.
4. Postmortems: `incident_start:` and `incident_end:` parse as timestamps, `incident_end >= incident_start`.

## Phase 4: Validate section contracts

For redteam audits (files with `audits:` field):
1. Section `Critical Vulnerabilities` exists.
2. Each CV entry: `- [ ] CV-<n>: <title>` with `Trigger:`, `Impact:`, `Detection:` sub-bullets.
3. Report missing sub-bullets — `telemetry` will fail on them.

## Phase 5: Report

```
DOCS-LINT
- <N> files scanned
- <K> violations:

[broken-ref]
- <path>: <field> → <target>: not found
[wrong-status]
- <path>: in archive/ but status != superseded
[malformed]
- <path>: <description>
[cv-format]
- <path>: CV-<n> missing <sub-bullet>
```

If zero violations: `DOCS-LINT - <N> files scanned - 0 violations`

No files modified.
