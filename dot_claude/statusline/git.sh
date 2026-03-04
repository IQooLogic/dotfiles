#!/bin/bash
# statusline/git.sh — Git branch + file-status segment
# Requires: colors.sh sourced beforehand (BRANCH, CTX_LOW, MODIFIED, CTX_HIGH, UNTRACKED, RESET).
# Sets:      GIT_SEGMENT (empty string when not in a git repo or detached HEAD)

GIT_SEGMENT=""

if git -c gc.auto=0 rev-parse --git-dir > /dev/null 2>&1; then
    _GIT_BRANCH=$(git -c gc.auto=0 branch --show-current 2>/dev/null)
    if [ -n "$_GIT_BRANCH" ]; then
        _GIT_STAGED=$(git -c gc.auto=0 diff --cached --name-only --diff-filter=d 2>/dev/null | wc -l | tr -d ' ')
        _GIT_MODIFIED=$(git -c gc.auto=0 diff --name-only --diff-filter=d 2>/dev/null | wc -l | tr -d ' ')
        _GIT_DELETED_STAGED=$(git -c gc.auto=0 diff --cached --name-only --diff-filter=D 2>/dev/null | wc -l | tr -d ' ')
        _GIT_DELETED_UNSTAGED=$(git -c gc.auto=0 diff --name-only --diff-filter=D 2>/dev/null | wc -l | tr -d ' ')
        _GIT_DELETED=$(( _GIT_DELETED_STAGED + _GIT_DELETED_UNSTAGED ))
        _GIT_UNTRACKED=$(git -c gc.auto=0 ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')

        GIT_SEGMENT="$(colored "$BRANCH"    "$_GIT_BRANCH")"
        [ "$_GIT_STAGED"    -gt 0 ] && GIT_SEGMENT="${GIT_SEGMENT} $(colored "$CTX_LOW"   "+${_GIT_STAGED}")"
        [ "$_GIT_MODIFIED"  -gt 0 ] && GIT_SEGMENT="${GIT_SEGMENT} $(colored "$MODIFIED"  "~${_GIT_MODIFIED}")"
        [ "$_GIT_DELETED"   -gt 0 ] && GIT_SEGMENT="${GIT_SEGMENT} $(colored "$CTX_HIGH"  "-${_GIT_DELETED}")"
        [ "$_GIT_UNTRACKED" -gt 0 ] && GIT_SEGMENT="${GIT_SEGMENT} $(colored "$UNTRACKED" "?${_GIT_UNTRACKED}")"
    fi
fi

# --- Cleanup private vars ---
unset _GIT_BRANCH _GIT_STAGED _GIT_MODIFIED _GIT_DELETED_STAGED _GIT_DELETED_UNSTAGED _GIT_DELETED _GIT_UNTRACKED
