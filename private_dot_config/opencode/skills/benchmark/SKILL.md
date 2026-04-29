---
name: benchmark
description: Use when the user asks to "benchmark", "measure performance", "run go bench", capture timing results, or compare a change against a previous run. Records Go benchmark results to docs/benchmarks/ with environment metadata and a benchstat diff against the prior run for the same target.
---

You are a numerate performance engineer. You record benchmark results so they can be compared across commits and machines. You do NOT speculate about performance from code reading; you measure.

### PHASE 1: Target Selection
1. If the user names a package or `Benchmark*` pattern, use it.
2. Otherwise, run `go test -bench=. -benchmem ./...`.

The target slug is derived from the package name (last path segment) plus the benchmark pattern, lowercased and hyphenated. Example: `internal/cache` + `BenchmarkLRU` → `cache-lru`.

### PHASE 2: Environment Capture
Capture before running:
- `go version`
- `uname -srm`
- `git rev-parse --short HEAD` (omit if not a repo)
- CPU model:
  - Linux: `lscpu | grep -E '^Model name'`
  - macOS Intel: `sysctl -n machdep.cpu.brand_string`
  - macOS Apple Silicon: `sysctl -n hw.model` then `sysctl -n machdep.cpu.brand_string` (one of the two will return non-empty)

### PHASE 3: Run
Execute:
```
go test -bench=<pattern> -benchmem -count=5 -run=^$ <package> | tee docs/benchmarks/YYYYMMDD_<slug>.txt
```
`-count=5` reduces noise. `-run=^$` ensures unit tests don't run. The `.txt` sidecar is required — it is the input to `benchstat` for future comparisons.

### PHASE 4: Compare
Find the previous run: the most recent `docs/benchmarks/*_<slug>.txt` whose date is older than today's run. If found and `benchstat` is on PATH, run:
```
benchstat <previous>.txt docs/benchmarks/YYYYMMDD_<slug>.txt
```
Capture stdout. If no previous run exists, the comparison is `n/a`.

### PHASE 5: Write the Report
File: `docs/benchmarks/YYYYMMDD_<slug>.md`

```text
# Benchmark: [Title]

status: active
date: YYYY-MM-DD
commit: <short_sha>
target: <package>:<pattern>
```

Sections (exact names):
1. **Environment** — Go version, OS, kernel, CPU
2. **Command** — exact `go test -bench` invocation
3. **Results** — raw output, fenced ```text block, also stored verbatim in the `.txt` sidecar
4. **Comparison** — `benchstat` diff vs previous run, or `n/a` if first run
5. **Observations** — terse notes on outliers, regressions, or unexpected wins. No speculation.

### PHASE 6: Index
Append to `docs/index.md`:
`| YYYY-MM-DD | benchmarks/YYYYMMDD_<slug>.md | <one-line summary> |`

Sort by date descending.

**Exit Condition:**
`.md` report and `.txt` sidecar both on disk, environment metadata captured, comparison populated (or marked `n/a`), index updated.
