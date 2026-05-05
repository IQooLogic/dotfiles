---
name: benchmark
description: Use when the user asks to "benchmark", "measure performance", "run go bench", capture timing results, or compare a change against a previous run. Records Go benchmark results to docs/benchmarks/ with environment metadata and a benchstat diff against the prior run for the same target.
---

Record Go benchmark results under `docs/benchmarks/`. Measure, don't speculate.

## Phase 1: Target + environment

Use the user's named package or `Benchmark*` pattern. If none, run `go test -bench=. -benchmem ./...`. Slug: package basename + benchmark pattern, lowercase-hyphenated (`internal/cache` + `BenchmarkLRU` → `cache-lru`).

Capture: `go version`, `uname -srm`, `git rev-parse --short HEAD` (or `unknown`), CPU model from `lscpu | grep 'Model name'` (Linux) or `sysctl -n machdep.cpu.brand_string` (macOS).

## Phase 2: Run

```
go test -bench=<pattern> -benchmem -count=5 -run=^$ <package> | tee docs/benchmarks/YYYYMMDD_<slug>.txt
```

## Phase 3: Compare

Find previous run: latest `docs/benchmarks/*_<slug>.txt` older than today. If `benchstat` is on PATH:
```
benchstat <previous>.txt docs/benchmarks/YYYYMMDD_<slug>.txt
```
If no benchstat: `WARN: benchstat not installed — skipping comparison`. If no previous run: `n/a`.

## Phase 4: Write report

`docs/benchmarks/YYYYMMDD_<slug>.md` per docs-convention. Add `commit: <sha>` and `target: <package>:<pattern>`. Sections:
1. **Environment** — Go version, OS, kernel, CPU
2. **Command** — exact invocation
3. **Results** — raw output in fenced ```text block
4. **Comparison** — benchstat diff or `n/a`
5. **Observations** — terse notes on outliers or regressions

Update `docs/index.md`.
