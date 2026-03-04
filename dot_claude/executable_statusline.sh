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

# --- 2. Parse JSON input (single jq call) ---
input=$(cat)
IFS=$'\t' read -r MODEL_DISPLAY CURRENT_DIR PROJECT_DIR CONTEXT_SIZE PERCENT_USED CURRENT_TOKEN_USAGE \
  < <(echo "$input" | jq -r '[
    .model.display_name,
    .workspace.current_dir,
    .workspace.project_dir,
    (.context_window.context_window_size // 200000 | tostring),
    (.context_window.used_percentage // 0 | floor | tostring),
    ((.context_window.current_usage // null) |
      if . == null then "0"
      else ((.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0) | tostring)
      end)
  ] | @tsv')

# --- 3. Git segment ---
# shellcheck source=statusline/git.sh
source "$_DIR/statusline/git.sh"

# --- 4. Context bar + usage label ---
# shellcheck source=statusline/context.sh
source "$_DIR/statusline/context.sh"

# --- 5. Line 1: main status ---
printf ' [%s] •  %s •  %s • 󰈸 %s %s •  %s\n' \
    "$(colored "$CLAUDE_MODEL" "$MODEL_DISPLAY")" \
    "$(colored "$PROJECT"     "${CURRENT_DIR##*/}")" \
    "$GIT_SEGMENT" \
    "$CTX_BAR" \
    "$(colored "$GHOST"        "$CTX_USAGE")" \
    "$(colored "$PATH_COL"      "$PROJECT_DIR")"

# --- 6. Line 2: Teams plan usage (printed only when available) ---
# shellcheck source=statusline/usage_api.sh
source "$_DIR/statusline/usage_api.sh"
