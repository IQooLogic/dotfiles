# HTTP Patterns

## Server with Timeouts

```go
srv := &http.Server{
    Addr:         cfg.ListenAddr,
    Handler:      mux,
    ReadTimeout:  10 * time.Second,
    WriteTimeout: 30 * time.Second,
    IdleTimeout:  120 * time.Second,
}

// Graceful shutdown
go func() {
    <-ctx.Done()
    shutCtx, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
    defer cancel()
    _ = srv.Shutdown(shutCtx)
}()

if err := srv.ListenAndServe(); !errors.Is(err, http.ErrServerClosed) {
    return fmt.Errorf("http server: %w", err)
}
```

## Rules

- `http.Client` is created once and reused — never per-request
- All outbound clients have explicit timeouts
- Handler functions follow `func(w http.ResponseWriter, r *http.Request)` — no fat middleware chains

## Observability (Prometheus)

```go
var (
    eventsProcessed = promauto.NewCounterVec(prometheus.CounterOpts{
        Name: "engine_events_processed_total",
        Help: "Total events processed by the engine.",
    }, []string{"source", "status"})

    processingDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
        Name:    "engine_processing_duration_seconds",
        Help:    "Time to process a single event.",
        Buckets: prometheus.DefBuckets,
    }, []string{"source"})
)
```

Label cardinality matters. Never use high-cardinality values (IDs, IPs) as labels.

## Profiling (pprof)

Register pprof handlers in the debug server (never the production listener):

```go
debugMux := http.NewServeMux()
debugMux.HandleFunc("/debug/pprof/", pprof.Index)
debugMux.HandleFunc("/debug/pprof/cmdline", pprof.Cmdline)
debugMux.HandleFunc("/debug/pprof/profile", pprof.Profile)
debugMux.HandleFunc("/debug/pprof/symbol", pprof.Symbol)
debugMux.HandleFunc("/debug/pprof/trace", pprof.Trace)

go http.ListenAndServe(cfg.DebugAddr, debugMux)
```
