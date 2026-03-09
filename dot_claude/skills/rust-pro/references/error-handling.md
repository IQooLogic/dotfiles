# Error Handling Patterns

## The Two-Crate Strategy

- **Library code**: `thiserror` — typed, structured errors callers can match on
- **Application code**: `anyhow` — ergonomic error propagation with context

Never mix them within the same layer. Libraries expose `thiserror` types;
the application boundary converts to `anyhow::Result`.

## thiserror — Library Errors

```rust
use thiserror::Error;

#[derive(Debug, Error)]
pub enum EngineError {
    #[error("event {id} not found")]
    NotFound { id: String },

    #[error("process event {id}: {source}")]
    Process {
        id: String,
        #[source]
        source: std::io::Error,
    },

    #[error("invalid configuration: {0}")]
    InvalidConfig(String),

    #[error("timeout after {0:?}")]
    Timeout(std::time::Duration),
}
```

### Rules
- Every variant has a clear `#[error("...")]` message
- Use `#[source]` to chain errors — enables `Error::source()` traversal
- Use `#[from]` sparingly — only when 1:1 mapping is unambiguous
- Variant names describe the failure, not the cause

## anyhow — Application Errors

```rust
use anyhow::{Context, Result};

async fn run(config: Config) -> Result<()> {
    let db = Database::connect(&config.database_url)
        .await
        .context("connecting to database")?;

    let events = db.fetch_events()
        .await
        .with_context(|| format!("fetching events from {}", config.database_url))?;

    Ok(())
}
```

### Rules
- Use `.context()` at every layer transition — the chain tells the full story
- Use `.with_context(|| ...)` when context needs formatting (avoids allocation on success path)
- `anyhow::bail!("message")` for early returns
- `anyhow::ensure!(condition, "message")` for assertions

## Error Conversion at Boundaries

```rust
// In the HTTP handler — convert domain errors to responses
impl From<EngineError> for StatusCode {
    fn from(err: EngineError) -> Self {
        match err {
            EngineError::NotFound { .. } => StatusCode::NOT_FOUND,
            EngineError::InvalidConfig(_) => StatusCode::BAD_REQUEST,
            EngineError::Timeout(_) => StatusCode::GATEWAY_TIMEOUT,
            EngineError::Process { .. } => StatusCode::INTERNAL_SERVER_ERROR,
        }
    }
}
```

## Pattern: Fallible Constructors

```rust
pub struct Port(u16);

impl Port {
    pub fn new(value: u16) -> Result<Self, PortError> {
        if value == 0 {
            return Err(PortError::Zero);
        }
        Ok(Self(value))
    }
}
```

Validate at construction time. Once a type exists, it's guaranteed valid.

## Result/Option Combinators

### Option Combinators

```rust
// map: transform Option<T> to Option<U>
let num: Option<i32> = Some(5);
let doubled = num.map(|n| n * 2);  // Some(10)

// and_then: chain operations that return Option
let result = Some(5)
    .and_then(|n| if n > 0 { Some(n * 2) } else { None })
    .and_then(|n| Some(n + 1));  // Some(11)

// or / unwrap_or / unwrap_or_else: provide fallbacks
let value = None.or(Some(42));                          // Some(42)
let value = None.unwrap_or(42);                         // 42
let value = None.unwrap_or_else(|| expensive_default());// lazy default

// filter: conditionally convert to None
let num = Some(5).filter(|&n| n > 10);  // None

// ok_or: convert Option to Result
let result: Result<i32, &str> = Some(5).ok_or("missing");
```

### Result Combinators

```rust
// map: transform Ok value
let doubled = Ok::<i32, String>(5).map(|n| n * 2);  // Ok(10)

// map_err: transform error value
let mapped = Err::<i32, &str>("fail").map_err(|e| e.to_uppercase());  // Err("FAIL")

// and_then: chain fallible operations
fn parse_and_double(s: &str) -> Result<i32, std::num::ParseIntError> {
    s.parse::<i32>().and_then(|n| Ok(n * 2))
}

// or_else: recover from errors
let result: Result<i32, &str> = Err("error").or_else(|_| Ok(42));  // Ok(42)

// unwrap_or: provide default on error
let value = Err::<i32, &str>("error").unwrap_or(42);  // 42

// ok(): convert Result to Option (discards error)
let opt: Option<i32> = Ok::<i32, &str>(5).ok();  // Some(5)
```

## From Trait Error Conversion

Manual `From` implementations enable the `?` operator to auto-convert between error types.
Prefer `#[from]` in `thiserror` when the mapping is 1:1; use manual `From` when you need
to add context or when `thiserror` is not in scope.

```rust
use std::io;
use std::num::ParseIntError;

#[derive(Debug)]
enum MyError {
    Io(io::Error),
    Parse(ParseIntError),
}

impl From<io::Error> for MyError {
    fn from(err: io::Error) -> Self {
        MyError::Io(err)
    }
}

impl From<ParseIntError> for MyError {
    fn from(err: ParseIntError) -> Self {
        MyError::Parse(err)
    }
}

// Now ? auto-converts at each call site
fn read_and_parse(path: &str) -> Result<i32, MyError> {
    let content = std::fs::read_to_string(path)?;  // io::Error -> MyError
    let number = content.trim().parse()?;           // ParseIntError -> MyError
    Ok(number)
}
```

## Advanced Error Patterns

### Box<dyn Error> for Prototyping

Use `Box<dyn Error>` for quick prototyping or scripts where typed errors are overkill.
Replace with `thiserror` or `anyhow` before production.

```rust
use std::error::Error;

fn quick_operation() -> Result<String, Box<dyn Error>> {
    let file = std::fs::read_to_string("data.txt")?;
    let number: i32 = file.trim().parse()?;
    Ok(format!("Number: {}", number))
}
```

### Context Extension Trait

When you need `anyhow`-style `.context()` without pulling in `anyhow` (e.g., in a library):

```rust
use std::error::Error;
use thiserror::Error;

#[derive(Error, Debug)]
#[error("{message}")]
struct ContextError {
    message: String,
    #[source]
    source: Option<Box<dyn Error + Send + Sync>>,
}

impl ContextError {
    fn new(message: impl Into<String>) -> Self {
        Self { message: message.into(), source: None }
    }

    fn with_source(mut self, source: impl Error + Send + Sync + 'static) -> Self {
        self.source = Some(Box::new(source));
        self
    }
}

trait ErrorContext<T> {
    fn context(self, message: impl Into<String>) -> Result<T, ContextError>;
}

impl<T, E: Error + Send + Sync + 'static> ErrorContext<T> for Result<T, E> {
    fn context(self, message: impl Into<String>) -> Result<T, ContextError> {
        self.map_err(|e| ContextError::new(message).with_source(e))
    }
}
```

### Error with Backtrace

```rust
#[derive(Debug)]
struct DetailedError {
    message: String,
    backtrace: std::backtrace::Backtrace,
}

impl DetailedError {
    fn new(message: impl Into<String>) -> Self {
        Self {
            message: message.into(),
            backtrace: std::backtrace::Backtrace::capture(),
        }
    }
}
```

Requires `RUST_BACKTRACE=1` at runtime. Use sparingly — backtraces add overhead.

## Anti-Patterns

| Anti-Pattern | Fix |
|-------------|-----|
| `.unwrap()` in library code | Return `Result` or use `expect` with rationale |
| `Box<dyn Error>` as error type | Use `thiserror` enum or `anyhow::Error` |
| String errors: `Err("failed".into())` | Use typed errors |
| Matching on error messages | Use enum variants or `downcast_ref` |
| Ignoring errors: `let _ = foo()` | Handle or add comment explaining why safe to ignore |
| `panic!` for recoverable errors | Return `Result` |
