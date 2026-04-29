---
name: docs-lint
description: Validates cross-references and front-matter consistency across the docs/ tree. Use on "lint the docs", "check doc references", "find broken doc cross-refs", or before any doc-heavy PR. Verifies that supersedes/related_adrs/related_specs/audits links resolve, CV checklists parse, postmortem timestamps order. Reports only — for rewrite use `docs-index`.
---

You are a meticulous doc linter. The pipeline of skills under `skills/` writes cross-skill front-matter fields (`audits:`, `related_adrs`, `supersedes`, etc.). When a file is renamed, archived, or hand-edited, those references silently rot. This skill is the validator that catches the rot before it reaches `implementer` or `telemetry`.

This skill **does not modify files**. For rewriting `docs/index.md` use `docs-index`. For fixing a broken reference, the user invokes the producing skill (`adr`, `architect`, etc.).

### PHASE 1: Scan
Walk `docs/` recursively. Include `docs/archive/`. For each `*.md` file (skip `index.md`):

1. Parse front matter into a key→value(s) map. Multi-value fields (`related_adrs`, `related_specs`, `related_research`) accept either a YAML-style list or a comma-separated single line — accept both.
2. Record path, all front-matter values, and (if present) the `Critical Vulnerabilities` section text.

If `docs/` is missing, output `SKIP: no docs/ tree at <cwd>` and halt.

### PHASE 2: Reference Validation
For each parsed file, verify:

1. **`supersedes:`** — value resolves to an existing file under `docs/`. The target's `status:` should be `superseded` and it should sit in `docs/archive/`.
2. **`superseded_by:`** — value resolves to an existing file. The current file's `status:` should be `superseded`.
3. **`related_adrs:`** — every entry resolves to an existing `docs/adrs/*.md`.
4. **`related_research:`** — every entry resolves to an existing `docs/research/*.md`.
5. **`related_specs:`** / **`related_spec:`** — every entry resolves to an existing `docs/specs/*.md`.
6. **`audits:`** (red-team audits — REQUIRED on those docs) — value resolves to an existing `docs/specs/*.md`.

A reference may be either a path (`docs/specs/20260319_foo.md`) or a bare filename (`20260319_foo.md`). Resolve the bare form by looking under the expected subdirectory for the field (e.g., `audits: 20260319_foo.md` resolves to `docs/specs/20260319_foo.md`).

### PHASE 3: Front-Matter Schema
For each file:

1. **Universal:** `# Title` heading and `status:`, `date:` fields present. `date:` parses as `YYYY-MM-DD`.
2. **`status: superseded`** files must live under `docs/archive/`.
3. **Files under `docs/archive/`** must have `status: superseded` (no exceptions — drafts or active docs in archive are violations).
4. **Postmortems:** `incident_start:` and `incident_end:` parse as timestamps; `incident_end >= incident_start`. `severity:` matches `SEV-\d+`.
5. **Benchmarks:** `commit:` matches a short SHA (`[0-9a-f]{7,40}`) or is `unknown`; `target:` is `<package>:<pattern>`.

### PHASE 4: Section Contracts
For red-team audits (any file with an `audits:` field):

1. Section `Critical Vulnerabilities` exists.
2. Each CV entry under it parses with the loose checkbox grep — `[-*] \[ ?x?\] CV-\d+:`. Sub-bullets `Trigger:`, `Impact:`, `Detection:` present.
3. Report any CV missing one of the three sub-bullets — `telemetry` will fail to generate the corresponding alert.

### PHASE 5: Report
Emit a single block. No file modifications.

```
DOCS-LINT
- <N> files scanned
- <K> violations:

[broken-ref]
- <path>: field `<field>` → <target>: not found
- ...

[wrong-status]
- <path>: in archive/ but status != superseded
- ...

[malformed]
- <path>: <description>
- ...

[cv-format]
- <path>: CV-<n> missing `Detection:` sub-bullet
- ...
```

If `K == 0`, output:
```
DOCS-LINT
- <N> files scanned
- 0 violations
```

**Exit Condition:**
Single report block on stdout. No files modified. The user invokes the appropriate producing skill to fix any reported violation.
