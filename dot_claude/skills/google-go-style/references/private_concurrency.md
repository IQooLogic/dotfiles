# Concurrency - Detailed Reference

Source: Google Go Style Guide + Decisions + Best Practices

## Table of Contents
1. Goroutine Lifecycle Management
2. Synchronous by Default
3. WaitGroup Patterns
4. Context and Cancellation
5. Channel Patterns
6. Mutex and Shared State
7. errgroup
8. Common Concurrency Bugs
9. Testing Concurrent Code
10. Concurrency and Global State

---

## 1. Goroutine Lifecycle Management

This is the single most important concurrency rule in the Google style guide:
**When you spawn a goroutine, make it clear when and whether it exits.**

Goroutines can leak by blocking on channel sends or receives. The garbage
collector will NOT terminate a goroutine blocked on a channel even if no other
goroutine has a reference to the channel. Even when goroutines do not leak,
leaving them in-flight causes subtle problems: data races from modifying
still-in-use inputs, unpredictable memory usage, and panics from sending on
closed channels.

```go
// Good: goroutine lifecycle is explicit and bounded
func (w *Worker) Run(ctx context.Context) error {
    var wg sync.WaitGroup
    for item := range w.queue {
        wg.Add(1)
        go func() {
            defer wg.Done()
            // process returns at latest when context is cancelled
            w.process(ctx, item)
        }()
    }
    wg.Wait() // Prevent spawned goroutines from outliving this function
    return nil
}

// Bad: no lifecycle management at all
func (w *Worker) Run() {
    for item := range w.queue {
        go w.process(item) // When does this stop? What if process blocks forever?
    }
}
```

Problems with the bad example:
- Undefined behavior in production; program may not terminate cleanly.
- Difficult to test meaningfully due to indeterminate lifecycle.
- May leak resources (goroutines, file descriptors, connections).

### Rules

- Every `go` statement must have a corresponding mechanism that bounds its lifetime.
- Use `context.Context` for cancellation signaling.
- Use `sync.WaitGroup` to wait for completion.
- Use `chan struct{}` as a done/quit signal when contexts are not appropriate.
- Document the exit condition in a comment if not immediately obvious.

---

## 2. Synchronous by Default

Prefer synchronous functions. Let the caller decide on concurrency.

```go
// Good: synchronous - caller wraps in goroutine if needed
func (s *Store) Save(ctx context.Context, item Item) error {
    return s.db.Insert(ctx, item)
}

// Bad: internally spawns goroutine without lifecycle control
func (s *Store) Save(item Item) {
    go func() {
        s.db.Insert(context.Background(), item) // leaked goroutine, no error handling
    }()
}
```

Why synchronous is better:
- Caller has full control over error handling.
- Caller can compose with their own concurrency patterns.
- Testing is straightforward (no race conditions in tests).
- Resource cleanup is deterministic.

If a function MUST manage goroutines internally (e.g., a long-running server loop),
document the lifecycle clearly and provide a shutdown mechanism.

---

## 3. WaitGroup Patterns

### Basic Fan-Out

```go
func processAll(ctx context.Context, items []Item) error {
    var wg sync.WaitGroup
    for _, item := range items {
        wg.Add(1)
        go func() {
            defer wg.Done()
            process(ctx, item)
        }()
    }
    wg.Wait()
    return nil
}
```

### Bounded Concurrency with Semaphore

```go
func processAll(ctx context.Context, items []Item, maxConcurrent int) error {
    sem := make(chan struct{}, maxConcurrent)
    var wg sync.WaitGroup

    for _, item := range items {
        wg.Add(1)
        sem <- struct{}{} // acquire semaphore slot
        go func() {
            defer wg.Done()
            defer func() { <-sem }() // release slot
            process(ctx, item)
        }()
    }
    wg.Wait()
    return nil
}
```

### Rules

- Call `wg.Add(1)` BEFORE the `go` statement, never inside the goroutine.
- Always `defer wg.Done()` as the first statement in the goroutine.
- Never copy a WaitGroup after first use.

---

## 4. Context and Cancellation

Context is the standard mechanism for cancellation, deadlines, and request-scoped values.

### Rules (from the Context section of the style guide)

- `context.Context` is ALWAYS the first parameter.
- Never store contexts in structs.
- Never pass nil context. Use `context.TODO()` if genuinely unsure.
- Only `main`, `init`, and top-level test functions may create root contexts
  (`context.Background()`).
- Library code always accepts context from the caller.

### Cancellation Pattern

```go
func (s *Server) Run(ctx context.Context) error {
    for {
        select {
        case <-ctx.Done():
            return ctx.Err()
        case conn := <-s.incoming:
            go s.handleConn(ctx, conn)
        }
    }
}
```

### Timeout Pattern

```go
func fetchWithTimeout(ctx context.Context, url string) ([]byte, error) {
    ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
    defer cancel() // ALWAYS defer cancel to release resources

    req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
    if err != nil {
        return nil, fmt.Errorf("create request: %v", err)
    }
    // ...
}
```

### Custom Context Values

Never create custom context types. Use context.WithValue with unexported key types:

```go
// Good: unexported key type prevents collisions
type userIDKey struct{}

func WithUserID(ctx context.Context, id string) context.Context {
    return context.WithValue(ctx, userIDKey{}, id)
}

func UserID(ctx context.Context) (string, bool) {
    id, ok := ctx.Value(userIDKey{}).(string)
    return id, ok
}

// Bad: string keys can collide across packages
ctx = context.WithValue(ctx, "userID", id)
```

---

## 5. Channel Patterns

### Signaling Done

```go
done := make(chan struct{})
go func() {
    defer close(done)
    // ... do work ...
}()
<-done // wait for goroutine to finish
```

### Fan-Out / Fan-In

```go
func fanOut(ctx context.Context, input <-chan Item, workers int) <-chan Result {
    results := make(chan Result)
    var wg sync.WaitGroup

    for i := 0; i < workers; i++ {
        wg.Add(1)
        go func() {
            defer wg.Done()
            for item := range input {
                select {
                case <-ctx.Done():
                    return
                case results <- process(item):
                }
            }
        }()
    }

    go func() {
        wg.Wait()
        close(results)
    }()

    return results
}
```

### Critical Channel Safety Rules

- Sending on a closed channel panics.
- Only the sender should close a channel (never the receiver).
- Closing a nil channel panics.
- Receiving from a nil channel blocks forever.
- Receiving from a closed channel returns the zero value immediately.

### Buffered vs Unbuffered

- Unbuffered (`make(chan T)`): synchronization point. Sender blocks until receiver ready.
- Buffered (`make(chan T, n)`): decouples sender/receiver up to buffer size.
- Use buffered channels as semaphores for bounding concurrency.
- Default to unbuffered unless you have a specific reason for buffering.

---

## 6. Mutex and Shared State

### When to Use Mutex (vs Channel)

Use sync.Mutex for:
- Protecting struct fields from concurrent access.
- Caches, counters, maps read/written by multiple goroutines.
- Any shared state that does not involve transferring ownership.

```go
type Cache struct {
    mu    sync.RWMutex
    items map[string]Item
}

func (c *Cache) Get(key string) (Item, bool) {
    c.mu.RLock()
    defer c.mu.RUnlock()
    item, ok := c.items[key]
    return item, ok
}

func (c *Cache) Set(key string, item Item) {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.items[key] = item
}
```

### Rules

- Place the mutex ABOVE the fields it protects, with a comment:

```go
type Server struct {
    // mu protects the fields below.
    mu       sync.Mutex
    clients  map[string]*Client
    shutdown bool
}
```

- Never copy a mutex after first use (types with mutexes need pointer receivers).
- Use sync.RWMutex when reads vastly outnumber writes.
- Always use `defer mu.Unlock()` unless you have a measured performance reason.
- Never hold a lock while doing I/O or calling external functions if avoidable.

### sync.Once

For one-time initialization:

```go
type Client struct {
    initOnce sync.Once
    conn     *grpc.ClientConn
}

func (c *Client) getConn() *grpc.ClientConn {
    c.initOnce.Do(func() {
        c.conn = dial() // called exactly once, even from multiple goroutines
    })
    return c.conn
}
```

### sync.Map

- Use sync.Map ONLY when keys are stable (mostly read, rare writes) or when
  goroutines access disjoint key sets.
- For everything else, sync.RWMutex + regular map is clearer and often faster.

---

## 7. errgroup

`golang.org/x/sync/errgroup` is the standard tool for running a group of
goroutines and collecting the first error.

### Basic Usage

```go
func fetchAll(ctx context.Context, urls []string) ([]Response, error) {
    g, ctx := errgroup.WithContext(ctx)
    responses := make([]Response, len(urls))

    for i, url := range urls {
        g.Go(func() error {
            resp, err := fetch(ctx, url)
            if err != nil {
                return fmt.Errorf("fetch %s: %w", url, err)
            }
            responses[i] = resp // safe: each goroutine writes to own index
            return nil
        })
    }

    if err := g.Wait(); err != nil {
        return nil, err
    }
    return responses, nil
}
```

### Key Behaviors

- errgroup.WithContext returns a derived context cancelled when ANY goroutine
  returns a non-nil error.
- g.Wait() blocks until all goroutines complete and returns the first error.
- Use g.SetLimit(n) to bound concurrency (Go 1.20+).

### With Concurrency Limit

```go
g, ctx := errgroup.WithContext(ctx)
g.SetLimit(10) // max 10 concurrent goroutines

for _, item := range items {
    g.Go(func() error {
        return process(ctx, item)
    })
}

if err := g.Wait(); err != nil {
    return err
}
```

---

## 8. Common Concurrency Bugs

### Loop Variable Capture (pre-Go 1.22)

In Go versions before 1.22, loop variables are shared across iterations:

```go
// Bug (Go < 1.22): all goroutines see the last value of item
for _, item := range items {
    go func() {
        process(item) // item is the loop variable, not a copy
    }()
}

// Fix for Go < 1.22: shadow the variable
for _, item := range items {
    item := item // new variable per iteration
    go func() {
        process(item)
    }()
}
```

Go 1.22+ changed loop variable scoping so each iteration creates a new variable.
If your code must support older Go versions, always shadow.

### Data Race on Map

Maps are NOT safe for concurrent use:

```go
// Bug: concurrent map read/write panics at runtime
var m = map[string]int{}
go func() { m["a"] = 1 }()
go func() { _ = m["a"] }()

// Fix: protect with mutex or use sync.Map
```

### Goroutine Leak via Unbuffered Channel

```go
// Bug: if nobody reads from ch, the goroutine leaks forever
ch := make(chan Result)
go func() {
    ch <- expensiveComputation() // blocks forever if nobody receives
}()

// Fix: use buffered channel of size 1
ch := make(chan Result, 1)
go func() {
    ch <- expensiveComputation() // can always send even if nobody receives yet
}()
```

### Defer in a Loop

```go
// Bug: defers run at function return, not loop iteration end
for _, f := range files {
    fd, err := os.Open(f)
    if err != nil { ... }
    defer fd.Close() // all files stay open until function returns!
}

// Fix: wrap in a function
for _, f := range files {
    if err := processFile(f); err != nil { ... }
}

func processFile(path string) error {
    fd, err := os.Open(path)
    if err != nil { return err }
    defer fd.Close()
    // ...
}
```

### Sending on Closed Channel

```go
// Bug: panics at runtime
ch := make(chan int)
ch <- 42
close(ch)
ch <- 13 // panic: send on closed channel

// Rule: only the sender closes. Close exactly once.
// Use sync.Once if multiple goroutines might close.
```

---

## 9. Testing Concurrent Code

### Race Detector

Always run tests with -race:
```bash
go test -race ./...
```

The race detector catches data races at runtime. All CI should include this.

### Testing Goroutine Cleanup

Verify goroutines do not leak using goleak:
```go
func TestMain(m *testing.M) {
    goleak.VerifyTestMain(m)
}
```

### Avoiding Flaky Tests

- Do NOT use time.Sleep for synchronization in tests.
- Use channels, WaitGroups, or condition variables to synchronize.
- If testing timeouts, use short but realistic durations and context deadlines.
- Use t.Parallel() only when subtests are truly independent.

```go
// Bad: flaky timing-based test
go doWork()
time.Sleep(100 * time.Millisecond) // hope it finished?
checkResult()

// Good: explicit synchronization
done := make(chan struct{})
go func() {
    defer close(done)
    doWork()
}()
<-done
checkResult()
```

---

## 10. Concurrency and Global State

Global mutable state is the enemy of safe concurrency:

- Package-level variables accessed by multiple goroutines cause data races.
- Global registries (Register/Lookup patterns) create implicit ordering.
- Singletons make testing hard because tests cannot run in parallel.

### Rules

- Prefer dependency injection: pass dependencies as parameters.
- If global state is unavoidable, protect with sync.Mutex or sync.RWMutex.
- Document concurrency safety of all exported types.
- Never use init() for registering global state that tests need to override.

### Safe Exception

Global state is acceptable when ALL of the following hold:
- Logically constant (set once during init, never modified after).
- Package behavior is stateless and idempotent.
- Does not affect external systems.
- No test would ever need to swap or override it.

Example: image.RegisterFormat is acceptable because decoders are stateless,
immutable, and additive.
