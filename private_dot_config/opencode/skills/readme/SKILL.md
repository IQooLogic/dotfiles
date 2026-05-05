---
name: readme
description: Writes or audits a user-facing project README.md at repo root. Use on "write a README", "audit the README", "update install instructions", or when the README is stale. Distinct from `architect`/`adr`/`plan` (those produce internal docs under `docs/`). Audits existing content first; proposes targeted edits, never wholesale rewrites curated voice.
---

Audit or write the root-level `README.md`. Internal docs belong under `docs/` (use other skills).

## Phase 1: Audit

Read `./README.md` if it exists. Read `./go.mod`, `./cmd/*`, `./Dockerfile`/`compose.yaml`, `./Makefile`/`justfile`, `./docs/index.md` for context.

Classify each section: **Keep** (accurate), **Update** (stale specifics), **Remove** (wrong/aspirational), **Add** (missing needed sections). For an existing README, propose targeted edits — never wholesale rewrites.

## Phase 2: Structure

Target structure (omit inapplicable sections):
- `# Name` + one-sentence description + optional badges
- `## Why` — problem + design stance (2–4 sentences, no marketing language)
- `## Install` — exact copy-pasteable commands
- `## Quickstart` — smallest provable usage
- `## Configuration` — table: NAME | default | description (user-facing only)
- `## Documentation` — pointer to `docs/index.md`
- `## Contributing` — tests, verification, PR process
- `## License` — SPDX identifier + link

## Phase 3: Hard rules

- No fabrication — ask for unknowns, use `<TBD: ask user>` markers.
- No marketing language ("blazingly fast", "production-ready").
- Code blocks must be real, copy-pasteable commands.

## Phase 4: Output

For audits:
```
README PLAN
Keep: - Section <name>: <reason>
Update: - Section <name>: <what to change>
Remove: - Section <name>: <why>
Add: - Section <name>: <draft>
```

For new READMEs: produce full content with `<TBD>` markers. Ask before writing to disk.
