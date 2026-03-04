#!/bin/bash
# statusline.sh — Claude Code status line entry point
#
# Modules (sourced in order):
#   statusline/colors.sh     — ANSI color constants + colored()
#   statusline/git.sh        — git branch + file-status segment  → $GIT_SEGMENT
#   statusline/context.sh    — context-window bar + token label  → $CTX_BAR, $CTX_USAGE
#   statusline/usage_api.sh  — Teams plan 5h/7d usage (line 2)

_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- 1. Colors (must be first; other modules depend on it) ---
# shellcheck source=statusline/colors.sh
source "$_DIR/statusline/colors.sh"

# --- 2. Parse JSON input ---
input=$(cat)
MODEL_DISPLAY=$(echo "$input" | jq -r '.model.display_name')
CURRENT_DIR=$(echo  "$input" | jq -r '.workspace.current_dir')
PROJECT_DIR=$(echo  "$input" | jq -r '.workspace.project_dir')
CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')

PERCENT_USED=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
CURRENT_TOKEN_USAGE=$(echo "$input" | jq -r '
  (.context_window.current_usage // null) |
  if . == null then 0
  else (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0)
  end
')

# --- 3. Git segment ---
# shellcheck source=statusline/git.sh
source "$_DIR/statusline/git.sh"

# --- 4. Context bar + usage label ---
# shellcheck source=statusline/context.sh
source "$_DIR/statusline/context.sh"

# --- 5. Line 1: main status ---
printf '🧠 [%s] • 📦 %s • 🌿 %s • 🔥 %s %s • 📁 %s\n' \
    "$(colored "$ORANGE" "$MODEL_DISPLAY")" \
    "$(colored "$CYAN"   "${CURRENT_DIR##*/}")" \
    "$GIT_SEGMENT" \
    "$CTX_BAR" \
    "$(colored "$GRAY"   "$CTX_USAGE")" \
    "$(colored "$GRAY"   "$PROJECT_DIR")"

# --- 6. Line 2: Teams plan usage (printed only when available) ---
# shellcheck source=statusline/usage_api.sh
source "$_DIR/statusline/usage_api.sh"
