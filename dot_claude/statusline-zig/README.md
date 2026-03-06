# statusline-zig

A Zig port of the Claude Code bash statusline (`~/.claude/statusline.sh`). Single compiled binary, no runtime dependencies beyond `git` and `libc`. Produces the same two-line ANSI-colored output as the original.

## Prerequisites

- **Zig 0.14.0+** — [install instructions](https://ziglang.org/download/)
- **git** — for branch/status segment
- **Nerd Font** — your terminal font must include Nerd Font glyphs for icons to render

## Build

```bash
cd ~/.claude/statusline-zig
zig build -Doptimize=ReleaseSmall
```

The binary is placed at `zig-out/bin/statusline`.

## Setup

### 1. Switch Claude Code to use the Zig binary

Edit `~/.claude/settings.json`:

```json
"statusLine": {
    "type": "command",
    "command": "~/.claude/statusline-zig.sh",
    "padding": 0
}
```

### 2. Restart Claude Code

The change takes effect on the next session.

### Fallback behavior

The wrapper script `~/.claude/statusline-zig.sh` automatically falls back to the original bash statusline if the binary hasn't been built yet. This means you can update `settings.json` first and build later — no downtime.

### Switching back to bash

To revert, change `settings.json` back to:

```json
"statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 0
}
```

## Testing

### Run all tests (unit + integration)

```bash
./test.sh
```

### Unit tests only

Zig built-in tests for pure functions (`countLines`, `basename`, `fmtK`, `buildBar`, `colored`, `parseInput`, `parseUsageJson`, `buildContextSegment`):

```bash
./test.sh --unit
# or directly:
zig build test
```

### Integration tests only

Compares zig binary output against the bash statusline across multiple JSON payloads (full, minimal, empty context, high/medium usage, etc.):

```bash
./test.sh --integ
```

## Debugging

`debug.sh` runs the zig binary with sample input and shows rendered, stripped, and optionally hex/diff output.

```bash
./debug.sh              # Default sample JSON, rendered + stripped
./debug.sh --diff       # Side-by-side diff against bash statusline
./debug.sh --hex        # Include hex dump of raw output
./debug.sh --hex --diff # Combine flags
./debug.sh --live       # Paste real JSON from stdin
./debug.sh input.json   # Use a JSON file as input
```

## Development

Debug build (with symbols, slower):

```bash
zig build
```

Clean build artifacts:

```bash
rm -rf zig-out .zig-cache
```

## Customizing icons

Nerd Font glyphs are defined as `ICON_*` constants near the top of `src/main.zig` using literal UTF-8 characters with their U+XXXX codepoint in a comment. Edit the character directly and rebuild. Reference the bash originals in `~/.claude/statusline.sh` and `~/.claude/statusline/usage_api.sh`.

## Architecture

All logic lives in a single file `src/main.zig`. Sections map 1:1 to the bash modules:

| Section in main.zig      | Bash module              | Purpose                          |
|--------------------------|--------------------------|----------------------------------|
| ANSI color helpers       | `statusline/colors.sh`   | Color constants, `colored()`, `buildBar()` |
| JSON input parsing       | `statusline.sh` (jq)     | Parse stdin JSON into struct     |
| Git segment              | `statusline/git.sh`      | Branch name + file status counts |
| Context segment          | `statusline/context.sh`  | Progress bar + token usage label |
| Usage API + cache        | `statusline/usage_api.sh`| HTTP fetch, TTL cache, line 2   |
| Tests                    | `test.sh`                | Unit tests for pure functions    |

## How it works

1. Reads JSON from stdin (Claude Code pipes session state)
2. Parses model name, workspace paths, context window stats
3. Runs `git` subprocesses to get branch and file status
4. Fetches Anthropic usage API (with 3-minute file cache at `/tmp/claude/`)
5. Prints 1-2 lines of ANSI-colored output with Nerd Font icons

## Output format

```
 [Opus 4.6] •  project •  main +2 ~1 • 󰈸 ●●●●○○○○○○ 42% (84k/200k) •  /home/user/project
 5h: ●●●○○○○○ 35% •  2:45pm 󰇙 󰺏 7d: ●●○○○○○○ 22% •  Mar 8, 2:45pm
```
