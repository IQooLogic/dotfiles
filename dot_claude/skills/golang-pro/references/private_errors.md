# Error Handling - Detailed Reference

Source: Google Go Style Decisions + Best Practices

## Table of Contents
1. Returning Errors
2. Error Strings
3. Handling Errors
4. Error Structure
5. Adding Information
6. Percent-v vs Percent-w
7. Error Flow
8. In-Band Errors
9. Do Not Panic
10. Must Functions
11. Error Logging
12. Program Init Errors

---

## 1. Returning Errors

- Error is always the last return value.
- Return the error interface, not concrete error types unless callers need errors.As.
- Use nil for success. Never return a non-nil error type with nil value (interface pitfall).

```go
func Lookup(key string) (Value, error) {
    if notFound {
        return Value{}, ErrNotFound
    }
    return val, nil
}
```

---

## 2. Error Strings

- Lowercase start (they get composed into chains).
- No trailing punctuation.
- No "failed to" or "error" or "unable to" prefix. The error context is already implied.
- Include relevant context: what operation, what identifier.

```go
// Good:
fmt.Errorf("connect to %s: %v", addr, err)
fmt.Errorf("parse config at %s: %v", path, err)

// Bad:
fmt.Errorf("Failed to connect to %s: %v.", addr, err)
fmt.Errorf("error reading file: %v", err)
```

---

## 3. Handling Errors

Every error return MUST be handled. Choose one:

1. Handle it: take corrective action and continue.
2. Return it: propagate to caller, optionally wrapping.
3. Fatal: call log.Fatal in main/init for unrecoverable startup errors.
4. Panic: only for impossible conditions (programming bugs).
5. Explicitly ignore: _ = f.Close() with documented reason only.

---

## 4. Error Structure

### Sentinel Errors

Use when callers must distinguish specific conditions:

```go
var (
    ErrNotFound  = errors.New("not found")
    ErrConflict  = errors.New("conflict")
    ErrForbidden = errors.New("forbidden")
)

// Caller uses errors.Is:
if errors.Is(err, ErrNotFound) {
    // handle not found
}
```

### Custom Error Types

Use when callers need structured data from the error:

```go
type ValidationError struct {
    Field   string
    Message string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation: %s: %s", e.Field, e.Message)
}

// Caller uses errors.As:
var ve *ValidationError
if errors.As(err, &ve) {
    log.Printf("invalid field %s: %s", ve.Field, ve.Message)
}
```

### Never String-Match Errors

```go
// Bad:
if strings.Contains(err.Error(), "not found") { ... }
if regexp.MatchString("duplicate", err.Error()) { ... }
```

---

## 5. Adding Information

Add context the underlying error does NOT already provide:

```go
// Good: adds new meaning
if err := os.Open("settings.txt"); err != nil {
    return fmt.Errorf("launch codes unavailable: %v", err)
}

// Bad: duplicates path info from os.Open
if err := os.Open("settings.txt"); err != nil {
    return fmt.Errorf("could not open settings.txt: %v", err)
}

// Bad: adds nothing
return fmt.Errorf("failed: %v", err) // just return err
```

---

## 6. Percent-v vs Percent-w

Use percent-v when:
- Adding context but hiding implementation details from callers.
- Translating errors across abstraction boundaries.
- The original error type/identity should NOT be inspectable.

Use percent-w when:
- Callers NEED errors.Is or errors.As on the wrapped error.
- The wrapped error is part of your documented API contract.

Place percent-w at the END of the format string:
```go
// Good:
return fmt.Errorf("read config %q: %w", path, err)

// Bad:
return fmt.Errorf("%w in %s", err, path)
```

---

## 7. Error Flow

The "line of sight" rule: happy path at the left edge, error path indented.

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

---

## 8. In-Band Errors

Avoid special return values to signal errors. Use a separate error return.

```go
// Bad:
func Lookup(key string) int { return -1 } // -1 means not found

// Good:
func Lookup(key string) (int, error) { return 0, ErrNotFound }
```

---

## 9. Do Not Panic

- Never panic for normal error handling.
- In main/init: prefer log.Exit or log.Fatal. Stack traces are noise for config errors.
- Panic only for "impossible" conditions that indicate programming bugs.

---

## 10. Must Functions

MustXYZ calls panic on error. Used exclusively for:
- Package-level variable initialization (var re = regexp.MustCompile(...))
- Program startup in main/init
- Test helpers (using t.Fatal instead of panic)

```go
// Good: package-level constant
var defaultVersion = MustParse("1.2.3")

// Good: test helper
func mustMarshal(t *testing.T, v any) []byte {
    t.Helper()
    data, err := json.Marshal(v)
    if err != nil {
        t.Fatalf("marshal %v: %v", v, err)
    }
    return data
}

// Bad: Must in request handler (panics on bad input)
func handleRequest(w http.ResponseWriter, r *http.Request) {
    data := MustReadBody(r)
}
```

---

## 11. Error Logging

- Log at the level that handles the error. If you return it, do NOT also log it.
- If you handle an error (do not propagate), log it.

```go
// Good: log at handling point only
if err := processOrder(ctx, orderID); err != nil {
    log.Errorf("processOrder(%s): %v", orderID, err)
}

// Bad: log AND return (double-logging)
if err := db.Query(ctx, q); err != nil {
    log.Errorf("query failed: %v", err)
    return fmt.Errorf("query: %v", err)
}
```

---

## 12. Program Init Errors

- In main: use log.Exit or log.Fatal for fatal startup errors.
- Validate configuration early: fail fast with clear messages.
- Do NOT use panic for config errors.

```go
func main() {
    cfg, err := loadConfig("app.yaml")
    if err != nil {
        log.Exitf("load config: %v", err)
    }
}
```
