---
name: docs-index
description: Use when the user asks to "rebuild the docs index", "update docs/index.md", "check for docs drift", or after manual file moves under docs/. Walks the docs/ tree, regenerates docs/index.md as a single flat table sorted by date desc, and reports naming/front-matter violations without modifying other files.
---

Rebuild `docs/index.md` from disk truth. Report drift. Do not modify other files.

## Phase 1: Scan

Walk `docs/` recursively (including `archive/`). For each `*.md` (skip `index.md`):
- **Path** — relative to `docs/`
- **Date** — `date:` front matter, fallback to `YYYYMMDD` filename prefix
- **Title** — first `#` heading
- **Status** — `status:` field, default `active`
- **Summary** — first non-empty paragraph after front matter, truncated to 80 chars

## Phase 2: Validate

Report each violation (do not refuse to write):

1. Filename doesn't match `YYYYMMDD_<lowercase-hyphen-slug>.md`.
2. File in `docs/` root or wrong subdirectory (must be in `plans|specs|adrs|research|benchmarks|notes|archive`).
3. Missing front-matter title, `status:`, or `date:`.
4. `status: superseded` but not in `archive/`.
5. File in `archive/` without `status: superseded`.
6. `supersedes:` references nonexistent path.

## Phase 3: Rewrite index

Preserve prose before the first `|` table delimiter. Replace table with flat list sorted by date desc (ties alphabetically by filename):

```markdown
| Date       | File                              | Summary                          |
|------------|-----------------------------------|----------------------------------|
| YYYY-MM-DD | <subdir>/<file>.md                | <one-line summary>               |
```

Archived files appear in the same table with `archive/` prefix.

## Phase 4: Report

```
INDEX REWRITTEN
- <N> entries (<A> active, <S> superseded)
- <K> violations:
  - <path>: <violation>
```

If `K == 0`: `- 0 violations`.
