---
name: redteam
description: Audits a written spec or plan for failure modes — concurrency races, CAP fallacies, retry storms, observability gaps. Use on "red-team this spec", "audit the plan", "find the failure modes", "tear apart docs/specs/...", or before a spec advances to implementation. Produces a CV checklist that `telemetry` and `implementer` consume.
---

Audit a spec for failure modes. Produce a Critical Vulnerabilities checklist consumed by `telemetry` and `implementer`.

## Phase 0: Verify target

Must be invoked with a target path. Verify file exists and is a spec/plan. If not: `FAIL: target spec not found: <path>` or `FAIL: target is not a spec/plan`. Halt.

## Phase 1: Teardown

Read the target. Hunt for:
1. **Concurrency & State** — unprotected memory, races, map-access panics, deadlocks.
2. **Distributed Systems** — CAP fallacies, network partitions, clock skew.
3. **Failure Cascades** — missing circuit breakers, OOM under DB slowdown, retry storms.
4. **Data Integrity** — migration backward-compatibility, split-brain risk, idempotency.
5. **Observability Blind Spots** — if this fails silently at 3 AM, how does on-call know?

## Phase 2: Write audit

Create `docs/notes/YYYYMMDD_<slug>-redteam.md` per docs-convention. Front matter requires `audits: docs/specs/<spec-slug>.md` (REQUIRED — consumed by `implementer` and `telemetry`).

Sections (exact names):
1. **Critical Vulnerabilities** — each entry:
   ```
   - [ ] CV-<n>: <one-line failure mode>
     - Trigger: <how it happens>
     - Impact: <user/data/system consequence>
     - Detection: <metric/log/alert that would catch it> OR `none`
   ```
   Format is a contract — do not deviate. `telemetry` parses CV entries to generate alert rules.

2. **Architectural Smells** — coupling, leaky abstractions, maintainability issues.
3. **Unstated Assumptions** — infrastructure assumptions not in the spec.
4. **The Fix It Mandate** — prioritized list of what MUST change in the spec before code. Reference CV-<n>.

Update `docs/index.md`.
