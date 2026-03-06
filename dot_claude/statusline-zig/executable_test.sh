#!/bin/bash
# test.sh — Integration tests: compare zig binary output against bash statusline.
#
# Usage:
#   ./test.sh          Run all tests (unit + integration)
#   ./test.sh --unit   Run zig unit tests only
#   ./test.sh --integ  Run integration (bash vs zig diff) tests only
#
# Exit code 0 = all pass, 1 = failures.

set -euo pipefail
cd "$(dirname "$0")"

BASH_SL="$HOME/.claude/statusline.sh"
ZIG_BIN="./zig-out/bin/statusline"
PASS=0
FAIL=0
SKIP=0

red()   { printf '\033[31m%s\033[0m' "$1"; }
green() { printf '\033[32m%s\033[0m' "$1"; }
dim()   { printf '\033[90m%s\033[0m' "$1"; }

strip_ansi() { sed 's/\x1b\[[0-9;]*m//g'; }

# ── Unit tests ──────────────────────────────────────────────

run_unit_tests() {
    echo "━━━ Unit tests (zig build test) ━━━"
    if zig build test 2>&1; then
        echo "$(green "PASS") unit tests"
        PASS=$((PASS + 1))
    else
        echo "$(red "FAIL") unit tests"
        FAIL=$((FAIL + 1))
    fi
    echo
}

# ── Integration helpers ─────────────────────────────────────

# Build if needed
ensure_built() {
    if [ ! -x "$ZIG_BIN" ] || [ "src/main.zig" -nt "$ZIG_BIN" ]; then
        echo "Building…"
        zig build -Doptimize=ReleaseSmall
        echo
    fi
}

# Run a single integration test case.
#   integ_test "name" "json_input"
# Compares line 1 (always) and line 2 (only if bash produces it).
integ_test() {
    local name="$1" input="$2"
    local bash_out zig_out

    bash_out=$(echo "$input" | bash "$BASH_SL" 2>/dev/null | strip_ansi) || true
    zig_out=$(echo "$input"  | "$ZIG_BIN" 2>/dev/null | strip_ansi) || true

    # Compare line 1
    local bash_l1 zig_l1
    bash_l1=$(echo "$bash_out" | head -1)
    zig_l1=$(echo "$zig_out" | head -1)

    if [ "$bash_l1" = "$zig_l1" ]; then
        echo "$(green "PASS") $name (line 1)"
        PASS=$((PASS + 1))
    else
        echo "$(red "FAIL") $name (line 1)"
        echo "  bash: $bash_l1"
        echo "  zig:  $zig_l1"
        FAIL=$((FAIL + 1))
    fi

    # Compare line 2 only if bash produced one
    local bash_l2 zig_l2
    bash_l2=$(echo "$bash_out" | sed -n '2p')
    zig_l2=$(echo "$zig_out" | sed -n '2p')

    if [ -z "$bash_l2" ] && [ -z "$zig_l2" ]; then
        echo "$(green "PASS") $name (line 2 — both empty)"
        PASS=$((PASS + 1))
    elif [ "$bash_l2" = "$zig_l2" ]; then
        echo "$(green "PASS") $name (line 2)"
        PASS=$((PASS + 1))
    else
        echo "$(red "FAIL") $name (line 2)"
        echo "  bash: $bash_l2"
        echo "  zig:  $zig_l2"
        FAIL=$((FAIL + 1))
    fi
}

# ── Integration test cases ──────────────────────────────────

run_integration_tests() {
    echo "━━━ Integration tests (bash vs zig) ━━━"
    ensure_built

    if [ ! -f "$BASH_SL" ]; then
        echo "$(dim "SKIP") bash statusline not found at $BASH_SL"
        SKIP=$((SKIP + 1))
        return
    fi

    integ_test "full payload" \
        '{"model":{"display_name":"Opus 4.6"},"workspace":{"current_dir":"/home/user/project","project_dir":"/home/user/project"},"context_window":{"context_window_size":200000,"used_percentage":42,"current_usage":{"input_tokens":50000,"cache_creation_input_tokens":10000,"cache_read_input_tokens":24000}}}'

    integ_test "minimal payload" \
        '{"model":{"display_name":"Sonnet 4"},"workspace":{"current_dir":"/tmp","project_dir":"/tmp"},"context_window":{}}'

    integ_test "empty context" \
        '{"model":{"display_name":"Haiku 4.5"},"workspace":{"current_dir":"/home/user/app","project_dir":"/home/user/app"},"context_window":{"context_window_size":100000,"used_percentage":0,"current_usage":{"input_tokens":0,"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}'

    integ_test "high context usage" \
        '{"model":{"display_name":"Opus 4.6"},"workspace":{"current_dir":"/home/user/big-repo","project_dir":"/home/user/big-repo"},"context_window":{"context_window_size":200000,"used_percentage":92,"current_usage":{"input_tokens":150000,"cache_creation_input_tokens":30000,"cache_read_input_tokens":4000}}}'

    integ_test "medium context usage" \
        '{"model":{"display_name":"Sonnet 4.6"},"workspace":{"current_dir":"/home/user/mid","project_dir":"/home/user/mid"},"context_window":{"context_window_size":200000,"used_percentage":55,"current_usage":{"input_tokens":80000,"cache_creation_input_tokens":20000,"cache_read_input_tokens":10000}}}'

    integ_test "cwd fallback (no workspace)" \
        '{"model":{"display_name":"Opus 4.6"},"workspace":{"current_dir":"/home/user/fallback","project_dir":"/home/user/fallback"},"context_window":{"context_window_size":200000,"used_percentage":10}}'

    integ_test "defaults (minimal context)" \
        '{"model":{"display_name":"Haiku 4.5"},"workspace":{"current_dir":"/tmp","project_dir":"/tmp"}}'

    echo
}

# ── Main ────────────────────────────────────────────────────

case "${1:-all}" in
    --unit)  run_unit_tests ;;
    --integ) run_integration_tests ;;
    *)       run_unit_tests; run_integration_tests ;;
esac

echo "━━━ Results: $(green "$PASS pass"), $(red "$FAIL fail"), $(dim "$SKIP skip") ━━━"
[ "$FAIL" -eq 0 ]
