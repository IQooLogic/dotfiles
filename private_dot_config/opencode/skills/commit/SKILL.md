---
name: commit
description: Use when the user asks to "commit", "make a commit", "write a commit message", or has staged changes ready to record. Generates a strict conventional commit header from staged changes and outputs only the `git commit` command.
---

Generate a conventional commit message from staged changes. Output only the `git commit` command.

## Phase 1: Context

1. `git diff --cached`. If empty: halt, tell user to stage changes.
2. `git status --porcelain`. If unstaged files touch same files as staged: prepend `WARN: unstaged changes in <files>; staged commit may be incomplete`.
3. `git rev-parse --abbrev-ref HEAD`. If `main`, `master`, or `release/*`: prepend `WARN: committing directly to <branch>`.

## Phase 2: Construct message

Format: `<type>(<optional scope>): <short summary>`

**Types:** `feat`, `fix`, `docs`, `refactor`, `test`, `chore`, `ci`, `perf`, `style`, `build`.

**Scope:** short area identifier (`api`, `worker`, `auth`, `pipeline`, `docker`) — omit if too broad.

**Hard constraints:** header only (no body, no footer), imperative mood (`add` not `added`), lowercase, no trailing period, ≤72 chars.

## Phase 3: Output

Single bash block, preceded only by warnings from Phase 1:

```bash
git commit -m "feat(api): add prometheus metrics endpoint"
```
