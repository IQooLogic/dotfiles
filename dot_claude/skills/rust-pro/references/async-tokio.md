# Async & Tokio Patterns

## Runtime Configuration

```rust
// Explicit runtime — preferred over #[tokio::main] for libraries and production
let rt = tokio::runtime::Builder::new_multi_thread()
    .worker_threads(4)        // default: num CPUs
    .enable_all()
    .build()
    .expect("failed to build runtime");

rt.block_on(async {
    // application logic
});
```

Never use `#[tokio::main]` in library code. Only in binary entry points for convenience,
and even then prefer explicit `Builder` for production services.

## Task Spawning

```rust
use tokio_util::sync::CancellationToken;

let token = CancellationToken::new();
let child_token = token.child_token();

let handle = tokio::spawn(async move {
    tokio::select! {
        result = do_work() => result,
        _ = child_token.cancelled() => {
            tracing::info!("task cancelled");
            Ok(())
        }
    }
});

// To cancel:
token.cancel();
// To await:
handle.await??;
```

### Rules
- Every `tokio::spawn` must have a cancellation path
- Use `CancellationToken` from `tokio-util` for cooperative cancellation
- `JoinHandle` must be awaited or explicitly detached with documentation
- Use `tokio::spawn` for independent concurrent work, not for parallelism within a request

## Graceful Shutdown

```rust
use tokio::signal;

async fn shutdown_signal() {
    let ctrl_c = async { signal::ctrl_c().await.expect("failed to listen for ctrl+c") };

    #[cfg(unix)]
    let terminate = async {
        signal::unix::signal(signal::unix::SignalKind::terminate())
            .expect("failed to listen for SIGTERM")
            .recv()
            .await;
    };

    #[cfg(not(unix))]
    let terminate = std::future::pending::<()>();

    tokio::select! {
        _ = ctrl_c => tracing::info!("received ctrl+c"),
        _ = terminate => tracing::info!("received SIGTERM"),
    }
}
```

## Channel Patterns

```rust
use tokio::sync::mpsc;

// Bounded channel — backpressure when full
let (tx, mut rx) = mpsc::channel::<Event>(100);

// Producer
tokio::spawn(async move {
    if tx.send(event).await.is_err() {
        tracing::warn!("receiver dropped");
        return;
    }
});

// Consumer
while let Some(event) = rx.recv().await {
    process(event).await?;
}
```

### Channel Selection Guide

| Type | Use Case |
|------|----------|
| `mpsc::channel` | Multiple producers, single consumer. Bounded with backpressure. |
| `mpsc::unbounded_channel` | Only when sender cannot be async (e.g., from sync code). Document why. |
| `oneshot::channel` | Single value response. Request-reply pattern. |
| `broadcast::channel` | Multiple consumers need every message. |
| `watch::channel` | Latest-value only. Config updates, state broadcasting. |

## Select Patterns

```rust
tokio::select! {
    // Bias toward cancellation — check it first
    biased;

    _ = token.cancelled() => {
        tracing::info!("cancelled");
        return Ok(());
    }

    Some(event) = rx.recv() => {
        process(event).await?;
    }

    _ = tokio::time::sleep(Duration::from_secs(30)) => {
        tracing::warn!("idle timeout");
    }
}
```

Use `biased;` when cancellation or shutdown should take priority.

## Semaphore for Concurrency Limiting

```rust
use tokio::sync::Semaphore;
use std::sync::Arc;

let semaphore = Arc::new(Semaphore::new(10)); // max 10 concurrent

for item in items {
    let permit = semaphore.clone().acquire_owned().await?;
    tokio::spawn(async move {
        let _permit = permit; // held until dropped
        process(item).await;
    });
}
```

## Common Pitfalls

| Pitfall | Fix |
|---------|-----|
| Holding `std::sync::Mutex` across `.await` | Use `tokio::sync::Mutex` or restructure |
| `block_in_place` in async context | Use `tokio::task::spawn_blocking` |
| Unbounded channels without justification | Use bounded channels with documented capacity |
| `tokio::spawn` without cancellation | Add `CancellationToken` or `select!` on shutdown |
| CPU-heavy work on async thread | Move to `spawn_blocking` or `rayon` |

## Stream Processing

```rust
use tokio_stream::{self as stream, StreamExt};

// Basic stream iteration
let mut s = stream::iter(vec![1, 2, 3, 4, 5]);
while let Some(value) = s.next().await {
    process(value).await;
}

// Stream combinators — filter, map, collect
let results: Vec<_> = stream::iter(vec![1, 2, 3, 4, 5])
    .filter(|x| *x % 2 == 0)
    .map(|x| x * 2)
    .collect()
    .await;

// Async transforms with .then()
use futures::stream::{self, StreamExt};

let processed: Vec<_> = stream::iter(items)
    .then(|item| async move {
        tokio::time::sleep(Duration::from_millis(10)).await;
        transform(item).await
    })
    .collect()
    .await;

// Buffered concurrency — process up to N items concurrently
let results: Vec<_> = stream::iter(urls)
    .map(|url| async move { fetch(url).await })
    .buffer_unordered(10) // up to 10 concurrent fetches
    .collect()
    .await;
```

### Rules
- Use `tokio-stream` for stream utilities; `futures::stream` for `.then()` and `.buffer_unordered()`
- Prefer `.buffer_unordered(N)` over spawning unbounded tasks for fan-out work
- Always consume streams — an unconsumed stream does nothing

## Async Traits

```rust
use async_trait::async_trait;

#[async_trait]
trait Repository {
    async fn find(&self, id: u64) -> Result<Entity, Error>;
    async fn save(&self, entity: &Entity) -> Result<(), Error>;
}

#[async_trait]
impl Repository for PgRepository {
    async fn find(&self, id: u64) -> Result<Entity, Error> {
        sqlx::query_as("SELECT * FROM entities WHERE id = $1")
            .bind(id)
            .fetch_one(&self.pool)
            .await
            .map_err(Into::into)
    }

    async fn save(&self, entity: &Entity) -> Result<(), Error> {
        sqlx::query("INSERT INTO entities (name) VALUES ($1)")
            .bind(&entity.name)
            .execute(&self.pool)
            .await?;
        Ok(())
    }
}
```

### Rules
- `async-trait` uses heap allocation (`Box<dyn Future>`). Acceptable for service-layer traits.
- For hot paths where allocation matters, use manual `-> impl Future` or RPITIT (Rust 1.75+):
  ```rust
  trait FastPath {
      fn compute(&self, input: &[u8]) -> impl Future<Output = Result<Vec<u8>, Error>> + Send;
  }
  ```
- Default to `async-trait` unless profiling shows it matters. Clarity wins over micro-optimization.

## Pin and Futures

```rust
use std::pin::Pin;
use std::future::Future;

// Returning a dynamically-dispatched future (common in trait impls and closures)
fn make_future(flag: bool) -> Pin<Box<dyn Future<Output = i32> + Send>> {
    if flag {
        Box::pin(async { 42 })
    } else {
        Box::pin(async { 0 })
    }
}

// Manual Future implementation — rarely needed, but useful for custom combinators
use std::task::{Context, Poll};

struct Timeout<F> {
    inner: Pin<Box<F>>,
    delay: Pin<Box<tokio::time::Sleep>>,
}

impl<F: Future> Future for Timeout<F> {
    type Output = Option<F::Output>;

    fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        if let Poll::Ready(v) = self.inner.as_mut().poll(cx) {
            return Poll::Ready(Some(v));
        }
        if let Poll::Ready(_) = self.delay.as_mut().poll(cx) {
            return Poll::Ready(None);
        }
        Poll::Pending
    }
}
```

### Rules
- `Pin` guarantees a value will not move in memory — required for self-referential futures
- Use `Box::pin(async { ... })` when you need type erasure or conditional futures
- Manual `Future` impls are rare — prefer `async fn` and combinators
- If you need `Pin<&mut Self>`, use `pin_project` crate instead of unsafe pin projections
