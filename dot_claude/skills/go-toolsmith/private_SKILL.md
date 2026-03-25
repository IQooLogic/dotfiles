---
name: go-toolsmith
description: >
  Two-mode skill for Go source-code tooling. VERIFY mode: runs the ordered verification
  pipeline (go build → go vet → go fix → golangci-lint → go test) against any
  generated or modified Go code — activate automatically after every IMPLEMENTATION phase
  completes and before any REFACTOR/PR gate. BUILD mode: reference for constructing custom
  analyzers (go/analysis), AST rewriters (go/ast), and x/tools-based codegen tools —
  activate manually with "@go-toolsmith" or at the PLANNER gate when the task itself
  involves building Go tooling. Never auto-trigger on tasks that only mention x/tools
  incidentally.
---

# go-toolsmith

| Mode | When | Read |
|------|------|------|
| **VERIFY** | After any IMPLEMENTATION phase — before REFACTOR/PR gate | `references/verify.md` |
| **BUILD** | Task is to build a linter / analyzer / rewriter / codegen tool | `references/build.md` |

Read only the reference file for the active mode.

> **IMPORTANT**: This is a **skill**, not an agent type. Always invoke it with the `Skill` tool.
> Never use `Agent(subagent_type="go-toolsmith")` — that will fail. Run verification commands directly via `Bash`.

---

## Pipeline Integration

### PLANNER gate (BUILD mode only)
```
[go-toolsmith — PLANNER]
- Layer: AST-only / type-aware / cross-package / SSA       ← Decision Tree in build.md
- Output: analyzer / rewriter / codegen / migration
- Check go fix built-ins first — if sufficient, skip implementation
- Note required x/tools imports for IMPLEMENTATION context header
```

### IMPLEMENTATION
- Confirm layer from Planner gate before writing code.
- Use skeletons from `build.md` verbatim — do not invent structure.
- Emit at top of primary file:
  ```go
  // [go-toolsmith] layer=<ast|analysis|packages|ssa> mode=<inspect|rewrite|generate|migrate>
  ```
- On completion: run VERIFY mode (`references/verify.md`).

### TEST WRITER
- Analyzers (`go/analysis`): MUST use `analysistest`. See `build.md §Analyzer Testing`.
- Refuse hand-rolled AST comparison tests.

### REFACTOR / PR gate
- MUST have `VERIFY:PASS` in context before emitting a commit.
- If `VERIFY:WARN` present: document findings in PR description.
- If any `VERIFY:*_FAIL` present: block commit, return to IMPLEMENTATION.
