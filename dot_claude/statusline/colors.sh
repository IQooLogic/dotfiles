#!/bin/bash
# statusline/colors.sh — ANSI color constants, colored() helper, and build_bar()
# Sourced by statusline.sh and all sub-modules.

RESET=$'\033[0m'

# Semantic color palette (RGB true-color)
CLAUDE_MODEL=$'\033[38;2;204;120;92m'   # warm terracotta  — model name
PROJECT=$'\033[38;2;167;139;250m'       # near-white slate — project dir
BRANCH=$'\033[38;2;246;201;14m'         # vivid yellow     — git branch
MODIFIED=$'\033[38;2;249;115;22m'       # orange           — modified files
UNTRACKED=$'\033[38;2;239;68;68m'       # red              — untracked files
CTX_LOW=$'\033[38;2;34;197;94m'         # green            — context <50% used
CTX_MED=$'\033[38;2;234;179;8m'         # amber            — context 50–79% used
CTX_HIGH=$'\033[38;2;239;68;68m'        # red              — context >=80% used
CTX_EMPTY=$'\033[38;2;30;41;59m'        # dark slate       — empty bar blocks
TIME=$'\033[38;2;56;189;248m'           # sky blue         — reset times / icons
GHOST=$'\033[38;2;148;163;184m'         # muted slate      — token labels, separators
PATH_COL=$'\033[38;2;71;85;105m'        # dim slate        — current directory

# Legacy aliases — keep old names working so no other script breaks
GRAY="$GHOST"
RED="$CTX_HIGH"
GREEN="$CTX_LOW"
YELLOW="$CTX_MED"
MAGENTA="$BRANCH"
CYAN="$UNTRACKED"
ORANGE="$CLAUDE_MODEL"
BLUE="$TIME"

# colored COLOR TEXT — wrap TEXT in COLOR then reset
colored() { printf '%s%s%s' "$1" "$2" "$RESET"; }

# build_bar PCT WIDTH — print a coloured block-character progress bar.
#   Colour thresholds: >=80 CTX_HIGH, >=50 CTX_MED, else CTX_LOW.
#   Empty blocks use CTX_EMPTY instead of GRAY for a dark-background-friendly look.
build_bar() {
    local pct=$1 width=$2
    [ "$pct" -lt 0 ]   2>/dev/null && pct=0
    [ "$pct" -gt 100 ] 2>/dev/null && pct=100
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local bar_color
    if   [ "$pct" -ge 80 ]; then bar_color="$CTX_HIGH"
    elif [ "$pct" -ge 50 ]; then bar_color="$CTX_MED"
    else                         bar_color="$CTX_LOW"
    fi
    local filled_str="" empty_str="" i
    for ((i=0; i<filled; i++)); do filled_str+="█"; done
    for ((i=0; i<empty;  i++)); do empty_str+="░";  done
    printf '%s%s%s%s%s' "$bar_color" "$filled_str" "$CTX_EMPTY" "$empty_str" "$RESET"
}
