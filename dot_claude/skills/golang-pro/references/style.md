# Google Go Style Guide — Quick Reference

Source: https://google.github.io/styleguide/go/

## Core Principles (in priority order)

1. **Clarity** — Code's purpose and rationale are obvious to the *reader*, not the author.
2. **Simplicity** — Accomplish the goal the simplest way possible.
3. **Concision** — High signal-to-noise ratio.
4. **Maintainability** — Easy for future programmers to modify correctly.
5. **Consistency** — Consistent with the surrounding codebase.

When principles conflict, resolve in order above: clarity beats simplicity beats concision.

---

## Formatting

- All Go source files MUST conform to `gofmt` output. No exceptions.
- Generated code should also be formatted via `format.Source`.

---

## Naming

> For comprehensive naming rules with examples, read `references/naming.md`.

### Fundamental Rules

- Use **MixedCaps** (camelCase), never snake_case. Constants are `MaxLength`, not `MAX_LENGTH`.
- Names should be **short and contextual**. Do not repeat information clear from context.
- Getters: No `Get` prefix. A field `count` has getter `Count()`, not `GetCount()`.
- Initialisms are ALL CAPS when starting exported names (`XMLAPI`, `HTTPClient`, `ID`, `DB`),
  all lowercase when unexported (`xmlAPI`, `httpClient`).

### Package Names

- Lowercase only, no underscores, no mixedCaps.
- Short, concise, singular nouns. Avoid `util`, `common`, `helper`, `base`.
- Package name is part of the call site: `time.Now()` not `time.GetCurrentTime()`.

### Receiver Names

- One or two letters, abbreviation of the type: `(s *Server)`, `(c *Client)`.
- Consistent across ALL methods. Never `this` or `self`.

### Variable Names

- Length proportional to scope distance.
- Single-letter: `i,j,k` for indices; `r` for `io.Reader`; `w` for `io.Writer`;
  `b` for `[]byte`; `ctx` for `context.Context`; `err` for errors.
- Do NOT shadow imports.

### Constants

- MixedCaps. Never `ALL_CAPS`, never `K` prefix. Name based on role, not value.

---

## Commentary

- Every exported symbol MUST have a doc comment starting with the symbol name.
- Complete sentences, ending with a period.
- Package comments: `// Package foo provides...` in exactly one file.
- Implementation comments explain **why**, not **what**.

---

## Imports

### Grouping (in order, separated by blank lines)

1. Standard library packages
2. Everything else (third-party, internal)

### Rules

- Avoid renaming imports; rename only to resolve collisions.
- Never use `.` imports outside tests.
- `import _ "pkg"` only in `main` packages or test files. Document why.

---

## Interfaces

- Interfaces belong in the **consumer** package, not the producer.
- Return **concrete types** from constructors, not interfaces.
- Do NOT define interfaces before they are used (YAGNI).
- Keep interfaces small — prefer minimal viable interfaces.

---

## Nil Slices

- Prefer `var s []string` (nil) over `s := []string{}` (empty).
- Use `len(s) == 0` to check emptiness, not `s == nil`.

---

## Literals

- Use field names in struct literals: `Foo{Bar: 1}` not `Foo{1}`.
- Omit zero-value fields unless meaningful for clarity.

---

## Conditionals

- Do NOT break `if` conditions across multiple lines.
- Extract complex conditions into named boolean variables.

---

## Receiver Type

- **Pointer receiver**: mutates state, contains sync fields, large struct, or consistency.
- **Value receiver**: map/chan/func, small immutable struct, basic type.
- When in doubt, use pointer receiver. Be consistent across all methods.

---

## Context

- `context.Context` is ALWAYS the first parameter.
- Never store contexts in structs.
- Never use `context.Background()` in library code.
- Only `main`, `init`, and top-level test functions may create root contexts.

---

## Global State

- Avoid mutable package-level state.
- Never use `init()` for complex initialization.

---

## Quick Reference: Common Mistakes

| Mistake | Fix |
|---|---|
| `MAX_LENGTH` | `MaxLength` |
| `GetUser()` getter | `User()` |
| `package utils` | Name after what it does |
| `if err == nil { long block }` | Flip: handle error first, return early |
| `go doWork()` fire-and-forget | Add lifecycle mgmt (WaitGroup, context) |
| Interface in producer pkg | Move to consumer |
| `t := []string{}` | `var t []string` |
| String-matching errors | Use sentinel errors or `errors.Is` |
| `context.Background()` in library | Accept `ctx` from caller |
