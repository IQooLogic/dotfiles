---
name: verify
description: Use after writing or modifying Go code, before committing, or when the user asks to "verify", "run the pipeline", "check Go", "run tests with race". Runs the binding Go verification pipeline in strict order (mod tidy → build → vet → fix → golangci-lint → test -race) and reports PASS/FAIL with a halt at the first failure.
---

Run the binding Go verification pipeline. Report only. Do not fix.

## Pipeline (strict order, halt on first failure)

1. `go mod tidy`
2. `go build ./...`
3. `go vet ./...`
4. `go fix ./...`
5. `golangci-lint run` — if not on PATH: `WARN: golangci-lint not installed — skipping step 5`, continue.
6. `CGO_ENABLED=1 go test -race ./...`

## Phase 1: Detect

Confirm cwd has `go.mod`. If not: `SKIP: not a Go module`. Halt.

## Phase 2: Run

Execute steps in order. Stop at first non-zero exit.

## Phase 3: Report

Success:
```
PASS
- go mod tidy: clean
- go build: ok
- go vet: ok
- go fix: ok
- golangci-lint: ok (or skipped)
- go test -race: <N> packages, <M> tests
```

Failure:
```
FAIL at step <n>: <step name>
<last 50 lines of failing output>
```

Do not propose fixes. Do not continue past failure.
