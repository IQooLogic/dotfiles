#!/bin/bash
# statusline/colors.sh — ANSI color constants, colored() helper, and build_bar()
# Sourced by statusline.sh and all sub-modules.

RESET=$'\033[0m'
GRAY=$'\033[90m'
RED=$'\033[31m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
MAGENTA=$'\033[35m'
CYAN=$'\033[36m'
ORANGE=$'\033[38;5;214m'
BLUE=$'\033[38;5;27m'

# colored COLOR TEXT — wrap TEXT in COLOR then reset
colored() { printf '%s%s%s' "$1" "$2" "$RESET"; }

# build_bar PCT WIDTH — print a coloured block-character progress bar.
#   Colour thresholds: >=90 RED, >=70 YELLOW, >=50 ORANGE, else GREEN.
build_bar() {
    local pct=$1 width=$2
    [ "$pct" -lt 0 ]   2>/dev/null && pct=0
    [ "$pct" -gt 100 ] 2>/dev/null && pct=100
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local bar_color
    if   [ "$pct" -ge 90 ]; then bar_color="$RED"
    elif [ "$pct" -ge 70 ]; then bar_color="$YELLOW"
    elif [ "$pct" -ge 50 ]; then bar_color="$ORANGE"
    else                         bar_color="$GREEN"
    fi
    local filled_str="" empty_str="" i
    for ((i=0; i<filled; i++)); do filled_str+="█"; done
    for ((i=0; i<empty;  i++)); do empty_str+="░";  done
    printf '%s%s%s%s%s' "$bar_color" "$filled_str" "$GRAY" "$empty_str" "$RESET"
}
