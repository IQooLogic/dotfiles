# Code Style

Go only. These rules are non-negotiable defaults. Override in a project CLAUDE.md only
when there is a concrete technical reason — not preference.

---

## Core Principles

- **Explicit over clever.** If it needs a comment to be understood, rewrite it.
- **Fail loudly.** No silent error suppression. Every error is logged, returned, or both.
- **Stdlib first.** Add a dependency only when the stdlib alternative is genuinely insufficient.
  Justify new dependencies in a comment or ADR.
- **Production-ready from the start.** No "we'll fix this later" shortcuts in committed code.
- **Single responsibility.** If you can't name a function without using "and", split it.

---

## Error Handling

Always wrap with context. The error string must form a readable chain from origin to caller.

```go
// GOOD
if err := store.Save(ctx, record); err != nil {
    return fmt.Errorf("handler: save record %s: %w", record.ID, err)
}

// BAD — no context, no wrapping
if err != nil {
    return err
}

// BAD — silent suppression
_ = store.Save(ctx, record)
```

**Rules:**
- Wrap with `fmt.Errorf("component: action: %w", err)` — colon-separated, lowercase
- Never use `errors.New` for wrapped errors; always `%w` to preserve the chain
- `errors.Is` / `errors.As` for inspection at call sites — never string matching
- Sentinel errors: `var ErrNotFound = errors.New("not found")` — exported, at package level
- Custom error types only when callers need to inspect structured fields

---

## Logging

Use `log/slog` exclusively. No `fmt.Println`, no `log.Printf`, no third-party loggers.

```go
// GOOD
slog.Error("failed to save record", "id", record.ID, "err", err)
slog.Info("server starting", "addr", addr, "env", cfg.Env)

// BAD
log.Printf("failed to save: %v", err)
fmt.Println("server starting on", addr)
```

**Rules:**
- Pass logger via `context.Context` or explicit struct field — never global logger in libraries
- Key names: lowercase, hyphen-separated (`request-id`, not `requestId` or `RequestID`)
- Always include `"err", err` as the last key pair on error logs
- Debug logs are free — use them; strip them before PR only if they're noise
- No log-and-return: either log at the boundary or return the error — not both

---

## Testing

Table-driven tests with `t.Run`. Every new package gets a `_test.go` file.

```go
func TestSave(t *testing.T) {
    tests := []struct {
        name    string
        input   Record
        wantErr bool
    }{
        {
            name:  "valid record",
            input: Record{ID: "abc", Value: "x"},
        },
        {
            name:    "empty ID",
            input:   Record{Value: "x"},
            wantErr: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := store.Save(context.Background(), tt.input)
            if (err != nil) != tt.wantErr {
                t.Errorf("Save() error = %v, wantErr %v", err, tt.wantErr)
            }
        })
    }
}
```

**Rules:**
- Hand-written mocks only — no `mockgen`, no `testify/mock`
- Mocks live in `internal/testutil/` or alongside the interface they implement (`_mock_test.go`)
- `t.Helper()` in every test helper function
- No `testify/assert` — use stdlib `t.Errorf` / `t.Fatalf`
- Race detector on all test runs: `go test -race ./...`
- Tests must be deterministic — no `time.Sleep`, seed random sources explicitly

**Mock pattern:**
```go
type mockStore struct {
    saveFn func(ctx context.Context, r Record) error
}

func (m *mockStore) Save(ctx context.Context, r Record) error {
    if m.saveFn != nil {
        return m.saveFn(ctx, r)
    }
    return nil
}
```

---

## Package Structure

```
cmd/
  <binary>/
    main.go          # wires dependencies, starts process — no business logic
internal/
  <domain>/          # one package per bounded concern
    <domain>.go      # primary types and interface definitions
    <domain>_test.go
  testutil/          # shared test helpers and mocks
pkg/                 # exported packages safe for external use (rare — prefer internal)
```

**Rules:**
- `cmd/<binary>/main.go` wires and starts — no logic, no direct DB calls
- Business logic lives in `internal/` — never in `main.go`
- Circular imports are a design failure, not a Go limitation to work around
- Avoid `util`, `helpers`, `common` package names — name by what the package does
- One package per directory — no exceptions

---

## Interfaces

Define interfaces at the point of use, not the point of implementation.

```go
// GOOD — consumer defines what it needs
// internal/worker/worker.go
type alertStore interface {
    Save(ctx context.Context, a Alert) error
    FindByID(ctx context.Context, id string) (Alert, error)
}

// BAD — implementation defines interface in its own package, forces import
// internal/store/store.go
type Store interface { ... }
```

**Rules:**
- Keep interfaces small — prefer single-method interfaces where possible
- Accept interfaces, return concrete types
- Name single-method interfaces with `-er` suffix: `Saver`, `Fetcher`, `Runner`
- Do not export interfaces from `internal/` packages unless they are explicitly shared contracts

---

## Concurrency

```go
// GOOD — explicit ownership, cancel propagated
ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
defer cancel()

var wg sync.WaitGroup
errCh := make(chan error, workers)

for i := range jobs {
    wg.Add(1)
    go func(j Job) {
        defer wg.Done()
        if err := process(ctx, j); err != nil {
            errCh <- err
        }
    }(jobs[i])
}

wg.Wait()
close(errCh)
```

**Rules:**
- Every goroutine has a clear owner responsible for its lifetime
- Always propagate `context.Context` — never use `context.Background()` deep in the stack
- Channel directions in function signatures: `chan<-` send-only, `<-chan` receive-only
- `sync.Mutex` fields are not exported and not embedded
- `defer cancel()` immediately after every `context.With*` call — no exceptions
- Data races are blocking failures — never merge code with detected races

---

## Naming

| Thing | Convention | Example |
|-------|-----------|---------|
| Package | lowercase, single word | `worker`, `fingerprint` |
| Interface | noun or `-er` suffix | `Store`, `Fetcher` |
| Error var | `Err` prefix | `ErrNotFound`, `ErrTimeout` |
| Constructor | `New<Type>` | `NewWorker`, `NewStore` |
| Config struct | `Config` | — |
| Test helper | verb phrase | `mustDial`, `newTestServer` |
| Context key | unexported type | `type ctxKey struct{}` |

- Acronyms follow Go convention: `userID`, `httpClient`, `tlsConfig` — not `userId`, `HTTPclient`
- Avoid redundant package prefixes: `store.Store` is `store.DB` or just `store.Store` — never `store.StoreStore`
- Single-letter vars only in tight loops and short closures — `i`, `k`, `v` are fine, `x` is not

---

## Dependencies

```go
// Evaluate in this order before adding a dependency:
// 1. Does stdlib cover it?
// 2. Can it be implemented in <50 lines?
// 3. Is the dependency actively maintained with a stable API?
// 4. Does it pull in transitive deps that outweigh its value?
```

**Approved patterns (no justification needed):**
- `github.com/jackc/pgx/v5` for PostgreSQL
- `github.com/prometheus/client_golang` for metrics
- `golang.org/x/...` packages (treated as extended stdlib)

**Requires justification (comment or ADR):**
- Any web framework (`gin`, `chi`, `fiber`, etc.) — stdlib `net/http` is usually sufficient
- ORMs — prefer raw SQL with `pgx`
- Any dependency with >10 transitive imports

---

## HTTP

Use `net/http` directly. No framework unless the project CLAUDE.md explicitly specifies one.

```go
mux := http.NewServeMux()
mux.HandleFunc("GET /api/v1/alerts", h.listAlerts)

srv := &http.Server{
    Addr:         cfg.Addr,
    Handler:      mux,
    ReadTimeout:  5 * time.Second,
    WriteTimeout: 10 * time.Second,
    IdleTimeout:  60 * time.Second,
}
```

**Rules:**
- Always set `ReadTimeout`, `WriteTimeout`, `IdleTimeout` — never use zero values
- Return structured JSON errors: `{"error": "message"}` with appropriate HTTP status
- Middleware as `func(http.Handler) http.Handler` — no framework-specific middleware types
- Handler functions return nothing — write to `w`, log errors, do not panic

---

## Configuration

```go
type Config struct {
    Addr     string        `env:"ADDR"      envDefault:":8080"`
    DSN      string        `env:"DSN"       required:"true"`
    Timeout  time.Duration `env:"TIMEOUT"   envDefault:"30s"`
}
```

**Rules:**
- Config from environment variables — no config files in production unless the format is
  inherently hierarchical (e.g. YAML for complex ML pipeline configs)
- Validate config at startup — fail fast with a clear message before accepting traffic
- Never embed secrets in structs beyond their initial load; clear after use where possible
- `required:"true"` on anything that has no sane default

---

## Build and Deployment

```dockerfile
# Build stage
FROM golang:1.24-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /bin/app ./cmd/app

# Final stage
FROM gcr.io/distroless/static-debian12
COPY --from=builder /bin/app /app
ENTRYPOINT ["/app"]
```

**Rules:**
- Distroless final image — no shell, no package manager, minimal attack surface
- `CGO_ENABLED=0` for static binaries unless CGO is explicitly required (e.g. `-race`)
- `-trimpath -ldflags="-s -w"` for all production builds
- Single binary per `cmd/` entry point — no side-car scripts
- Health check endpoint at `/healthz` — returns `200 OK` when ready

---

## What Never To Do

- `_ = someFunc()` — if you're discarding an error, document why with a comment
- `log.Fatal` outside of `main()` — callers cannot recover or clean up
- `os.Exit` outside of `main()` — same reason
- Naked `recover()` — if you recover, you must log what you caught and why
- `interface{}` / `any` as a lazy escape hatch — use generics or a concrete type
- Storing `context.Context` in a struct — pass it as a function parameter
- `init()` with side effects — initialise explicitly in `main()` or constructors
- Package-level mutable vars as implicit global state — inject dependencies
- Committing commented-out code — delete it; git has history
