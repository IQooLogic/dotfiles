---
name: docs-index
description: Use when the user asks to "rebuild the docs index", "update docs/index.md", "check for docs drift", or after manual file moves under docs/. Walks the docs/ tree, regenerates docs/index.md as a single flat table sorted by date desc, and reports naming/front-matter violations without modifying other files.
---

You are a meticulous librarian. The `docs/index.md` index drifts whenever a skill forgets to update it or a file is moved manually. This skill is the reconciliation step: scan disk, rewrite the index, report drift.

### PHASE 1: Scan
1. Walk `docs/` recursively. Include `docs/archive/` so archived rows are preserved.
2. For each `*.md` file (skip `index.md` itself), parse:
   - **Path** — relative to `docs/`
   - **Date** — prefer the `date:` field in front matter; fall back to the `YYYYMMDD` prefix of the filename if front matter is missing.
   - **Title** — first `# ...` heading line.
   - **Status** — `status:` field; default to `active` if absent.
   - **Summary** — the first non-empty paragraph after the front matter, truncated to 80 chars.

### PHASE 2: Validate
Report each violation but do not refuse to write the index:
1. Filename does not match `YYYYMMDD_<lowercase-hyphen-slug>.md`.
2. File is in `docs/` root or wrong subdirectory (must be in `plans|specs|adrs|research|benchmarks|notes|archive`).
3. Missing front-matter title, `status:`, or `date:`.
4. `status: superseded` but file is not in `docs/archive/`.
5. File in `docs/archive/` without `status: superseded`.
6. `supersedes:` references a path that does not exist.

### PHASE 3: Rewrite
Read the existing `docs/index.md`. Preserve any prose **before** the first `|` table delimiter (intro paragraphs, conventions notes). Replace the table itself with a single flat table sorted by date desc; tied dates sort alphabetical by filename:

```markdown
# Documentation Index

<preserved prose, if any>

| Date       | File                                  | Summary                          |
|------------|---------------------------------------|----------------------------------|
| YYYY-MM-DD | <subdir>/<file>.md                    | <one-line summary>               |
| ...        | ...                                   | ...                              |
```

Archived files appear in the same table; their `File` column path begins with `archive/`. This matches the global docs-convention in `~/.claude/CLAUDE.md`.

### PHASE 4: Report
Output:
```
INDEX REWRITTEN
- <N> entries (<A> active, <S> superseded)
- <K> violations:
  - <path>: <violation>
  ...
```

If `K == 0`, output `- 0 violations` and nothing else.

**Exit Condition:**
`docs/index.md` rewritten. No other docs modified. Violations listed (or zero confirmed). If the user wants violations fixed, they invoke the appropriate skill (`adr`, `architect`, etc.) per file.
