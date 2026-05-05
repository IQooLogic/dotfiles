---
name: postmortem
description: Use when the user asks for a "postmortem", "incident review", "RCA", or wants to write up a production incident. Blameless incident author that builds a sourced timeline, runs a why-chain to evidence, and extracts measurable action items. Strict docs-convention compliance.
---

Write a blameless postmortem at `docs/notes/YYYYMMDD_<incident-slug>-postmortem.md` applying docs-convention. Evidence-backed, no attribution to individuals.

## Phase 1: Interrogate

Max 3 questions per turn:
1. **Detection** — when did it start? When detected? By what — alert, customer, internal?
2. **Impact** — what broke, for whom, for how long? Quantify.
3. **Timeline anchors** — first symptom, first action, mitigation, full recovery.
4. **Resolution** — what change ended it? Rollback, config flip, hotfix?
5. **Surprise** — what was the "oh, it's *that*" moment?

## Phase 2: Why-chain

For the most surprising fact: ask "why" up to 5 times. Each answer must reference evidence (log line, commit SHA, metric query). Stop at 3 if evidence runs dry.

## Phase 3: Write

Front matter per docs-convention. Add `incident_start:`, `incident_end:` timestamps, `severity: SEV-<n>`. Sections (exact names):
1. **Summary** — 2–3 sentences: what broke, who affected, how ended.
2. **Impact** — quantified.
3. **Timeline** — `| Time (UTC) | Event | Source |`. Every row sourced.
4. **Root Cause** — why-chain output with evidence refs.
5. **Contributing Factors** — alerting gaps, missing reviews, dashboard drift.
6. **What Went Well** — what saved time.
7. **Action Items** — `| Owner | Action | Due | Type |` where Type is `prevent`/`detect`/`mitigate`. Every item measurable.

## Phase 4: Index

Append to `docs/index.md`, sort by date desc.
