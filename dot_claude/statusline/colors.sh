#!/bin/bash
# statusline/colors.sh — ANSI color constants and colored() helper
# Sourced by statusline.sh and all sub-modules.

RESET=$'\033[0m'
GRAY=$'\033[90m'
RED=$'\033[31m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
MAGENTA=$'\033[35m'
CYAN=$'\033[36m'
ORANGE=$'\033[38;5;214m'

# colored COLOR TEXT — wrap TEXT in COLOR then reset
colored() { printf '%s%s%s' "$1" "$2" "$RESET"; }
