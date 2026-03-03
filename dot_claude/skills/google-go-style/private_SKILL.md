---
name: google-go-style
description: >
  Enforces Google's Go Style Guide when writing, reviewing, or refactoring Go code.
  Use this skill whenever writing Go code, reviewing Go code, generating Go functions,
  creating Go packages, or refactoring Go. Also trigger when the user mentions
  "Go style", "Google style guide", "Go best practices", "Go naming", "Go error handling",
  "Go testing patterns", or asks for idiomatic Go. Apply this skill to ALL Go code
  generation tasks even if the user does not explicitly mention style.
---

# Google Go Style Guide — Claude Code Skill

Source: https://google.github.io/styleguide/go/

This skill distills Google's complete Go Style Guide (Guide + Decisions + Best Practices)
into actionable rules. When writing Go code, follow every rule below. When a topic needs
deeper context, read the referenced file under `references/`.

---

## Core Principles (in priority order)

1. **Clarity** — Code's purpose and rationale are obvious to the *reader*, not the author.
2. **Simplicity** — Accomplish the goal the simplest way possible.
3. **Concision** — High signal-to-noise ratio.
4. **Maintainability** — Easy for future programmers to modify correctly.
5. **Consistency** — Consistent with the surrounding codebase.

When principles conflict, resolve in the order above: clarity beats simplicity beats concision.

---

## Formatting

- All Go source files MUST conform to `gofmt` output. No exceptions.
- Generated code should also be formatted via `format.Source`.

---

## Naming

> For comprehensive naming rules with examples, read `references/naming.md`.

### Fundamental Rules

- Use **MixedCaps** (camelCase), never snake_case. Constants are `MaxLength`, not `MAX_LENGTH`.
- Names should be **short and contextual**. Do not repeat information already clear from context.
- Getters: No `Get` prefix. A field `count` has getter `Count()`, not `GetCount()`.
- Initialisms are ALL CAPS when starting exported names (`XMLAPI`, `HTTPClient`, `ID`, `DB`), all lowercase when unexported (`xmlAPI`, `httpClient`).

### Package Names

- Lowercase only, no underscores, no mixedCaps.
- Short, concise, singular nouns. Avoid `util`, `common`, `helper`, `base`.
- The package name is part of the call site: `time.Now()` not `time.GetCurrentTime()`.

### Receiver Names

- One or two letters, abbreviation of the type: `(s *Server)`, `(c *Client)`.
- Consistent across ALL methods of the type.
- Never use `this` or `self`.

### Variable Names

- Length proportional to scope distance: `i` for loop index is fine, `userCount` for package-level.
- Prefer `userCount` over `numUsers` or `nUsers` for quantities.
- Single-letter names: `i,j,k` for indices; `r` for `io.Reader`; `w` for `io.Writer`; `b` for `[]byte`; `ctx` for `context.Context`; `err` for errors; `ok` for booleans from maps/type assertions.
- Do NOT shadow imports: never name a variable `context`, `errors`, `fmt`.

### Avoid Repetition

- Do not repeat package name in exported symbols: `file.Read` not `file.FileRead`.
- Do not repeat method receiver in method name: `s.Count()` not `s.ServerCount()`.
- Do not repeat parameter types in function name when unambiguous.

### Constants

- Use MixedCaps. Never `ALL_CAPS`, never `K` prefix.
- Name based on role, not value: `MaxRetries` not `Five`.

---

## Commentary

> For detailed commentary rules, see `references/patterns.md`.

### Doc Comments

- Every exported symbol (function, type, const, var, package) MUST have a doc comment.
- Start with the name of the element: `// Server represents...`, `// ErrNotFound indicates...`.
- Complete sentences, ending with a period.
- Package comments: `// Package foo provides...` in exactly one file (usually `doc.go`).
- Use `//` comments for doc comments, not `/* */`.

### Implementation Comments

- Explain **why**, not **what**. The code shows what; comments explain rationale.
- Flag non-obvious behavior, performance reasons, workarounds, TODOs.
- Comment line length: aim for ~80 chars, hard limit at 100. URLs may exceed.

### Named Result Parameters

- Use when they genuinely improve godoc readability.
- Do NOT use just to save a `var` declaration.
- Always use `return` with explicit values when named results exist (avoid bare returns).

---

## Imports

### Grouping (in this order, separated by blank lines)

1. Standard library packages
2. Everything else (third-party, internal)

### Renaming

- Avoid renaming imports; rename only to resolve collisions or for very long paths.
- Renamed imports must still follow Go naming rules (lowercase, no underscores).
- Never use `.` imports outside tests.

### Side-effect Imports

- `import _ "pkg"` only in `main` packages or test files.
- Document why: `import _ "image/png" // Register PNG decoder`.

---

## Error Handling

> For comprehensive error handling patterns, read `references/errors.md`.

### Returning Errors

- Return `error` as the last return value.
- Error strings: lowercase, no punctuation at end, no "failed to" prefix.
  Good: `fmt.Errorf("connect to %s: %v", addr, err)`
  Bad: `fmt.Errorf("Failed to connect to %s: %v.", addr, err)`

### Handling Errors

- ALWAYS handle errors. Do one of: handle it, return it, call `log.Fatal`, or in truly impossible cases `panic`.
- Never silently discard: `_ = f.Close()` only when you've documented why.

### Error Wrapping

- Use `%w` when callers need `errors.Is`/`errors.As` to inspect the cause.
- Use `%v` when you want to add context but hide implementation details.
- Do NOT add redundant info the inner error already provides.
- Bad: `fmt.Errorf("open %s: %v", path, err)` when `err` already contains the path.
- Bad: `fmt.Errorf("failed: %v", err)` — just return `err`.

### Structured Errors

- Use sentinel errors (`var ErrNotFound = errors.New(...)`) when callers must distinguish conditions.
- Use custom error types when callers need structured data from the error.
- Never match errors by string content.

### Error Flow

- Indent the error path, not the happy path. The "line of sight" rule:
```go
// Good:
val, err := doSomething()
if err != nil {
    return err
}
// continue with val...

// Bad:
val, err := doSomething()
if err == nil {
    // long block of happy path
} else {
    return err
}
```

### Don't Panic

- Never `panic` for normal error handling. Use error returns.
- `panic` is acceptable only for truly impossible conditions (programming bugs).
- In `main`/init, prefer `log.Fatal` over `panic` — no stack trace needed for config errors.

### Must Functions

- `MustXYZ` pattern: only for program startup / package init / test helpers.
- Must functions `panic` on error — never use in request handlers or business logic.

---

## Interfaces

- Interfaces belong in the **consumer** package, not the producer.
- Return **concrete types** from constructors, not interfaces.
- Do NOT define interfaces before they are used (YAGNI).
- Do NOT export interfaces users don't need.
- Do NOT use interface parameters when only one type is ever passed.
- Keep interfaces small — prefer minimal viable interfaces.

---

## Generics

- Use only when they fulfill actual business requirements.
- Prefer concrete types first, add generics later if genuinely needed.
- Do NOT use generics to build DSLs or error-handling frameworks.
- If only one type is ever instantiated, don't use generics.

---

## Concurrency

> For comprehensive concurrency patterns, channel usage, sync primitives, and errgroup, read `references/concurrency.md`.

### Goroutine Lifetimes

- ALWAYS make goroutine exit conditions explicit and documented.
- Use `context.Context` for cancellation.
- Use `sync.WaitGroup` to prevent goroutines from outliving their parent.
- Never fire-and-forget: `go process(item)` without lifecycle management is a bug.
- Sending on a closed channel panics. Blocked goroutines are never garbage-collected.

### Synchronous by Default

- Prefer synchronous functions. Let the caller manage concurrency.
- If a function must be async, document the goroutine lifecycle clearly.

### Channel vs Mutex

- Channels: transferring ownership of data, distributing work, communicating results.
- Mutexes: protecting shared state (caches, counters, struct fields).
- When in doubt, start with a mutex — simpler mental model.

### errgroup

- Use `errgroup.Group` for fan-out/fan-in with error propagation and context cancellation.
- Derived context from `errgroup.WithContext` is cancelled when any goroutine returns an error.

---

## Testing

> For comprehensive testing conventions, read `references/testing.md`.

### Test Failures

- Include: what function was called, with what inputs, what it returned, what was expected.
- Format: `YourFunc(%v) = %v, want %v`
- Show "got" before "want" in all messages.

### Table-Driven Tests

- Use for multiple test cases with similar structure.
- Each case has a descriptive `name` field for subtests.
- Run with `t.Run(tc.name, func(t *testing.T) { ... })`.
- Never use array index as test identifier.

### Test Helpers

- Mark with `t.Helper()` so failures report the caller's line.
- Test helpers do setup/cleanup; they are NOT assertion libraries.
- Do NOT build assertion frameworks — use `if got != want { t.Errorf(...) }`.

### Subtests

- Each subtest must be independent — no shared mutable state, no ordering deps.
- Names: readable, useful on command line. Avoid `/` and non-printing chars.

### Packages

- Same package (`package foo`) for white-box tests needing unexported access.
- External package (`package foo_test`) for black-box / integration tests.

---

## Nil Slices

- Prefer `var s []string` (nil) over `s := []string{}` (empty) for declarations.
- Use `len(s) == 0` to check emptiness, not `s == nil`.
- Do NOT design APIs that distinguish nil from empty slices.

---

## Literals

### Struct Literals

- Use field names in struct literals: `Foo{Bar: 1}` not `Foo{1}`.
- Omit zero-value fields unless they're meaningful for clarity.
- Closing brace on its own line for multi-line literals.

### Function Formatting

- Keep function signatures on one line. If too long, factor out local variables.
- Do NOT break function calls at arbitrary points — group by semantic meaning.
- Use option structs for functions with many parameters.

---

## Conditionals

- Do NOT break `if` conditions across multiple lines (indentation confusion).
- Extract complex conditions into named boolean variables:
```go
inTransaction := db.CurrentStatusIs(db.InTransaction)
keysMatch := db.ValuesEqual(db.TransactionKey(), row.Key())
if inTransaction && keysMatch {
    // ...
}
```

---

## Pass Values

- Do NOT pass pointers just to save bytes. If a function only reads `*x`, pass `x`.
- Exception: large structs, or when the function signature mandates a pointer.

---

## Receiver Type

- Use **pointer receiver** when: the method mutates state, the receiver contains sync fields (e.g. `sync.Mutex`), the receiver is large, or other methods already use pointer receiver.
- Use **value receiver** when: the receiver is a map/chan/func, the receiver is a small struct with no mutable fields, or the receiver is a basic type (`int`, `string`).
- When in doubt, use pointer receiver.
- Be consistent: all methods on a type should use the same receiver type.

---

## Context

- `context.Context` is ALWAYS the first parameter: `func DoThing(ctx context.Context, ...) error`.
- Never store contexts in structs.
- Never use `context.Background()` in library code — accept it from the caller.
- Only `main`, `init`, and top-level test functions may create root contexts.
- Never create custom context types — use `context.WithValue` with unexported key types.

---

## Logging

- Use structured logging where available.
- Log at the appropriate level — don't log errors you're also returning (double-logging).
- Error messages in logs: include enough context to diagnose without the original request.

---

## Global State

- Avoid mutable package-level state. It makes testing and concurrency hard.
- If unavoidable: provide instance-based APIs alongside, document concurrency safety.
- Never use `init()` for complex initialization — prefer explicit setup.

---

## Least Mechanism

When multiple approaches exist, prefer (in order):
1. Core language constructs (channels, slices, maps, loops, structs)
2. Standard library
3. Well-known third-party packages
4. Internal/custom solutions

Do not introduce complexity machinery without justification.

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
| Bare `return` with named results | Explicit `return val, err` |
| `context.Background()` in library | Accept `ctx` from caller |
