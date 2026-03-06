#!/bin/bash
# debug.sh — Run the zig statusline with sample or live input and inspect output.
#
# Usage:
#   ./debug.sh              Use default sample JSON
#   ./debug.sh --live       Capture real Claude Code statusline JSON from stdin
#   ./debug.sh --hex        Show hex dump alongside rendered output
#   ./debug.sh --diff       Side-by-side diff against bash statusline
#   ./debug.sh --raw FILE   Use a JSON file as input
#   ./debug.sh --cached     Use the cached usage API response for line 2
#
# Flags can be combined: ./debug.sh --hex --diff

set -euo pipefail
cd "$(dirname "$0")"

ZIG_BIN="./zig-out/bin/statusline"
BASH_SL="$HOME/.claude/statusline.sh"

# Rebuild if source is newer
if [ ! -x "$ZIG_BIN" ] || [ "src/main.zig" -nt "$ZIG_BIN" ]; then
    echo "Rebuilding (debug)…"
    zig build
    echo
fi

# Default sample JSON
SAMPLE_JSON='{"model":{"display_name":"Opus 4.6"},"workspace":{"current_dir":"'"$PWD"'","project_dir":"'"$PWD"'"},"context_window":{"context_window_size":200000,"used_percentage":42,"current_usage":{"input_tokens":50000,"cache_creation_input_tokens":10000,"cache_read_input_tokens":24000}}}'

# Parse flags
INPUT_JSON="$SAMPLE_JSON"
SHOW_HEX=false
SHOW_DIFF=false
LIVE=false

for arg in "$@"; do
    case "$arg" in
        --live)    LIVE=true ;;
        --hex)     SHOW_HEX=true ;;
        --diff)    SHOW_DIFF=true ;;
        --cached)
            if [ -f /tmp/claude/statusline-usage-cache.json ]; then
                echo "Using cached usage API response"
            else
                echo "No cached usage response found at /tmp/claude/statusline-usage-cache.json"
            fi
            ;;
        --raw)     ;; # handled below
        *)
            if [ -f "$arg" ]; then
                INPUT_JSON=$(cat "$arg")
            fi
            ;;
    esac
done

if $LIVE; then
    echo "Paste Claude Code statusline JSON, then press Ctrl-D:"
    INPUT_JSON=$(cat)
fi

strip_ansi() { sed 's/\x1b\[[0-9;]*m//g'; }

echo "━━━ Zig output (rendered) ━━━"
echo "$INPUT_JSON" | "$ZIG_BIN" 2>/dev/null
echo

echo "━━━ Zig output (stripped) ━━━"
echo "$INPUT_JSON" | "$ZIG_BIN" 2>/dev/null | strip_ansi
echo

if $SHOW_HEX; then
    echo "━━━ Zig output (hex) ━━━"
    echo "$INPUT_JSON" | "$ZIG_BIN" 2>/dev/null | xxd | head -30
    echo
fi

if $SHOW_DIFF; then
    if [ -f "$BASH_SL" ]; then
        BASH_OUT=$(echo "$INPUT_JSON" | bash "$BASH_SL" 2>/dev/null | strip_ansi)
        ZIG_OUT=$(echo "$INPUT_JSON" | "$ZIG_BIN" 2>/dev/null | strip_ansi)

        echo "━━━ Diff (bash vs zig, stripped) ━━━"
        if diff <(echo "$BASH_OUT") <(echo "$ZIG_OUT") --color=always; then
            printf '\033[32m✓ Identical\033[0m\n'
        fi
    else
        echo "(bash statusline not found at $BASH_SL — skipping diff)"
    fi
    echo
fi

echo "━━━ Input JSON (pretty) ━━━"
echo "$INPUT_JSON" | python3 -m json.tool 2>/dev/null || echo "$INPUT_JSON"
