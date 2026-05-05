---
name: test
description: Use when the user asks to "write tests for X", "add table tests", "test this function", "improve coverage on package Y", or has untested Go code that needs coverage. Generates table-driven Go tests for a target function, type, or package. Hand-written mocks only — no mock-gen frameworks. Runs the verification pipeline at the end.
---

Write table-driven Go tests. Hand-written mocks only. Tests exercise behavior, not implementation.

## Phase 1: Read target

Read the target file(s) and existing `*_test.go` (extend, don't duplicate). Identify public surface, input shapes, side effects, and interface dependencies (mock candidates).

## Phase 2: Enumerate cases

Per function:
- **Happy path** — typical inputs, expected output.
- **Boundaries** — empty, single-element, max-int, zero, negative, just-over-limit.
- **Error paths** — one case per distinct `return ..., err` branch.
- **Context cancellation** — pre-cancelled context, assert `ctx.Err()` propagates.
- **Concurrency** — if goroutines or channels, add `t.Parallel()` case.

## Phase 3: Write

File: `<target>_test.go`. Table-driven, `t.Run`, standard library assertions only (`if got != want { t.Fatalf(...) }`). Use `errors.Is`/`errors.As` for error sentinels. Failure messages show both `got` and `want`.

Mocks: hand-rolled structs implementing domain interfaces in `<package>_mocks_test.go`. No mockery/gomock/mock-gen. Record calls, return canned values.

## Phase 4: Verify

Run `CGO_ENABLED=1 go test -race ./<package>`. Fix until green.
