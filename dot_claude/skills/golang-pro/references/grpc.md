# gRPC Patterns

When gRPC is in scope per ARCH.md:

## Server

```go
grpcServer := grpc.NewServer(
    grpc.ChainUnaryInterceptor(
        logging.UnaryServerInterceptor(logger),
        recovery.UnaryServerInterceptor(),
    ),
)
pb.RegisterServiceServer(grpcServer, &serviceImpl{})
reflection.Register(grpcServer) // enables grpcurl in dev

// Graceful shutdown
go func() {
    <-ctx.Done()
    grpcServer.GracefulStop()
}()

if err := grpcServer.Serve(lis); err != nil {
    return fmt.Errorf("grpc serve: %w", err)
}
```

## Client

```go
conn, err := grpc.NewClient(cfg.TargetAddr,
    grpc.WithTransportCredentials(credentials.NewTLS(&tls.Config{})),
    grpc.WithChainUnaryInterceptor(
        retry.UnaryClientInterceptor(
            retry.WithMax(3),
            retry.WithBackoff(retry.BackoffExponential(100*time.Millisecond)),
        ),
    ),
)
if err != nil {
    return fmt.Errorf("grpc dial %s: %w", cfg.TargetAddr, err)
}
defer conn.Close()

client := pb.NewServiceClient(conn)

ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
defer cancel()
resp, err := client.Call(ctx, req)
```

## Rules

- Always use interceptors for logging and recovery — not inline in handlers
- Use `grpc.GracefulStop()`, not `grpc.Stop()`
- Create the connection once at startup — never per-RPC
- All RPC calls use a deadline context — never raw `context.Background()`
- Proto files live in `api/proto/` — never in `internal/`
- Run `buf lint` and `buf generate` via `go generate` or Makefile target
