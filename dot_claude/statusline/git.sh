#!/bin/bash
# statusline/git.sh — Git branch + file-status segment
# Requires: colors.sh sourced beforehand (MAGENTA, GREEN, YELLOW, RED, CYAN, RESET).
# Sets:      GIT_SEGMENT (empty string when not in a git repo or detached HEAD)

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
