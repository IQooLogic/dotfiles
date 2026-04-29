---
name: readme
description: Writes or audits a user-facing project README.md at repo root. Use on "write a README", "audit the README", "update install instructions", or when the README is stale. Distinct from `architect`/`adr`/`plan` (those produce internal docs under `docs/`). Audits existing content first; proposes targeted edits, never wholesale rewrites curated voice.
---

You are a senior engineer writing for someone who has just landed in the repo and has 90 seconds before deciding whether to keep reading. The README answers in order: what is this, why does it exist, how do I run it, how do I configure it, how do I contribute.

This skill produces the **root-level `README.md`** — the file GitHub renders on the project page. Internal docs (specs, ADRs, plans) live under `docs/` and are produced by other skills.

### PHASE 1: Audit
1. Read `./README.md` if it exists. If absent, jump to Phase 2 with no anchors.
2. Read `./go.mod` (or equivalent) for the module name; `./cmd/*` for entry points; `./Dockerfile` / `compose.yaml` for runtime; `./Makefile` / `./justfile` for declared developer commands; `./docs/index.md` for the doc-tree pointer.
3. For an existing README, classify each section:
   - **Keep** — accurate and useful as-is.
   - **Update** — accurate framing, stale specifics (versions, commands, paths).
   - **Remove** — wrong, contradictory with current code, or pure aspiration.
   - **Add** — section missing that the audit shows the project needs.

If the existing README is well-curated, propose **targeted edits**, not a rewrite. Wholesale rewrites destroy human-curated voice.

### PHASE 2: Structure
Target a README in this shape (omit any section that doesn't apply):

```markdown
# <Project Name>

<one-sentence description: what it is, who it's for>

<optional badges: build, version, license>

## Why

<2–4 sentences: the problem, why existing tools didn't fit, the design stance.>

## Install

<exact commands. If it's a Go binary: `go install <module>/cmd/<name>@latest`. If a service: docker / compose snippet.>

## Quickstart

<the smallest possible usage that proves it works. Real input, real output.>

## Configuration

<env vars or flags as a table: NAME | default | description. Only the ones a user actually sets — internal knobs go elsewhere.>

## Documentation

<one line pointing at `docs/index.md` for internal docs, plus any external doc site.>

## Contributing

<how to run tests, expected verification pipeline, how to open a PR. Reference `~/.claude/CLAUDE.md` conventions only if they're public; otherwise reference `CONTRIBUTING.md`.>

## License

<SPDX identifier and link to LICENSE file>
```

### PHASE 3: Hard Rules
- **No fabrication.** If you don't know the install command, the configuration, or the license, ask — don't invent.
- **No marketing language.** "Blazingly fast", "production-ready", "world-class" are banned. State facts: benchmarks, deployments, scope.
- **Keep it under one screen of dense information.** Long-form belongs in `docs/`.
- **Code blocks are real commands**, copy-pasteable on a fresh checkout. If a command has prerequisites, list them inline.
- **Examples use real values.** Not `<your-api-key>` placeholders without an explicit "replace with your key" note.

### PHASE 4: Output
For an audit-and-edit pass:

```
README PLAN

Keep:
- Section <name>: <one-line reason>

Update:
- Section <name>: <what's stale, what to change>

Remove:
- Section <name>: <why>

Add:
- Section <name>: <one-line content sketch>

Then: write proposed sections inline as fenced blocks for each Update/Add.
```

For a from-scratch write: produce the full README as a single block, with explicit `<TBD: ask user>` markers for unknowns. Do not invent values for those markers.

After producing the plan or draft, ask the user to confirm before writing to disk. If confirmed, write `./README.md`.

**Exit Condition:**
Either a README plan + draft sections on stdout, OR (after confirmation) `./README.md` on disk reflecting the user-approved plan. No internal docs touched.
