#!/bin/bash
# statusline/usage_api.sh — Anthropic Teams plan usage (5-hour & 7-day windows)
# Requires: colors.sh sourced beforehand (build_bar, colored, color constants).
# Outputs:  Prints a second status line when usage data is available.
# Side-effects: reads/writes $_CACHE_FILE (TTL-controlled cache)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
_CACHE_DIR="/tmp/claude"
_CACHE_FILE="$_CACHE_DIR/statusline-usage-cache.json"
_DEBUG_FILE="$_CACHE_DIR/statusline-usage-debug.json"
_ERR_FILE="$_CACHE_DIR/statusline-curl-err.txt"
_CREDS_PATH="$HOME/.claude/.credentials.json"
_CACHE_TTL=60        # seconds
_USAGE_BAR_WIDTH=8   # block characters per bar
_API_URL="https://api.anthropic.com/api/oauth/usage"
_API_BETA_HEADER="anthropic-beta: oauth-2025-04-20"
_USER_AGENT="claude-code/2.1.34"
_CURL_TIMEOUT=8      # seconds

# jq filter: extract all needed fields as @tsv; emits nothing when .five_hour absent.
_JQ_USAGE_FILTER='
    if .five_hour then
      [
        (.five_hour.utilization  | if . then round else 0 end | tostring),
        (.five_hour.resets_at   // ""),
        (.seven_day.utilization  | if . then round else 0 end | tostring),
        (.seven_day.resets_at   // ""),
        (.extra_usage.is_enabled // false | tostring),
        (.extra_usage.utilization  | if . then round else 0 end | tostring),
        (.extra_usage.used_credits  // 0 | tostring),
        (.extra_usage.monthly_limit // 0 | tostring)
      ] | @tsv
    else empty
    end'

# --- Helpers ---

# _format_reset_time ISO_STR STYLE — convert ISO 8601 to compact local time
#   STYLE "time"     → "3:45pm"
#   STYLE "datetime" → "Mar 5, 3:45pm"
_format_reset_time() {
    local iso_str="$1" style="$2"
    [ -z "$iso_str" ] || [ "$iso_str" = "null" ] && return
    # Strip sub-second precision (e.g. .000) which confuses some date versions
    iso_str="${iso_str%%.*}"
    # Append Z only when no explicit timezone offset (+HH:MM / -HH:MM / +HHMM) is present.
    [[ "$iso_str" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{2}:?[0-9]{2}$ ]] \
        || iso_str="${iso_str}Z"
    local epoch
    epoch=$(date -d "$iso_str" +%s 2>/dev/null) || return
    [ -z "$epoch" ] && return
    case "$style" in
        time)     LC_TIME=C date -d "@$epoch" +"%l:%M%P"         | sed 's/^ //' ;;
        datetime) LC_TIME=C date -d "@$epoch" +"%b %-d, %l:%M%P" | sed 's/ \+/ /g; s/^ //' ;;
    esac
}

# _fetch_usage_json — call the API and return JSON on stdout.
#   Writes debug info to $_DEBUG_FILE. Returns nothing on failure.
_fetch_usage_json() {
    local token
    token=$(jq -r '.claudeAiOauth.accessToken // empty' "$_CREDS_PATH" 2>/dev/null)
    [ -z "$token" ] && return

    local json curl_exit
    json=$(curl -s --max-time "$_CURL_TIMEOUT" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $token" \
        -H "$_API_BETA_HEADER" \
        -H "User-Agent: $_USER_AGENT" \
        "$_API_URL" 2>"$_ERR_FILE")
    curl_exit=$?

    # Always write debug so we can inspect what the API returned.
    { echo "exit=$curl_exit"; echo "$json"; } > "$_DEBUG_FILE"

    if echo "$json" | jq -e '.five_hour' > /dev/null 2>&1; then
        echo "$json"
    fi
}

# _load_usage_json — return JSON from cache when fresh, else fetch and re-cache.
_load_usage_json() {
    mkdir -p "$_CACHE_DIR"

    # Remove empty/corrupt cache files so they don't linger.
    if [ -f "$_CACHE_FILE" ] && ! [ -s "$_CACHE_FILE" ]; then
        rm -f "$_CACHE_FILE"
    fi

    if [ -f "$_CACHE_FILE" ] && [ -s "$_CACHE_FILE" ]; then
        local age=$(( $(date +%s) - $(stat -c %Y "$_CACHE_FILE" 2>/dev/null || echo 0) ))
        if [ "$age" -lt "$_CACHE_TTL" ]; then
            cat "$_CACHE_FILE"
            return
        fi
    fi

    local json
    json=$(_fetch_usage_json)
    if [ -n "$json" ]; then
        echo "$json" > "$_CACHE_FILE"
        echo "$json"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
_USAGE_JSON=$(_load_usage_json)

if [ -n "$_USAGE_JSON" ]; then
    # Single jq call (using the named filter) extracts all fields as tab-separated values.
    # Outputs nothing (empty) when .five_hour is absent.
    read -r _FIVE_PCT _FIVE_RESET _WEEK_PCT _WEEK_RESET _EXTRA_ENABLED _EXTRA_PCT _EXTRA_USED _EXTRA_LIMIT \
      < <(echo "$_USAGE_JSON" | jq -r "$_JQ_USAGE_FILTER")

    # If .five_hour was absent jq emitted nothing and $_FIVE_PCT is empty; bail out.
    [ -z "$_FIVE_PCT" ] && {
        unset _USAGE_JSON _FIVE_PCT _FIVE_RESET _WEEK_PCT _WEEK_RESET \
              _EXTRA_ENABLED _EXTRA_PCT _EXTRA_USED _EXTRA_LIMIT
        unset -f _format_reset_time _fetch_usage_json _load_usage_json
        unset _CACHE_DIR _CACHE_FILE _DEBUG_FILE _ERR_FILE _CREDS_PATH \
              _CACHE_TTL _USAGE_BAR_WIDTH _API_URL _API_BETA_HEADER \
              _USER_AGENT _CURL_TIMEOUT _JQ_USAGE_FILTER
        return 0
    }

    _FIVE_BAR=$(build_bar "$_FIVE_PCT" "$_USAGE_BAR_WIDTH")
    _WEEK_BAR=$(build_bar "$_WEEK_PCT" "$_USAGE_BAR_WIDTH")

    _FIVE_RESET_FMT=$(_format_reset_time "$_FIVE_RESET" "time")
    _WEEK_RESET_FMT=$(_format_reset_time "$_WEEK_RESET" "datetime")

    _FIVE_LABEL="5h: ${_FIVE_BAR} ${_FIVE_PCT}%"
    [ -n "$_FIVE_RESET_FMT" ] && _FIVE_LABEL="${_FIVE_LABEL} • $(colored "$BLUE" "") ${_FIVE_RESET_FMT}"

    _WEEK_LABEL="7d: ${_WEEK_BAR} ${_WEEK_PCT}%"
    [ -n "$_WEEK_RESET_FMT" ] && _WEEK_LABEL="${_WEEK_LABEL} • $(colored "$BLUE" "") ${_WEEK_RESET_FMT}"

    _LINE2="$(colored "$GREEN" "") ${_FIVE_LABEL} 󰇙 $(colored "$GREEN" "󰺏") ${_WEEK_LABEL}"

    # Extra credits block (only shown when the feature is enabled on the account).
    if [ "$_EXTRA_ENABLED" = "true" ]; then
        _EXTRA_BAR=$(build_bar "$_EXTRA_PCT" "$_USAGE_BAR_WIDTH")
        _LINE2="${_LINE2}  $(colored "$GRAY" "💳") extra: ${_EXTRA_BAR} $(colored "$GRAY" "${_EXTRA_PCT}% (${_EXTRA_USED}/${_EXTRA_LIMIT})")"
    fi

    printf '%s\n' "$_LINE2"
fi

# ---------------------------------------------------------------------------
# Cleanup private vars and functions
# ---------------------------------------------------------------------------
unset _USAGE_JSON _FIVE_PCT _FIVE_RESET _WEEK_PCT _WEEK_RESET \
      _EXTRA_ENABLED _EXTRA_PCT _EXTRA_USED _EXTRA_LIMIT \
      _FIVE_BAR _WEEK_BAR _FIVE_RESET_FMT _WEEK_RESET_FMT \
      _FIVE_LABEL _WEEK_LABEL _EXTRA_BAR _LINE2
unset -f _format_reset_time _fetch_usage_json _load_usage_json
unset _CACHE_DIR _CACHE_FILE _DEBUG_FILE _ERR_FILE _CREDS_PATH \
      _CACHE_TTL _USAGE_BAR_WIDTH _API_URL _API_BETA_HEADER \
      _USER_AGENT _CURL_TIMEOUT _JQ_USAGE_FILTER
