---
name: telemetry
description: Use when the user asks to "wire up alerting", "generate Prometheus rules", "add monitoring for this spec", or has a vetted spec + audit ready for day-2 ops. Converts spec + red-team audit into Prometheus alerting rules (YAML), one alert per Critical Vulnerability, validated for parseability before exit.
---

Generate Prometheus alerting rules from a spec and its redteam audit.

## Phase 1: Acquire context

Must be given a spec path. Search `docs/notes/*.md` for `audits:` matching the spec. Use most recent by `date:`.

**No audit found:** halt with `FAIL: no audit for this spec; run \`redteam\` first`. Override only with `--no-audit` or explicit user skip — then emit `WARN: generated without redteam audit` and set front matter `audit_status: missing`.

## Phase 2: Generate alerts

Parse audit's `Critical Vulnerabilities` section. For each CV:
- `Trigger:` → PromQL condition
- `Impact:` → severity and summary
- `Detection:` → metric to query (if `none`, propose a metric the implementer must expose)

One alert per CV. Also extract additional failure modes from spec's `State Management` and `Execution Sequence` — emit those with `labels.source: spec`.

**Constraints:**
- Standard PromQL.
- `severity: critical` or `severity: warning`.
- `annotations.summary` (what broke) and `annotations.runbook` (immediate fix).
- `labels.cv: CV-<n>` linking back to audit.

## Phase 3: Write

`infra/monitoring/alerts/YYYYMMDD_<spec-slug>.yml`. Create directories if missing.

## Phase 4: Validate

Try `promtool check rules <file>`. If not on PATH, try `python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" <file>`. If neither: `WARN: promtool and python3 not available — YAML not validated`. Fix and re-validate on failure.

## Phase 5: Report

```
File: <path>
Audit: <audit_path or "missing">
Validation: promtool|yaml|skipped
Coverage:
  CV-1 → <alert_name>
  CV-2 → <alert_name>
  spec:<failure_mode> → <alert_name>
```
