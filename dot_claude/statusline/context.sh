#!/bin/bash
# statusline/context.sh — Context-window progress bar and token-usage label
# Requires: colors.sh sourced beforehand (build_bar, colored, color constants).
# Inputs (variables that must exist before sourcing):
#   PERCENT_USED         — integer 0-100
#   CURRENT_TOKEN_USAGE  — integer token count for the current call
#   CONTEXT_SIZE         — integer total context window size
# Sets:
#   CTX_BAR   — coloured block-character progress bar + percentage
#   CTX_USAGE — "(Nk/Mk)" label

# --- Configuration ---
_CTX_BAR_WIDTH=10

# --- Progress bar ---
CTX_BAR="$(build_bar "$PERCENT_USED" "$_CTX_BAR_WIDTH") ${PERCENT_USED}%"

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

# --- Cleanup private vars ---
unset _CTX_BAR_WIDTH
unset -f _fmt_k
