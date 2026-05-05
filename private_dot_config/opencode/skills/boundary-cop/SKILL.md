---
name: boundary-cop
description: Narrow architectural-and-Never-rules check on a staged Go diff. Use when the user asks to "review boundaries", "check architecture", "lint the diff", or before committing/merging. Scans for hexagonal leaks, dropped contexts, silent error suppression, unstructured logging, attribution lines. Reports only — does not fix. For broader review (correctness, naming, tests), use `review` instead.
---

Narrow architectural and CLAUDE.md Never-rules check on a Go diff. Reports only. Does not fix.

## Phase 1: Get diff

1. `git diff --cached`. If empty, `git diff` (prepend `WARN: reviewing unstaged changes`).
2. If both empty: `FAIL: No changes to review.` Halt.

## Phase 2: Identify boundaries

Check `./CLAUDE.md` or `docs/CLAUDE.md` for `## Architecture` section declaring domain and infrastructure roots. If not declared, check `internal/domain/` and `internal/infrastructure/`. If neither found, ask once: "Which directories are domain? Which are infrastructure?"

## Phase 3: Scan

Report each violation with path, line, and rule:

1. **Domain leakage** — domain root importing `net/http`, `database/sql`, or external vendor modules.
2. **Context dropping** — new exported interface method or blocking function missing `ctx context.Context` as first parameter.
3. **Infrastructure bleed** — adapters returning raw driver errors (`redis.Nil`, `sql.ErrNoRows`, `mongo.ErrNoDocuments`) without wrapping to domain errors.
4. **Silent error suppression** — `_ = err`, bare `return err` without wrap (except in passthrough wrappers ≤5 lines). Must wrap: `fmt.Errorf("component: action: %w", err)`.
5. **Unstructured logging** — `fmt.Println`, `fmt.Printf`, `log.Printf`/`log.Println` outside `_test.go` and `main.go` bootstrap.
6. **Attribution lines** — "Generated with Claude Code" or similar in committed code.

## Phase 4: Verdict

Clean:
```
PASS
```

Violations found:
```
FAIL
- <path>:<line> — <rule name>: <specifics>
- ...
```

Do not output corrected code.
