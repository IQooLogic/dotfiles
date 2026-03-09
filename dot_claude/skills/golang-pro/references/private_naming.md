# Naming — Detailed Reference

Source: Google Go Style Decisions + Best Practices

## Table of Contents
1. Package Names
2. Receiver Names
3. Constant Names
4. Initialisms
5. Variable Names
6. Single-Letter Variables
7. Repetition Avoidance
8. Getters
9. Function and Method Names
10. Test Double Naming

---

## 1. Package Names

Package names must be concise, lowercase only, no underscores, no mixedCaps.

Avoid names likely to be shadowed by common variables: don't name a package `context`, `errors`, `flag`, etc.

**Allowed underscores:**
- Packages only imported by generated code may use underscores.
- `_test` suffix for external test packages (`package foo_test`).
- `_test` suffix for integration test packages.

**Import renaming:**
- Renamed imports must follow Go naming: `foopb` for `foo_go_proto`, not `foo_proto`.
- Use `pkgname` not `pkg_name`.

**Avoid these package names:** `util`, `utility`, `common`, `helper`, `base`, `misc`, `shared`.
Instead, name packages after what they *provide*: `imageutil` -> `resize`, `stringutil` -> `sanitize`.

### Package Size

- No single correct answer on size.
- Users see all exports in one godoc page — large packages with coherent APIs are fine.
- Code in a package can access unexported identifiers — use this to reduce API surface.
- Putting everything in one package is also bad: makes it hard to navigate.
- Files within a package can be any size; maintainers can reorganize freely.

---

## 2. Receiver Names

Receiver variables must be:
- Short (one or two letters)
- Abbreviation of the type itself
- Applied consistently to EVERY receiver for that type

| Long Name | Better Name |
|-----------|-------------|
| `func (tray Tray)` | `func (t Tray)` |
| `func (info *ResearchInfo)` | `func (ri *ResearchInfo)` |
| `func (this *Report498)` | `func (r *Report498)` |
| `func (self *Formatter)` | `func (f *Formatter)` |

Never use `self`, `this`, or `me`.

---

## 3. Constant Names

- Use MixedCaps like all other Go names.
- Exported: `MaxRetries`, unexported: `maxRetries`.
- Never: `MAX_RETRIES`, `kMaxRetries`.

Name based on role, not value:
```go
// Good:
const MaxPacketSize = 512
const (
    ExecuteBit = 1 << iota
    WriteBit
    ReadBit
)

// Bad:
const Twelve = 12   // meaningless name
const K = 1 << 10   // unclear role
```

If a constant has no meaningful role beyond its value, use the value directly — don't create a named constant.

---

## 4. Initialisms

Initialisms and acronyms are ALL CAPS or all lowercase. Never mixed.

| English | Exported | Unexported |
|---------|----------|------------|
| XML API | `XMLAPI` | `xmlAPI` |
| iOS | `IOS` | `iOS` is acceptable for unexported |
| gRPC | `GRPC` | `gRPC` |
| DDoS | `DDoS` | `ddos` |
| ID | `ID` | `id` |
| DB | `DB` | `db` |
| Txn | `Txn` | `txn` (not `TXN`) |
| URL | `URL` | `url` |
| HTTP | `HTTP` | `http` |

"Txn" is a conventional abbreviation, not an initialism, so: `Txn` not `TXN`.

---

## 5. Variable Names

General principles:
- Short names for small scopes, longer names for larger scopes.
- `userCount` is better than `numUsers` or `nUsers` for quantities.
- `users` is better than `usrSlice` — don't encode type in the name.
- A boolean should read naturally: `ok`, `found`, `valid`, `done`, `hasPrefix`.

### Scope Guidelines

- **1-line scope:** single letter is fine (`i`, `v`, `k`)
- **Few lines:** short abbreviated name (`buf`, `ctx`, `msg`)
- **Broader scope:** descriptive name (`userCount`, `requestTimeout`)
- **Package level:** very descriptive (`DefaultMaxIdleConns`)

---

## 6. Single-Letter Variable Names

Acceptable when:
- The scope is very small (a few lines).
- The convention is well-established.

Common conventions:
- `i`, `j`, `k` — loop indices
- `r` — `io.Reader`
- `w` — `io.Writer`
- `b` — `[]byte` or `byte`
- `n` — count or length
- `v` — generic value
- `k` — map key
- `ctx` — `context.Context` (three letters, but conventional)
- `err` — error
- `ok` — boolean from comma-ok

Avoid single-letter names:
- For function parameters that are the sole purpose of the function.
- When the type isn't obvious from context.
- When multiple variables of similar type exist (use descriptive names).

---

## 7. Repetition Avoidance

### Package vs. Export

The package name is part of every call site. Don't repeat it:

| Repetitive | Better |
|-----------|--------|
| `widget.NewWidget` | `widget.New` |
| `widget.WidgetColor` | `widget.Color` |
| `db.DBWrite` | `db.Write` |
| `goatteleportation.GoatTeleworker` | `goatteleportation.Worker` |

### Variable vs. Type

Don't repeat the type name in the variable:

| Repetitive | Better |
|-----------|--------|
| `var numUsers int` | `var userCount int` |
| `var nameString string` | `var name string` |
| `var primaryProject *Project` | `var primary *Project` |

### Method Receiver

Don't repeat the receiver type in method names:

| Repetitive | Better |
|-----------|--------|
| `s.ServerStart()` | `s.Start()` |
| `c.ClientSend()` | `c.Send()` |

---

## 8. Getters

- No `Get` prefix: use `s.Count()`, not `s.GetCount()`.
- Exception: the field name itself would be a keyword or would collide.
- Exception: protocol buffer getters use `Get` by convention.

---

## 9. Function and Method Names

### Naming Conventions

- Functions returning something: noun-like names (`time.Now()`, `os.Hostname()`).
- Functions doing something: verb-like names (`fmt.Print()`, `sort.Sort()`).
- Functions differing by type include the type: `ParseInt`, `ParseFloat`.
- If there's a clear "primary" version, omit the type: `Parse` + `ParseFloat`.

### Avoid in Function Names

- The types of inputs/outputs (when unambiguous from signature)
- The receiver type for methods
- Whether an input/output is a pointer

```go
// Bad:
func (s *Server) HandleHTTPGETRequest(r *http.Request) // too much info in name

// Good:
func (s *Server) Handle(r *http.Request)               // context makes it clear
```

---

## 10. Test Double and Helper Packages

For a production package `creditcard`, the test helper package is `creditcardtest`.

Structure:
```
creditcard/
    creditcard.go          // Production code
    creditcardtest/
        creditcardtest.go  // Test doubles
```

Naming test doubles:
- Simple case (one double): `creditcardtest.StubService`
- Multiple behaviors: `creditcardtest.AlwaysCharges`, `creditcardtest.AlwaysDeclines`
- Multiple types: `creditcardtest.StubService`, `creditcardtest.StubManager`

In test code, prefix variables to distinguish doubles from real values:
```go
// Good:
spyCC := creditcardtest.Spy(t)  // clearly a double
normalCC := creditcard.New()     // clearly real
```
