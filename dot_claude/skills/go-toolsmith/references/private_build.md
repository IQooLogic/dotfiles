# go-toolsmith: Build Reference

Reference for constructing Go source-code tools. Read the section for your chosen layer only.

**Table of Contents**
- [Decision Tree](#decision-tree)
- [§GoFix — built-in migrations](#gofix)
- [§Codegen — x/tools commands](#codegen)
- [§AST — raw manipulation](#ast)
- [§Analysis — go/analysis framework](#analysis)
  - [§Analyzer Testing](#analyzer-testing)
- [§Packages — go/packages loader](#packages)
- [§Pitfalls](#pitfalls)
- [§Recipes](#recipes)
- [§Imports Cheatsheet](#imports)

---

## Decision Tree {#decision-tree}

```
Want to INSPECT code?
├─ No type info needed           → §AST
├─ Needs type info               → §Analysis
├─ Cross-package understanding   → §Packages
└─ Data-flow / pointer analysis  → §Analysis + buildssa pass

Want to REWRITE code?
├─ Known pattern, one-shot       → §GoFix first — may already cover it
├─ Custom rewrite, AST+printer   → §AST
├─ Import path changes           → §AST + astutil
└─ Large-scale, IDE-integrated   → §Analysis + SuggestedFix

Want to GENERATE code?
├─ iota enum String()            → §Codegen (stringer)
├─ Boilerplate / mocks           → §Codegen (go generate + custom tool)
└─ Type-safe wrappers            → §Packages (go/types introspection)
```

---

## §GoFix {#gofix}

Check built-in fixes before writing a custom rewriter — may already cover the target.

```bash
go tool fix -diff ./...           # dry run — always start here
go tool fix ./...                 # apply all
go tool fix -r context ./...      # specific fix only
go tool fix -force buildtag ./... # force even if looks updated
```

| Fix | What it does |
|-----|-------------|
| `buildtag` | Remove `// +build` in Go 1.18+ modules |
| `context` | `x/net/context` → `context` |
| `gotypes` | `x/tools/go/{exact,types}` → `go/{constant,types}` |
| `printerconfig` | Add field keys to `printer.Config` literals |
| `netipv6zone` | Fix `IPAddr`/`UDPAddr`/`TCPAddr` composite literals |

Custom fixers: use `go/analysis` SuggestedFix — not the internal `cmd/fix` `fix{}` struct.
The internal pattern doesn't integrate with golangci-lint, gopls, or `go vet -fix`.

---

## §Codegen {#codegen}

```bash
go install golang.org/x/tools/cmd/<tool>@latest
```

| Tool | Purpose |
|------|---------|
| `stringer` | `String()` for `iota` types |
| `goimports` | Format + manage imports |
| `gorename` | Type-safe identifier rename |
| `guru` | Query: callers, callees, peers, definition |
| `fiximports` | Fix import paths after package moves |
| `eg` | Example-based refactoring |
| `gopls` | Full LSP server |

**stringer:**
```go
//go:generate stringer -type=State -linecomment
type State int
const (
    Idle    State = iota // idle
    Running              // running
    Stopped              // stopped
)
```
Flags: `-type`, `-output`, `-linecomment`, `-trimprefix`, `-tags`

**goimports in CI:**
```bash
goimports -l ./...                                        # check (CI)
goimports -local github.com/yourorg/repo -w ./...         # fix with grouping
```

**go generate discipline:**
```go
// tools/gen/main.go
//go:build ignore   // mandatory — prevents accidental compilation
```

---

## §AST {#ast}

Use when: no type info needed, simple structural transforms, or prototyping before
promoting to `go/analysis`.

### Parse
```go
fset := token.NewFileSet()
f, err := parser.ParseFile(fset, "example.go", nil, parser.ParseComments)

pkgs, err := parser.ParseDir(fset, "./mypkg", nil, parser.ParseComments)
```

### Traverse

**`ast.Inspect`** — default:
```go
ast.Inspect(f, func(n ast.Node) bool {
    call, ok := n.(*ast.CallExpr)
    if !ok { return true }
    sel, ok := call.Fun.(*ast.SelectorExpr)
    if !ok { return true }
    if sel.Sel.Name == "OldFunc" {
        fmt.Println(fset.Position(call.Pos()))
    }
    return true
})
```

**`ast.Walk`** — when exit hooks needed:
```go
type v struct{ fset *token.FileSet }
func (vis v) Visit(n ast.Node) ast.Visitor {
    if n == nil { return nil }   // exit hook
    if fn, ok := n.(*ast.FuncDecl); ok { fmt.Println(fn.Name.Name) }
    return vis
}
ast.Walk(v{fset}, f)
```

### Common node types
```
ast.File          whole file
ast.FuncDecl      func foo(...)
ast.FuncLit       func(...) { } anonymous
ast.CallExpr      foo(args...)
ast.SelectorExpr  pkg.Name
ast.Ident         bare identifier
ast.BasicLit      string / int / float literal
ast.AssignStmt    x := y  |  x = y
ast.ReturnStmt    return ...
ast.IfStmt        if cond { }
ast.RangeStmt     for k, v := range ...
ast.TypeSpec      type Foo struct { }
ast.ImportSpec    import "pkg"
ast.GenDecl       var / const / type / import block
ast.Field         struct field or func parameter
```

### Rewrite + emit
```go
var buf bytes.Buffer
format.Node(&buf, fset, f)
os.WriteFile("example.go", buf.Bytes(), 0644)
```

### Import manipulation
```go
astutil.AddImport(fset, f, "context")
astutil.DeleteImport(fset, f, "golang.org/x/net/context")
ast.SortImports(fset, f)
```

---

## §Analysis {#analysis}

Use when: type info required, integration with `go vet` / golangci-lint / gopls, or
auto-fix (SuggestedFix) needed. Correct default for any non-trivial analyzer.

### Skeleton
```go
var Analyzer = &analysis.Analyzer{
    Name:     "myanalyzer",
    Doc:      "reports uses of deprecated Foo API",
    Requires: []*analysis.Analyzer{inspect.Analyzer},
    Run:      run,
}

func run(pass *analysis.Pass) (interface{}, error) {
    insp := pass.ResultOf[inspect.Analyzer].(*inspector.Inspector)
    insp.Preorder([]ast.Node{(*ast.CallExpr)(nil)}, func(n ast.Node) {
        call := n.(*ast.CallExpr)
        sel, ok := call.Fun.(*ast.SelectorExpr)
        if !ok { return }
        obj := pass.TypesInfo.Uses[sel.Sel]
        if obj == nil { return }
        if obj.Pkg().Path() == "myorg/pkg" && obj.Name() == "OldFunc" {
            pass.Reportf(call.Pos(), "OldFunc is deprecated, use NewFunc instead")
        }
    })
    return nil, nil
}
```

### SuggestedFix
```go
pass.Report(analysis.Diagnostic{
    Pos: call.Pos(), End: call.End(),
    Message: "use NewFunc instead of OldFunc",
    SuggestedFixes: []analysis.SuggestedFix{{
        Message: "Replace with NewFunc",
        TextEdits: []analysis.TextEdit{{
            Pos: sel.Sel.Pos(), End: sel.Sel.End(),
            NewText: []byte("NewFunc"),
        }},
    }},
})
```

### Runners
```go
singlechecker.Main(myanalyzer.Analyzer)
multichecker.Main(a1.Analyzer, a2.Analyzer)
```

### Built-in passes (`Requires`)
| Pass | Result type | Use for |
|------|------------|---------|
| `inspect.Analyzer` | `*inspector.Inspector` | Filtered traversal — always include |
| `buildssa.Analyzer` | `*ssa.SSA` | SSA / data-flow |
| `ctrlflow.Analyzer` | `*cfg.CFG` | Control flow graph |

### §Analyzer Testing {#analyzer-testing}

Use `analysistest`. Refuse hand-rolled AST comparison tests.

```go
func TestAnalyzer(t *testing.T) {
    analysistest.Run(t, analysistest.TestData(), myanalyzer.Analyzer, "mypackage")
}
```

Test files use `// want` inline annotations:
```go
func bad() {
    pkg.OldFunc() // want `OldFunc is deprecated`
}
```

**golangci-lint registration:**
```yaml
linters-settings:
  custom:
    myanalyzer:
      path: ./bin/myanalyzer
      description: "Detects use of deprecated API"
      original-url: github.com/myorg/myanalyzer
```

---

## §Packages {#packages}

Use for standalone tools (not `go vet` passes) needing full type info across packages.

```go
cfg := &packages.Config{
    Mode: packages.NeedName | packages.NeedFiles | packages.NeedSyntax |
          packages.NeedTypes | packages.NeedTypesInfo | packages.NeedImports,
}
pkgs, err := packages.Load(cfg, "./...")
packages.Visit(pkgs, nil, func(pkg *packages.Package) {
    for _, f := range pkg.Syntax { /* f is *ast.File, full type info in pkg.TypesInfo */ }
})
```

**Mode flags:**
```
NeedName        pkg.Name, pkg.PkgPath
NeedFiles       pkg.GoFiles (filenames)
NeedSyntax      pkg.Syntax ([]*ast.File)
NeedTypes       pkg.Types (*types.Package)
NeedTypesInfo   pkg.TypesInfo (*types.Info)  ← most commonly forgotten
NeedImports     pkg.Imports
NeedDeps        transitive dependencies
```

---

## §Pitfalls {#pitfalls}

**Never mutate shared AST nodes:**
```go
// BAD
call.Fun.(*ast.SelectorExpr).Sel.Name = "NewFunc"
// GOOD
call.Fun = &ast.SelectorExpr{X: sel.X, Sel: ast.NewIdent("NewFunc")}
```

**Always check position validity:**
```go
if !node.Pos().IsValid() { return }
pos := fset.Position(node.Pos())
```

**Comments need CommentMap after mutation:**
```go
cmap := ast.NewCommentMap(fset, f, f.Comments)
// ... mutate AST ...
f.Comments = cmap.Filter(f).Comments()
```

**Use `inspector.Inspector` not raw `ast.Walk` in analysis passes:**
`insp.Preorder(filter, fn)` pre-indexes by node type — significantly faster for multi-file
traversals. `ast.Inspect` in a `go/analysis` pass is a performance smell.

---

## §Recipes {#recipes}

**Rename a call site:**
```go
insp.Preorder([]ast.Node{(*ast.CallExpr)(nil)}, func(n ast.Node) {
    call := n.(*ast.CallExpr)
    sel, ok := call.Fun.(*ast.SelectorExpr)
    if !ok { return }
    if sel.Sel.Name != "OldName" || !isTargetPkg(pass, sel.X) { return }
    pass.Report(analysis.Diagnostic{
        Pos: sel.Sel.Pos(), End: sel.Sel.End(), Message: "use NewName",
        SuggestedFixes: []analysis.SuggestedFix{{
            Message: "Rename to NewName",
            TextEdits: []analysis.TextEdit{{
                Pos: sel.Sel.Pos(), End: sel.Sel.End(), NewText: []byte("NewName"),
            }},
        }},
    })
})
```

**Detect ignored error return:**
```go
insp.Preorder([]ast.Node{(*ast.ExprStmt)(nil)}, func(n ast.Node) {
    es := n.(*ast.ExprStmt)
    call, ok := es.X.(*ast.CallExpr)
    if !ok { return }
    sig, ok := pass.TypesInfo.TypeOf(call.Fun).(*types.Signature)
    if !ok { return }
    res := sig.Results()
    if res.Len() >= 2 && res.At(res.Len()-1).Type().String() == "error" {
        pass.Reportf(call.Pos(), "error return not checked")
    }
})
```

**Replace deprecated import:**
```go
for _, f := range pkg.Syntax {
    for _, imp := range f.Imports {
        if imp.Path.Value == `"old/path"` {
            astutil.DeleteImport(fset, f, "old/path")
            astutil.AddImport(fset, f, "new/path")
        }
    }
    ast.SortImports(fset, f)
}
```

---

## §Imports Cheatsheet {#imports}

```go
"go/ast"                                         // node types
"go/token"                                       // FileSet, Pos
"go/parser"                                      // ParseFile, ParseDir
"go/types"                                       // type checker
"go/format"                                      // format.Node (printer)
"go/constant"                                    // constant values
"golang.org/x/tools/go/ast/astutil"              // AddImport, DeleteImport
"golang.org/x/tools/go/ast/inspector"            // fast filtered traversal
"golang.org/x/tools/go/analysis"                 // Analyzer, Pass, Diagnostic
"golang.org/x/tools/go/analysis/passes/inspect"  // inspect pass
"golang.org/x/tools/go/analysis/singlechecker"   // single-analyzer main
"golang.org/x/tools/go/analysis/multichecker"    // multi-analyzer main
"golang.org/x/tools/go/analysis/analysistest"    // test framework
"golang.org/x/tools/go/packages"                 // package loader
"golang.org/x/tools/go/ssa"                      // SSA IR
```
