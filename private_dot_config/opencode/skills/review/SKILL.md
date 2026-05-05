---
name: review
description: Use when the user asks to "review the diff", "look this over", "code review this", "check my changes", or has staged/branch changes ready for a general code review. Broader than `boundary-cop` (which only checks architectural boundaries); this skill reviews correctness, naming, error handling, test coverage, observability, and complexity, and emits prioritized findings (BLOCKER/MAJOR/MINOR/NIT). Reports only — does not fix.
---

General code review. For hexagonal-architecture and CLAUDE.md Never-rule violations, see `boundary-cop`.

## Phase 1: Get diff

1. `git diff --cached`. If empty, determine base branch and run `git diff <base>...HEAD`.
2. If still empty: `FAIL: no changes to review`. Halt.
3. Also gather: `git diff --stat`, list of new files.

## Phase 2: Review

Check: correctness, error handling (wrapped, no silent suppression), concurrency (goroutine exits, context propagation), test coverage, naming, observability (slog), security smells (SQL injection, secrets, missing authz), complexity.

## Phase 3: Report

Clean:
```
PASS
```

Findings:
```
REVIEW
BLOCKER — must fix before merge (correctness, security, broken tests)
- <path>:<line> — <problem>: <why>
MAJOR — should fix before merge (design, maintainability)
- <path>:<line> — <problem>: <suggested direction>
MINOR — nice to fix, non-blocking
- <path>:<line> — <problem>
NIT — optional polish
- <path>:<line> — <stylistic suggestion>
```

No corrected code. Suggested directions in prose only.
