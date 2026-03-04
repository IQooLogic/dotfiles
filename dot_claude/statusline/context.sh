#!/bin/bash
# statusline/context.sh — Context-window progress bar and token-usage label
# Requires: colors.sh sourced beforehand (RED, YELLOW, GREEN, GRAY, RESET).
# Inputs (variables that must exist before sourcing):
#   PERCENT_USED         — integer 0-100
#   CURRENT_TOKEN_USAGE  — integer token count for the current call
#   CONTEXT_SIZE         — integer total context window size
# Sets:
#   CTX_BAR   — coloured block-character progress bar + percentage
#   CTX_USAGE — "(Nk/Mk)" label

# --- Progress bar (10 chars) ---
_BAR_WIDTH=10
_FILLED=$(( PERCENT_USED * _BAR_WIDTH / 100 ))
_EMPTY=$(( _BAR_WIDTH - _FILLED ))

if   [ "$PERCENT_USED" -ge 80 ]; then _BAR_COLOR="$RED"
elif [ "$PERCENT_USED" -ge 50 ]; then _BAR_COLOR="$YELLOW"
else                                   _BAR_COLOR="$GREEN"
fi

_FILLED_STR="" _EMPTY_STR=""
for _i in $(seq 1 "$_FILLED"); do _FILLED_STR="${_FILLED_STR}█"; done
for _i in $(seq 1 "$_EMPTY");  do _EMPTY_STR="${_EMPTY_STR}░";   done

CTX_BAR="$(colored "$_BAR_COLOR" "$_FILLED_STR")$(colored "$GRAY" "$_EMPTY_STR") ${PERCENT_USED}%"

# --- Token usage label (Nk/Mk) ---
_fmt_k() {
    local n=$1
    if [ "$n" -ge 1000 ]; then
        printf '%dk' $(( n / 1000 ))
    else
        printf '%d' "$n"
    fi
}

CTX_USAGE="($(_fmt_k "$CURRENT_TOKEN_USAGE")/$(_fmt_k "$CONTEXT_SIZE"))"
