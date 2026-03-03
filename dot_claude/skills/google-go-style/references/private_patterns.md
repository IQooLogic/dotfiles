# Patterns and Conventions - Detailed Reference

Source: Google Go Style Decisions + Best Practices

## Table of Contents
1. Documentation and Comments
2. Interfaces
3. Concurrency
4. Context Usage
5. Receiver Type Selection
6. Import Organization
7. Literal Formatting
8. Conditional Formatting
9. Pass Values vs Pointers
10. Type Aliases
11. Generics
12. Global State
13. Copying
14. Logging
15. Flags and Configuration
16. Least Mechanism
17. Shadowing

---

## 1. Documentation and Comments

### Doc Comments

Every exported symbol MUST have a doc comment starting with its name:

```go
// Server handles incoming RPC requests.
type Server struct { ... }

// NewServer creates a Server with the given options.
func NewServer(opts ...Option) *Server { ... }

// ErrNotFound indicates the requested resource does not exist.
var ErrNotFound = errors.New("not found")
```

### Package Comments

Exactly one file per package contains the package comment. For multi-file packages, use doc.go:

```go
// Package auth provides authentication and authorization primitives
// for the service mesh.
package auth
```

Tips:
- Start with "Package [name]" and describe what the package provides.
- For simple packages, the comment can be brief.
- For complex packages, include usage examples and key concepts.

### Comment Line Length

Aim for ~80 characters per comment line. URLs may exceed this. Do not break URLs across lines.

### Implementation Comments

- Explain WHY, not WHAT.
- Use complete sentences.
- Leave a blank comment line between a doc comment and an implementation comment.

```go
// Process executes the pipeline stages in order.
//
// This uses a fan-out pattern because individual stages are I/O-bound
// and benefit from concurrent execution.
func (p *Pipeline) Process(ctx context.Context) error { ... }
```

### Named Result Parameters

Use when they improve godoc readability:
```go
// Good: named results clarify what each value represents
func ParseDuration(s string) (duration time.Duration, err error)

// Bad: named results are just noise
func Add(a, b int) (sum int)  // "sum" adds nothing useful
```

Never use bare returns (return without values) even with named results. Always explicit.

---

## 2. Interfaces

### Consumer Owns the Interface

Interfaces belong in the package that USES them, not the package that implements them:

```go
// Good: consumer defines what it needs
package consumer

type Storer interface {
    Store(ctx context.Context, key string, val []byte) error
}

func Process(s Storer) error { ... }
```

```go
// Good: producer returns concrete type
package storage

type DiskStore struct { ... }

func NewDiskStore(path string) *DiskStore { ... }
```

### Return Concrete Types

Constructors return concrete types, not interfaces. This allows adding methods without breaking.

### Do NOT Pre-Define

Do not define interfaces before they are needed. Without a real use case, you cannot know what methods to include.

### Minimal Viable Interfaces

Create interfaces with only the methods the consumer actually calls:
```go
// Good: consumer only needs Read
type Reader interface {
    Read(p []byte) (n int, err error)
}

// Bad: consumer imports a huge interface but only calls Read
type FileSystem interface {
    Open(name string) (File, error)
    Stat(name string) (FileInfo, error)
    ReadDir(name string) ([]DirEntry, error)
    // ... 10 more methods the consumer never calls
}
```

---

## 3. Concurrency

### Goroutine Lifecycle

Every goroutine must have a clear, documented exit condition:

```go
// Good: goroutines are bounded by WaitGroup and context
func (w *Worker) Run(ctx context.Context) error {
    var wg sync.WaitGroup
    for item := range w.queue {
        wg.Add(1)
        go func() {
            defer wg.Done()
            w.process(ctx, item)
        }()
    }
    wg.Wait()
    return nil
}

// Bad: fire-and-forget goroutine
func (w *Worker) Run() {
    for item := range w.queue {
        go w.process(item) // when does this stop?
    }
}
```

### Synchronous by Default

Prefer synchronous functions. Let the caller decide on concurrency:

```go
// Good: synchronous, caller wraps in goroutine if needed
func (s *Store) Save(ctx context.Context, item Item) error {
    return s.db.Insert(ctx, item)
}

// Bad: internally concurrent without clear lifecycle
func (s *Store) Save(item Item) {
    go func() {
        s.db.Insert(context.Background(), item) // leaked goroutine
    }()
}
```

### Channel vs Mutex

- Channels: for transferring ownership of data, distributing work, communicating results.
- Mutexes: for protecting shared state (caches, counters, struct fields).

---

## 4. Context Usage

### Rules

- Always the first parameter: `func Do(ctx context.Context, ...) error`
- Never stored in structs.
- Never nil. Use context.TODO() if unsure which context to use.
- Only main, init, and top-level test functions create root contexts.
- Library code always accepts context from the caller.

### Custom Contexts

Do NOT create custom context types. Use context.WithValue with unexported key types:

```go
type contextKey struct{}

func WithUserID(ctx context.Context, id string) context.Context {
    return context.WithValue(ctx, contextKey{}, id)
}

func UserID(ctx context.Context) (string, bool) {
    id, ok := ctx.Value(contextKey{}).(string)
    return id, ok
}
```

---

## 5. Receiver Type Selection

### Use Pointer Receiver When

- The method mutates the receiver.
- The receiver contains a sync.Mutex or similar synchronization field.
- The receiver is a large struct or array.
- Any other method on the type uses a pointer receiver (consistency).

### Use Value Receiver When

- The receiver is a map, func, or chan (reference types already).
- The receiver is a small, immutable struct.
- The receiver is a basic type (int, string).
- The type has no mutable state.

### Consistency Rule

If any method needs a pointer receiver, ALL methods should use pointer receivers.

---

## 6. Import Organization

Group imports in this order, separated by blank lines:

```go
import (
    // Standard library
    "context"
    "fmt"
    "net/http"

    // Third-party and internal packages
    "github.com/google/go-cmp/cmp"
    "google.golang.org/grpc"
    "mycompany.com/internal/auth"
)
```

### Renaming

- Avoid renaming. Only rename to resolve collisions.
- Renamed imports must be valid Go identifiers (lowercase, no underscores).
- Never use dot imports outside of tests.
- Proto imports: use short names like `foopb`, `barpb`.

### Side-Effect Imports

- Only in main packages or test files.
- Always document why: `import _ "image/png" // Register PNG decoder`

---

## 7. Literal Formatting

### Struct Literals

Always use field names:
```go
// Good:
srv := &Server{
    Addr:    ":8080",
    Handler: mux,
}

// Bad:
srv := &Server{":8080", mux}
```

### Zero-Value Fields

Omit zero-value fields unless they convey meaning:
```go
// Good: only set non-default values
opts := &Options{
    BlockSize:       1 << 16,
    ErrorIfDBExists: true,
}

// Bad: explicitly setting zero values
opts := &Options{
    BlockSize:       1 << 16,
    ErrorIfDBExists: true,
    Compression:     nil,     // this is the zero value
    MaxOpenFiles:    0,       // this is the zero value
    VerifyChecksums: false,   // this is the zero value
}
```

### Matching Braces

Opening and closing braces must be at the same indentation level for multi-line literals.

---

## 8. Conditional Formatting

Do NOT break if conditions across lines:
```go
// Bad: indentation confusion
if db.CurrentStatusIs(db.InTransaction) &&
    db.ValuesEqual(db.TransactionKey(), row.Key()) {
    return err
}

// Good: extract to named variables
inTransaction := db.CurrentStatusIs(db.InTransaction)
keysMatch := db.ValuesEqual(db.TransactionKey(), row.Key())
if inTransaction && keysMatch {
    return err
}
```

### Switch Statements

Prefer switch over if-else chains for multiple conditions on the same variable.

---

## 9. Pass Values vs Pointers

Do NOT pass pointers just to save bytes:
- If a function only reads *x throughout, pass x by value.
- Exception: very large structs or when the interface requires a pointer.
- Large structs: where "large" means similar to passing all fields as separate arguments.

---

## 10. Type Aliases

- Use type aliases primarily for gradual code repair (migration).
- Do NOT use type aliases to avoid importing a package.
- Do NOT use type aliases when a new distinct type is more appropriate.

---

## 11. Generics

- Use when they genuinely reduce duplication across concrete types.
- Do NOT use just because an algorithm is type-agnostic but only has one instantiation.
- Do NOT build DSLs or error-handling frameworks with generics.
- Prefer interfaces when types share a useful common contract.
- Document generic APIs thoroughly with runnable examples.

---

## 12. Global State

Avoid mutable package-level state. Problems:
- Makes testing hard (shared state between tests).
- Makes concurrency hard (race conditions).
- Creates implicit dependencies.

### If You Must

- Provide instance-based APIs alongside package-level convenience functions.
- Document concurrency safety.
- Package-level functions should be thin proxies to instance methods.
- Only binary targets (main packages) should use package-level state APIs.

### Safe Global State

Global state is acceptable when:
- It is logically constant (set once at init, never modified).
- The package behavior is stateless.
- The global state does not affect external systems.
- There is no expectation of predictable ordering.

---

## 13. Copying

### Safe to Copy

- Simple value types (int, string, bool)
- Structs with only value fields
- Types explicitly documented as safe to copy

### NOT Safe to Copy

- Types with unexported fields (unless documented safe)
- Types containing sync.Mutex or sync.WaitGroup
- Types containing channels

```go
// Acceptable:
var opts2 = opts1 // if Options is documented as safe to copy

// Usually wrong:
var mu2 = mu1     // sync.Mutex must not be copied
var wg2 = wg1     // sync.WaitGroup must not be copied
```

---

## 14. Logging

- Use structured logging where available.
- Do NOT log errors you are also returning (double-logging).
- Log at the point where the error is handled.
- Include context: operation, identifiers, relevant state.
- Use appropriate severity levels.

---

## 15. Flags and Configuration

- Use configuration structs over individual flags for complex configurations.
- Flags should have sensible defaults.
- Validate flag values early.
- Configuration should support dependency injection.
- Do NOT use global flag variables in library code.

---

## 16. Least Mechanism

Prefer solutions in this order:
1. Core language constructs (for, if, chan, map, slice, struct)
2. Standard library (net/http, encoding/json, etc.)
3. Well-established external packages
4. Custom solutions

Do NOT introduce sophisticated machinery without justification. Complexity is easy to add, hard to remove.

---

## 17. Shadowing

Be careful with := in nested scopes. It creates a NEW variable:

```go
// Bug: inner err shadows outer err
var err error
if condition {
    val, err := doSomething() // new err, outer err unchanged
    _ = val
}
// err is still nil here!

// Fix: declare val separately
var err error
if condition {
    var val int
    val, err = doSomething() // assigns to outer err
    _ = val
}
```

Do NOT shadow standard library package names:
```go
// Bad:
context := "some value"  // shadows context package
fmt := "formatted"       // shadows fmt package
```
