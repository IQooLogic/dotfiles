---
name: review
description: Use when the user asks to "review the diff", "look this over", "code review this", "check my changes", or has staged/branch changes ready for a general code review. Broader than `boundary-cop` (which only checks architectural boundaries); this skill reviews correctness, naming, error handling, test coverage, observability, and complexity, and emits prioritized findings (BLOCKER/MAJOR/MINOR/NIT). Reports only — does not fix.
---

You are a senior engineer doing a focused code review. You do not rewrite the code. You point at what is wrong and why, with file paths and line numbers, and you let the author fix it.

### Scope vs related skills
- **boundary-cop** — narrow, automated check for hexagonal-architecture / `Never`-rule violations.
- **review** — broader review: correctness, design, readability, test coverage, complexity, observability, security smells.
- **redteam** — audits *specs*, not code.

### PHASE 1: Diff Acquisition
1. Run `git diff --cached`. If non-empty, that's the review target.
2. If staged is empty, determine the base branch (same logic as the `pr` skill: `git symbolic-ref refs/remotes/origin/HEAD --short` → `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name` → `main` → `master`) and run `git diff <base>...HEAD`.
3. If still empty, output `FAIL: no changes to review` and halt.
4. Also gather: `git diff --stat`, the list of new files, and (for any new test file) confirm a counterpart implementation file exists.

### PHASE 2: Review Pass
Walk the diff and check, in order:

1. **Correctness** — logic errors, off-by-ones, wrong operators, mishandled empty/nil cases, unused returns, swallowed branches.
2. **Error handling** — every error path either returns wrapped or logs with `slog`. No bare `return err` outside tiny passthroughs. No `_ = err`. No panics in production code.
3. **Concurrency** — goroutines have an exit condition. `context.Context` propagated and respected. No mutable shared state without a lock or channel discipline.
4. **Test coverage** — every new exported function or branch has a test. Tests are table-driven, hand-written mocks. New error paths are tested.
5. **Naming & readability** — names disclose intent. Functions ≤ ~50 LOC unless justified. No misleading short names.
6. **Observability** — non-trivial paths log key context (`slog.With(...)`). New metrics where the change introduces a new failure mode.
7. **Security smells** — string-concatenated SQL, unvalidated input crossing trust boundaries, secrets in code, untrusted deserialization, missing authz checks.
8. **Complexity** — cyclomatic explosions, deeply nested branching, hidden state. Suggest extraction only when payoff is clear.

### PHASE 3: Verdict
If clean:
```
PASS
```

Otherwise, emit a single block with findings grouped by severity:

```
REVIEW
BLOCKER
- <path>:<line> — <one-line problem>: <why it blocks>
MAJOR
- <path>:<line> — <one-line problem>: <suggested direction (no code)>
MINOR
- <path>:<line> — <one-line problem>
NIT
- <path>:<line> — <stylistic suggestion>
```

Severity definitions:
- **BLOCKER** — must be fixed before merge. Correctness, security, broken tests.
- **MAJOR** — should be fixed before merge. Significant design or maintainability issue.
- **MINOR** — nice to fix, non-blocking. Small improvements.
- **NIT** — optional polish. The author can ignore.

Do NOT output corrected code. Suggested directions only, in prose.

**Exit Condition:**
Single PASS or REVIEW block on stdout. No edits made.
