# go-toolsmith: Verification Pipeline

Ordered, gated sequence. A BLOCK at any step stops the sequence — do not continue.
Scope: all packages touched in the current task (`./...` unless narrower).

**Table of Contents**

- [Step 0 — Pre-flight](#step-0)
- [Step 1 — Build](#step-1)
- [Step 2 — go vet](#step-2)
- [Step 3 — go fix](#step-3)
- [Step 4 — Static Analysis](#step-4)
- [Step 5 — Tests](#step-5)
- [Gate Summary](#gate-summary)
- [Output Format](#output-format)

---

## Step 0 — Pre-flight {#step-0}

```bash
ls go.mod || echo "NOT AT MODULE ROOT — stop"
go mod tidy -diff 2>/dev/null || go mod tidy -v
```

**Gate:** `go.mod` exists and `go mod tidy` produces no diff.
**On drift:** emit `[VERIFY:MOD_DRIFT]`, run `go mod tidy`, then continue.

---

## Step 1 — Build {#step-1}

```bash
go build ./...
```

**Gate:** exit 0 → PASS.
**On failure:** emit `[VERIFY:BUILD_FAIL]`. Fix ALL errors before proceeding.
Vet and lint output is meaningless against a broken build — do not skip ahead.

Common causes in generated code:

- Wrong receiver type (pointer vs value)
- Missing interface method
- Import cycle introduced by new package
- Unresolved type after refactor

---

## Step 2 — go vet {#step-2}

```bash
go vet ./...
go vet -shadow ./...    # if shadow checker available
```

**Gate:** exit 0 → PASS.
**On failure:** emit `[VERIFY:VET_FAIL]`. Every finding is a real bug — do not defer.

| Finding | What it means |
|---------|--------------|
| `printf` verb mismatch | Wrong format verb — data corruption |
| `copylocks` | Mutex copied by value — race condition |
| `lostcancel` | `WithCancel`/`WithTimeout` cancel never called — goroutine leak |
| `unreachable` | Dead code after return/panic — logic error |
| `structtag` | Malformed struct tag — silent encoding failure |
| `loopclosure` | Loop variable captured by closure — classic Go bug |

---

## Step 3 — go fix {#step-3}

```bash
go fix -diff ./...
```

**Gate:** no diff output → PASS.
**On diff:** emit `[VERIFY:FIX_REQUIRED]`, apply, then re-run Step 1.

```bash
go fix ./...
go build ./...    # re-verify after rewrite
```

Catches generated code using APIs that pre-date the current Go version.
Run `go fix -help` for the full fix list.

---

## Step 4 — Static Analysis {#step-4}

Run in order. Stop at first BLOCK-level finding.

### 4a — golangci-lint (if available)

```bash
golangci-lint run ./...
```

Skip to 4b if not installed — do not block on absence.

| Finding category | Action |
|-----------------|--------|
| `errcheck`, `govet`, `staticcheck` (SA) | **BLOCK** — fix before proceeding |
| `revive`, `stylecheck`, `godot` | **WARN** — record, do not block |
| `wsl`, `nlreturn`, `gofumpt` | **INFO** — batch-fix at REFACTOR |

### 4b — staticcheck (fallback)

```bash
staticcheck ./...
```

`SA` category → emit `[VERIFY:STATIC_FAIL]`, fix.
`S`, `ST`, `QF` categories → WARN only.

### 4c — Custom analyzer (if project defines one)

```bash
go vet -vettool=$(which <project-analyzer>) ./...
```

Check `./bin/`, `./.tools/`, `$(go env GOPATH)/bin/` before assuming absent.

---

## Step 5 — Tests {#step-5}

```bash
go test -race -count=1 -timeout=120s ./...
```

**Gate:** exit 0 → PASS. Pipeline complete — emit `VERIFY:PASS`.
**On failure:** emit `[VERIFY:TEST_FAIL]`. Diagnose before fixing.

**Diagnosis protocol:**

1. Failure in a test Claude wrote → verify test logic first, not just implementation.
   Do not weaken assertions to make a test pass.
2. Failure in a pre-existing test → treat as regression. Understand the contract the
   test encodes before touching either the test or the implementation.
3. `-race` flag reports a data race → emit `[VERIFY:RACE_FAIL]`. BLOCK.
   Do not merge. Identify shared state and fix synchronization.

For `go/analysis` analyzer tests:

```bash
go test ./... -run TestAnalyzer -v
```

---

## Gate Summary {#gate-summary}

```
[Step 0] go mod tidy -diff    → MOD_DRIFT     → tidy, continue
[Step 1] go build ./...       → BUILD_FAIL    → fix all, BLOCK downstream
[Step 2] go vet ./...         → VET_FAIL      → fix all, BLOCK downstream
[Step 3] go fix -diff    → FIX_REQUIRED  → apply, re-run Step 1
[Step 4] SA/error findings    → STATIC_FAIL   → fix, BLOCK downstream
         style findings       → WARN          → record, batch at REFACTOR
[Step 5] go test -race        → TEST_FAIL     → diagnose before fixing
         data race            → RACE_FAIL     → BLOCK, fix synchronization
```

`VERIFY:PASS` — all steps clear. Emit this to REFACTOR/PR agent as handoff token.
PR agent MUST NOT commit without `VERIFY:PASS` in context.

---

## Output Format {#output-format}

```
[VERIFY] go-toolsmith pipeline
  [PASS] Step 0: mod tidy
  [PASS] Step 1: build
  [WARN] Step 2: vet — 1 finding (see below)
  [PASS] Step 3: fix
  [PASS] Step 4: staticcheck
  [PASS] Step 5: tests (47 passed, 0 failed, race: clean)
  [STATUS] VERIFY:WARN — proceed with noted findings

Findings:
  pkg/server/handler.go:42: lostcancel: the cancel function returned by
  context.WithTimeout is not used on all paths
```
