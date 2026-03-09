# CLI Patterns

## Argument Parsing with clap

```rust
use clap::Parser;

/// A tool that processes events from various sources.
#[derive(Debug, Parser)]
#[command(version, about)]
pub struct Args {
    /// Path to the configuration file
    #[arg(short, long, default_value = "config.toml")]
    pub config: PathBuf,

    /// Increase logging verbosity (-v, -vv, -vvv)
    #[arg(short, long, action = clap::ArgAction::Count)]
    pub verbose: u8,

    /// Output format
    #[arg(long, default_value = "text", value_enum)]
    pub format: OutputFormat,

    #[command(subcommand)]
    pub command: Command,
}

#[derive(Debug, Clone, clap::ValueEnum)]
pub enum OutputFormat {
    Text,
    Json,
    Table,
}

#[derive(Debug, clap::Subcommand)]
pub enum Command {
    /// Start the server
    Serve {
        /// Listen address
        #[arg(long, default_value = "0.0.0.0:8080")]
        addr: String,
    },
    /// Run a one-shot import
    Import {
        /// Source file
        path: PathBuf,
    },
}
```

### Rules
- Use `derive(Parser)` — not the builder API unless dynamic args are needed
- Every field and variant gets a `///` doc comment (shown in `--help`)
- Use `value_enum` for closed sets of string options
- Subcommands for distinct operational modes
- `PathBuf` for file arguments, not `String`

## Structured Output

```rust
use std::io::{self, Write, BufWriter};

fn write_output(events: &[Event], format: OutputFormat) -> anyhow::Result<()> {
    let stdout = io::stdout();
    let mut out = BufWriter::new(stdout.lock());

    match format {
        OutputFormat::Json => {
            serde_json::to_writer_pretty(&mut out, events)?;
            writeln!(out)?;
        }
        OutputFormat::Text => {
            for event in events {
                writeln!(out, "{}: {}", event.id, event.summary)?;
            }
        }
        OutputFormat::Table => {
            // Use comfy-table or tabled crate
        }
    }

    out.flush()?;
    Ok(())
}
```

### Rules
- Buffer stdout with `BufWriter` for batch output
- Lock stdout once for the entire output operation
- Support at least `--format json` for machine consumption
- Write errors to stderr, data to stdout
- Flush before exiting

## Exit Codes

```rust
use std::process::ExitCode;

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("error: {e:#}");
            ExitCode::FAILURE
        }
    }
}
```

- `ExitCode::SUCCESS` (0) for success
- `ExitCode::FAILURE` (1) for general errors
- Custom codes via `ExitCode::from(2)` for specific failure categories
- Never `std::process::exit()` — it skips destructors

## Progress and Interactive Output

```rust
use indicatif::{ProgressBar, ProgressStyle};

let pb = ProgressBar::new(total as u64);
pb.set_style(
    ProgressStyle::default_bar()
        .template("{spinner:.green} [{bar:40}] {pos}/{len} ({eta})")
        .expect("invalid template")
);

for item in items {
    process(item)?;
    pb.inc(1);
}
pb.finish_with_message("done");
```

- Use `indicatif` for progress bars
- Only show progress on stderr (keeps stdout clean for piping)
- Disable progress in non-TTY contexts: `if atty::is(atty::Stream::Stderr)`

## Configuration File Loading

```rust
use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct Config {
    pub server: ServerConfig,
    pub database: DatabaseConfig,
}

#[derive(Debug, Deserialize)]
pub struct ServerConfig {
    #[serde(default = "default_addr")]
    pub addr: String,
    #[serde(with = "humantime_serde")]
    pub timeout: Duration,
}

fn default_addr() -> String { "0.0.0.0:8080".into() }

impl Config {
    pub fn load(path: &Path) -> anyhow::Result<Self> {
        let content = std::fs::read_to_string(path)
            .with_context(|| format!("reading config from {}", path.display()))?;
        let config: Self = toml::from_str(&content)
            .context("parsing config")?;
        Ok(config)
    }
}
```

- TOML for config files (Rust ecosystem convention)
- `serde::Deserialize` for all config structs
- Provide defaults with `#[serde(default)]`
- Validate after deserialization, not during

## Logging Setup

```rust
use tracing_subscriber::{fmt, EnvFilter};

pub fn init_logging(verbosity: u8) {
    let filter = match verbosity {
        0 => "warn",
        1 => "info",
        2 => "debug",
        _ => "trace",
    };

    let env_filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new(filter));

    fmt()
        .with_env_filter(env_filter)
        .with_target(false)
        .with_writer(std::io::stderr)
        .init();
}
```

- Log to stderr — never stdout
- Respect `RUST_LOG` environment variable
- Map `-v` flags to log levels
- `with_target(false)` for cleaner CLI output
