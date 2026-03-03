#!/bin/bash

# --- Colors ---
RESET=$'\033[0m'
GRAY=$'\033[90m'
RED=$'\033[31m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
MAGENTA=$'\033[35m'
CYAN=$'\033[36m'
ORANGE=$'\033[38;5;214m'

# --- Helper functions ---

# colored COLOR TEXT — wrap text in a color then reset
colored() { printf '%s%s%s' "$1" "$2" "$RESET"; }

# --- Read JSON input ---
input=$(cat)
MODEL_DISPLAY=$(echo "$input" | jq -r '.model.display_name')
CURRENT_DIR=$(echo  "$input" | jq -r '.workspace.current_dir')
PROJECT_DIR=$(echo  "$input" | jq -r '.workspace.project_dir')
CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size')
USAGE=$(echo        "$input" | jq    '.context_window.current_usage')
TRANSCRIPT_PATH=$(echo "$input" | jq -r '.transcript_path // empty')

# --- Context window usage percentage ---
PERCENT_USED=0
if [ "$USAGE" != "null" ]; then
    CURRENT_TOKENS=$(echo "$USAGE" | jq '.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens')
    PERCENT_USED=$(( CURRENT_TOKENS * 100 / CONTEXT_SIZE ))
fi

# --- Git: branch, staged count, modified count ---
GIT_SEGMENT=""
if git -c gc.auto=0 rev-parse --git-dir > /dev/null 2>&1; then
    BRANCH=$(git -c gc.auto=0 branch --show-current 2>/dev/null)
    if [ -n "$BRANCH" ]; then
        STAGED=$(git -c gc.auto=0 diff --cached --name-only --diff-filter=d 2>/dev/null | wc -l | tr -d ' ')
        MODIFIED=$(git -c gc.auto=0 diff --name-only --diff-filter=d 2>/dev/null | wc -l | tr -d ' ')
        DELETED_STAGED=$(git -c gc.auto=0 diff --cached --name-only --diff-filter=D 2>/dev/null | wc -l | tr -d ' ')
        DELETED_UNSTAGED=$(git -c gc.auto=0 diff --name-only --diff-filter=D 2>/dev/null | wc -l | tr -d ' ')
        DELETED=$(( DELETED_STAGED + DELETED_UNSTAGED ))
        UNTRACKED=$(git -c gc.auto=0 ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
        GIT_SEGMENT="$(colored "$MAGENTA" "$BRANCH")"
        [ "$STAGED"    -gt 0 ] && GIT_SEGMENT="${GIT_SEGMENT} $(colored "$GREEN"  "+${STAGED}")"
        [ "$MODIFIED"  -gt 0 ] && GIT_SEGMENT="${GIT_SEGMENT} $(colored "$YELLOW" "~${MODIFIED}")"
        [ "$DELETED"   -gt 0 ] && GIT_SEGMENT="${GIT_SEGMENT} $(colored "$RED"    "-${DELETED}")"
        [ "$UNTRACKED" -gt 0 ] && GIT_SEGMENT="${GIT_SEGMENT} $(colored "$CYAN"   "?${UNTRACKED}")"
    fi
fi

# --- Context progress bar (10 chars, filled=color, empty=gray) ---
BAR_WIDTH=10
FILLED=$(( PERCENT_USED * BAR_WIDTH / 100 ))
EMPTY=$(( BAR_WIDTH - FILLED ))
if   [ "$PERCENT_USED" -ge 80 ]; then BAR_COLOR="$RED"
elif [ "$PERCENT_USED" -ge 50 ]; then BAR_COLOR="$YELLOW"
else                                   BAR_COLOR="$GREEN"
fi
FILLED_STR="" EMPTY_STR=""
for i in $(seq 1 $FILLED); do FILLED_STR="${FILLED_STR}█"; done
for i in $(seq 1 $EMPTY);  do EMPTY_STR="${EMPTY_STR}░";  done
CTX_BAR="$(colored "$BAR_COLOR" "$FILLED_STR")$(colored "$GRAY" "$EMPTY_STR") ${PERCENT_USED}%"

# --- Assemble and print status line ---
printf '🧠 [%s] • 📦 %s • 🌿 %s • 🔥 %s • 📁 %s\n' \
    "$(colored "$ORANGE"   "$MODEL_DISPLAY")" \
    "$(colored "$CYAN"     "${CURRENT_DIR##*/}")" \
    "$GIT_SEGMENT" \
    "$CTX_BAR" \
    "$(colored "$GRAY" "$PROJECT_DIR")"
