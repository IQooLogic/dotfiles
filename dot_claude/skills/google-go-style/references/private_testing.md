# Testing - Detailed Reference

Source: Google Go Style Decisions + Best Practices

## Table of Contents
1. Test Failure Messages
2. Assertion Libraries
3. Table-Driven Tests
4. Subtests
5. Test Helpers
6. Test Packages
7. Equality and Diffs
8. Test Error Semantics
9. Data-Driven Tests
10. Test Organization

---

## 1. Test Failure Messages

Every test failure must include:
- What function was called
- What inputs were provided
- The actual result
- The expected result

Standard format: `YourFunc(input) = got, want expected`

```go
// Good:
if got := SplitHostPort(test.input); got != test.want {
    t.Errorf("SplitHostPort(%q) = %q, want %q", test.input, got, test.want)
}
```

Rules:
- "Got" always comes before "want" in the message.
- Use %q for strings (shows quotes, escapes special chars).
- Use %v for general values.
- Use %+v for structs when field names help.
- For complex structs, prefer printing a diff over the full value.

---

## 2. Assertion Libraries

Do NOT use third-party assertion libraries (testify, gocheck, etc.). Reasons:
- They produce less useful failure messages.
- They obscure the actual comparison logic.
- They create API surface to learn.
- They can mask what is actually being tested.

Use the standard pattern:
```go
if got != want {
    t.Errorf("Func() = %v, want %v", got, want)
}
```

For complex comparisons, use google/go-cmp:
```go
if diff := cmp.Diff(want, got); diff != "" {
    t.Errorf("Func() mismatch (-want +got):\n%s", diff)
}
```

---

## 3. Table-Driven Tests

Use table-driven tests when many cases share similar structure:

```go
func TestSplitHostPort(t *testing.T) {
    tests := []struct {
        name     string
        input    string
        wantHost string
        wantPort string
    }{
        {
            name:     "with port",
            input:    "example.com:80",
            wantHost: "example.com",
            wantPort: "80",
        },
        {
            name:     "ipv6 with port",
            input:    "[::1]:80",
            wantHost: "::1",
            wantPort: "80",
        },
        {
            name:  "missing port",
            input: "example.com",
            // wantHost and wantPort are zero values
        },
    }
    for _, tc := range tests {
        t.Run(tc.name, func(t *testing.T) {
            gotHost, gotPort := SplitHostPort(tc.input)
            if gotHost != tc.wantHost || gotPort != tc.wantPort {
                t.Errorf("SplitHostPort(%q) = (%q, %q), want (%q, %q)",
                    tc.input, gotHost, gotPort, tc.wantHost, tc.wantPort)
            }
        })
    }
}
```

### Field Naming

- Prefix expected values with `want`: `wantErr`, `wantResult`.
- Use `name` or `desc` for subtest identification.
- Use zero-value omission for default/success cases.

### When NOT to Use Tables

- When test cases need fundamentally different setup or assertions.
- When the table row logic becomes as complex as individual tests.
- When only 1-2 cases exist.

---

## 4. Subtests

### Independence

Each subtest MUST be independent:
- No shared mutable state between subtests.
- No ordering dependencies.
- Must work with -run flag targeting individual subtests.
- Must work with t.Parallel().

### Naming

Subtest names should be:
- Readable in test output.
- Useful on the command line for -run filtering.
- Short but descriptive.

```go
// Good:
t.Run("with port", func(t *testing.T) { ... })
t.Run("ipv6 with port", func(t *testing.T) { ... })

// Bad:
t.Run("test case 1", func(t *testing.T) { ... })
```

Avoid slashes in subtest names - they interact poorly with -run flag. The test runner replaces spaces with underscores.

If a test needs a longer description, put it in the test struct and print it on failure, but keep the subtest name short.

---

## 5. Test Helpers

A test helper performs setup or cleanup. It is NOT an assertion function.

Rules:
- Always call t.Helper() at the start.
- Failures in helpers report the caller's line, not the helper's.
- Helpers should call t.Fatal for setup failures, not return errors.
- Do NOT use helpers to hide the connection between a test failure and the code being tested.

```go
// Good: test helper for setup
func setupTestDB(t *testing.T) *sql.DB {
    t.Helper()
    db, err := sql.Open("sqlite3", ":memory:")
    if err != nil {
        t.Fatalf("open test db: %v", err)
    }
    t.Cleanup(func() { db.Close() })
    return db
}

// Bad: assertion helper (obscures what's being tested)
func assertNoError(t *testing.T, err error) {
    t.Helper()
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
}
```

---

## 6. Test Packages

### Same Package (package foo)

Use when:
- Testing unexported functions/methods.
- Testing internal state or behavior.
- The test file is `foo_test.go` with `package foo`.

```go
// foo_test.go
package foo

func TestInternalParse(t *testing.T) {
    // Can access unexported internalParse
    got := internalParse("input")
    // ...
}
```

### External Package (package foo_test)

Use when:
- Testing the public API only (black-box).
- Avoiding circular dependencies.
- Integration tests that span multiple packages.

```go
// foo_test.go
package foo_test

import "mymodule/foo"

func TestPublicAPI(t *testing.T) {
    got := foo.Parse("input")
    // ...
}
```

### Integration Test Packages

If an integration test does not belong to a single library, create a separate test package.

---

## 7. Equality and Diffs

### Simple Values

Use == for scalar types (numbers, booleans, strings):
```go
if got != want {
    t.Errorf("Func() = %v, want %v", got, want)
}
```

### Complex Structures

Use google/go-cmp for structs, slices, maps:
```go
import "github.com/google/go-cmp/cmp"

if diff := cmp.Diff(want, got); diff != "" {
    t.Errorf("Func() mismatch (-want +got):\n%s", diff)
}
```

Convention: `-want +got` in diff output. Be consistent.

### Approximate Comparisons

Use cmp.Options for float comparison, time tolerances, etc.:
```go
opt := cmp.Comparer(func(x, y float64) bool {
    return math.Abs(x-y) < 0.001
})
if diff := cmp.Diff(want, got, opt); diff != "" {
    t.Errorf("mismatch (-want +got):\n%s", diff)
}
```

### Compare Stable Results

Do NOT compare against output that depends on serialization order or formatting of external packages. Parse the output first, then compare structured data.

```go
// Bad: depends on JSON key ordering
if got := MarshalJSON(obj); got != `{"a":1,"b":2}` { ... }

// Good: parse and compare structurally
var got MyStruct
json.Unmarshal(MarshalJSON(obj), &got)
if diff := cmp.Diff(want, got); diff != "" { ... }
```

---

## 8. Test Error Semantics

- Use errors.Is / errors.As to check error conditions, not string matching.
- When you only care that an error occurred (not which one), just check `err != nil`.
- String comparison of errors is acceptable ONLY when checking human-readable messages, not for programmatic control flow.

```go
// Good: check error type
if !errors.Is(err, os.ErrNotExist) {
    t.Errorf("Open() = %v, want os.ErrNotExist", err)
}

// Good: just check non-nil
if err == nil {
    t.Error("Open() succeeded, want error")
}

// Bad: string matching for control flow
if !strings.Contains(err.Error(), "permission denied") { ... }
```

---

## 9. Data-Driven Tests

When table rows become complex, keep the data declarative and the logic in the test body:

```go
// Good: data is declarative
tests := []struct {
    name  string
    input Config
    want  Result
}{
    {name: "defaults", input: Config{}, want: defaultResult},
    {name: "custom port", input: Config{Port: 8080}, want: customResult},
}

// Bad: logic in table rows (hard to read)
tests := []struct {
    name    string
    input   Config
    setup   func()
    check   func(t *testing.T, r Result)
}{...}
```

---

## 10. Test Organization

### Keep Going

Tests should continue after a failure when possible to report all issues:
```go
// Good: use t.Errorf (non-fatal) to report and continue
for _, tc := range tests {
    t.Run(tc.name, func(t *testing.T) {
        got := Func(tc.input)
        if got != tc.want {
            t.Errorf("Func(%v) = %v, want %v", tc.input, got, tc.want)
        }
    })
}

// Use t.Fatalf only when subsequent assertions depend on this one
```

### Identifying Table Rows

Never use array index as the identifier:
```go
// Bad:
for i, tc := range tests {
    t.Run(fmt.Sprintf("case_%d", i), ...)
}

// Good:
for _, tc := range tests {
    t.Run(tc.name, ...)
}
```

### Use Standard Testing Package

Do NOT use third-party testing frameworks. The standard `testing` package provides:
- Top-level tests, benchmarks, fuzz tests
- Subtests via t.Run
- Logging via t.Log
- Failures via t.Error/t.Fatal
- Cleanup via t.Cleanup
- Helpers via t.Helper
