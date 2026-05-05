---
name: logging
description: Designs and wires structured logging with `log/slog` into a Go package. Use on "add structured logging", "wire slog into X", "replace fmt.Println with slog", or before promoting a prototype to production. Identifies log boundaries, proposes attached fields, recommends a `slog.Handler` config. Bound by `~/.claude/CLAUDE.md` — no `fmt.Println`/`log.Printf` in production.
---

Design slog wiring for a Go package. Do not auto-apply edits — output a plan.

## Phase 1: Read target

Read the target file/package. Identify:
- Existing logging calls (`fmt.Print*`, `log.Print*`, `slog.*`)
- Boundary functions: HTTP handlers, gRPC handlers, queue consumers, scheduled jobs
- Domain identifiers in scope: `request_id`, `user_id`, `tenant_id`, `job_id`
- Existing `slog.Handler` factory — if one exists, integrate, don't replace

## Phase 2: Design

For each boundary:
- **Entry**: `slog.InfoContext` with route/operation, request_id
- **Errors**: `slog.ErrorContext` with wrapped error as `slog.Any("err", err)`. Log once at boundary — non-boundary functions return wrapped errors, don't log.
- **Outcome**: optional `slog.InfoContext` with duration and status

**Field set** via `slog.With(...)` at boundary: `request_id`, `op` (route/RPC/job), `user_id`/`tenant_id` when authenticated. Never log: passwords, tokens, full bodies, unauthorized PII.

## Phase 3: Handler config

If no existing handler: recommend `slog.NewJSONHandler(os.Stdout, opts)` for production, `slog.NewTextHandler` for dev. Level via `LOG_LEVEL` env, default `info`. `AddSource: true` only in dev. Factory at `internal/logging/logger.go`. Constructor injection preferred over package-global.

## Phase 4: Output

```
LOGGING PLAN: <target>

Boundaries:
- <file>:<func> — entry/exit/error

Fields (slog.With at boundary): request_id, op=<route>, user_id (when set)

Handler: <recommendation or "use existing at <path>">

Edits:
- <file>:<line> — <description>

Removed (forbidden):
- <file>:<line> — fmt.Println / log.Printf
```
