#!/bin/bash
# statusline/usage_api.sh — Anthropic Teams plan usage (5-hour & 7-day windows)
# Requires: colors.sh sourced beforehand.
# Outputs:  Prints a second status line when usage data is available.
# Side-effects: reads/writes /tmp/claude/statusline-usage-cache.json (60-second TTL)

_CACHE_DIR="/tmp/claude"
_CACHE_FILE="$_CACHE_DIR/statusline-usage-cache.json"
_CREDS_PATH="$HOME/.claude/.credentials.json"
_CACHE_TTL=60   # seconds

# --- Helpers ---

# _build_usage_bar PCT WIDTH — print a coloured block-character bar
_build_usage_bar() {
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

# _format_reset_time ISO_STR STYLE — convert ISO 8601 to compact local time
#   STYLE "time"     → "3:45pm"
#   STYLE "datetime" → "Mar 5, 3:45pm"
_format_reset_time() {
    local iso_str="$1" style="$2"
    [ -z "$iso_str" ] || [ "$iso_str" = "null" ] && return
    local epoch
    epoch=$(date -d "$iso_str" +%s 2>/dev/null) || return
    case "$style" in
        time)     LC_TIME=C date -d "@$epoch" +"%l:%M%P"        | sed 's/^ //' ;;
        datetime) LC_TIME=C date -d "@$epoch" +"%b %-d, %l:%M%P" | sed 's/ \+/ /g; s/^ //' ;;
    esac
}

# --- Fetch or load cached usage JSON ---
_load_usage_json() {
    mkdir -p "$_CACHE_DIR"

    if [ -f "$_CACHE_FILE" ]; then
        local age=$(( $(date +%s) - $(stat -c %Y "$_CACHE_FILE" 2>/dev/null || echo 0) ))
        if [ "$age" -lt "$_CACHE_TTL" ]; then
            cat "$_CACHE_FILE"
            return
        fi
    fi

    local token
    token=$(jq -r '.claudeAiOauth.accessToken // empty' "$_CREDS_PATH" 2>/dev/null)
    [ -z "$token" ] && return

    local json
    json=$(curl -s --max-time 5 \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $token" \
        -H "anthropic-beta: oauth-2025-04-20" \
        -H "User-Agent: claude-code/2.1.34" \
        "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)

    if echo "$json" | jq -e '.five_hour' > /dev/null 2>&1; then
        echo "$json" > "$_CACHE_FILE"
        echo "$json"
    fi
}

# --- Main ---
_USAGE_JSON=$(_load_usage_json)

if [ -n "$_USAGE_JSON" ] && echo "$_USAGE_JSON" | jq -e '.five_hour' > /dev/null 2>&1; then
    _FIVE_PCT=$(echo "$_USAGE_JSON"   | jq -r '.five_hour.utilization  | if . then round else 0 end')
    _FIVE_RESET=$(echo "$_USAGE_JSON" | jq -r '.five_hour.resets_at   // empty')
    _WEEK_PCT=$(echo "$_USAGE_JSON"   | jq -r '.seven_day.utilization  | if . then round else 0 end')
    _WEEK_RESET=$(echo "$_USAGE_JSON" | jq -r '.seven_day.resets_at   // empty')

    _FIVE_BAR=$(_build_usage_bar "$_FIVE_PCT" 8)
    _WEEK_BAR=$(_build_usage_bar "$_WEEK_PCT" 8)

    _FIVE_RESET_FMT=$(_format_reset_time "$_FIVE_RESET" "time")
    _WEEK_RESET_FMT=$(_format_reset_time "$_WEEK_RESET" "datetime")

    _FIVE_LABEL="5h: ${_FIVE_BAR} ${_FIVE_PCT}%"
    [ -n "$_FIVE_RESET_FMT" ] && _FIVE_LABEL="${_FIVE_LABEL} ↺ ${_FIVE_RESET_FMT}"

    _WEEK_LABEL="7d: ${_WEEK_BAR} ${_WEEK_PCT}%"
    [ -n "$_WEEK_RESET_FMT" ] && _WEEK_LABEL="${_WEEK_LABEL} ↺ ${_WEEK_RESET_FMT}"

    _LINE2="$(colored "$GRAY" "🕔") ${_FIVE_LABEL}  $(colored "$GRAY" "📅") ${_WEEK_LABEL}"

    # Extra credits block (only shown when the feature is enabled on the account)
    _EXTRA_ENABLED=$(echo "$_USAGE_JSON" | jq -r '.extra_usage.is_enabled // false')
    if [ "$_EXTRA_ENABLED" = "true" ]; then
        _EXTRA_PCT=$(echo "$_USAGE_JSON"  | jq -r '.extra_usage.utilization  | if . then round else 0 end')
        _EXTRA_USED=$(echo "$_USAGE_JSON" | jq -r '.extra_usage.used_credits  // 0')
        _EXTRA_LIMIT=$(echo "$_USAGE_JSON"| jq -r '.extra_usage.monthly_limit // 0')
        _EXTRA_BAR=$(_build_usage_bar "$_EXTRA_PCT" 8)
        _LINE2="${_LINE2}  $(colored "$GRAY" "💳") extra: ${_EXTRA_BAR} $(colored "$GRAY" "${_EXTRA_PCT}% (${_EXTRA_USED}/${_EXTRA_LIMIT})")"
    fi

    printf '%s\n' "$_LINE2"
fi
