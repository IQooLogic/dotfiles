# Generics Patterns

Use generics when the algorithm is identical across types and the abstraction genuinely reduces
duplication. Do not use generics just because you can — concrete types and interfaces are
usually clearer.

## Type Parameters and Constraints

```go
import "cmp"

// Ordered covers all types supporting <, >, <=, >=
func Min[T cmp.Ordered](a, b T) T {
    if a < b { return a }
    return b
}

// Custom numeric constraint
type Number interface {
    ~int | ~int8 | ~int16 | ~int32 | ~int64 |
    ~float32 | ~float64
}

func Sum[T Number](nums []T) T {
    var total T
    for _, n := range nums { total += n }
    return total
}
```

## Common Generic Utilities

```go
// Map — transform a slice
func Map[T, U any](s []T, fn func(T) U) []U {
    out := make([]U, len(s))
    for i, v := range s { out[i] = fn(v) }
    return out
}

// Filter — keep elements matching predicate
func Filter[T any](s []T, fn func(T) bool) []T {
    out := make([]T, 0, len(s))
    for _, v := range s {
        if fn(v) { out = append(out, v) }
    }
    return out
}

// Keys / Values — extract map keys or values
func Keys[K comparable, V any](m map[K]V) []K {
    keys := make([]K, 0, len(m))
    for k := range m { keys = append(keys, k) }
    return keys
}
```

## Generic Data Structures

```go
type Stack[T any] struct{ items []T }

func (s *Stack[T]) Push(v T)          { s.items = append(s.items, v) }
func (s *Stack[T]) IsEmpty() bool     { return len(s.items) == 0 }
func (s *Stack[T]) Pop() (T, bool) {
    if s.IsEmpty() { var zero T; return zero, false }
    v := s.items[len(s.items)-1]
    s.items = s.items[:len(s.items)-1]
    return v, true
}
```

## Generic Channels

```go
// Stage — transform values in a pipeline stage
func Stage[T, U any](ctx context.Context, in <-chan T, fn func(T) U) <-chan U {
    out := make(chan U)
    go func() {
        defer close(out)
        for v := range in {
            select {
            case out <- fn(v):
            case <-ctx.Done():
                return
            }
        }
    }()
    return out
}

// Merge — fan-in multiple channels of the same type
func Merge[T any](ctx context.Context, channels ...<-chan T) <-chan T {
    out := make(chan T)
    var wg sync.WaitGroup
    for _, ch := range channels {
        wg.Add(1)
        go func(c <-chan T) {
            defer wg.Done()
            for v := range c {
                select {
                case out <- v:
                case <-ctx.Done():
                    return
                }
            }
        }(ch)
    }
    go func() { wg.Wait(); close(out) }()
    return out
}
```
