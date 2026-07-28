#!/bin/bash

# This file keeps its historical path because the More-menu item id is
# intentionally preserved. It now displays Claude Code subscription usage.

RELPATH="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
source "$RELPATH/set_colors.sh"

set_usage_label() {
  local five_hour="$1" weekly="$2" label color max

  if [[ "$five_hour" =~ ^[0-9]+$ && "$weekly" =~ ^[0-9]+$ ]]; then
    label="${five_hour}% · ${weekly}%"
    max=$(( five_hour > weekly ? five_hour : weekly ))
    if ((max >= 90)); then
      color=$CRITICAL
    elif ((max >= 70)); then
      color=$WARN
    elif ((max >= 50)); then
      color=$NOTICE
    else
      color=$TEXT
    fi
  else
    label="--"
    color=$TEXT
  fi

  sketchybar --set "${NAME:?}" label="$label" label.color=$color 2>/dev/null
}

claude_usage() {
  local credentials token response

  if [[ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]]; then
    token="$CLAUDE_CODE_OAUTH_TOKEN"
  elif [[ -n "${CLAUDE_USAGE_TOKEN_FILE:-}" && -r "$CLAUDE_USAGE_TOKEN_FILE" ]]; then
    token="$(<"$CLAUDE_USAGE_TOKEN_FILE")"
  else
    credentials="$(security find-generic-password \
      -s "${CLAUDE_KEYCHAIN_SERVICE:-Claude Code-credentials}" -w 2>/dev/null)" || return 1
    token="$(printf '%s' "$credentials" | jq -er '.claudeAiOauth.accessToken // empty' 2>/dev/null)" || return 1
  fi

  [[ -n "$token" ]] || return 1
  response="$(curl --fail --silent --show-error \
    --connect-timeout 3 --max-time 10 \
    -H "Authorization: Bearer $token" \
    -H "Accept: application/json" \
    "${CLAUDE_USAGE_URL:-https://api.anthropic.com/api/oauth/usage}" 2>/dev/null)" || return 1

  printf '%s' "$response" | jq -er '
    def pct: select(type == "number" and . >= 0 and . <= 100) | round;
    "\(.five_hour.utilization | pct) \(.seven_day.utilization | pct)"
  ' 2>/dev/null
}

read -r five_hour weekly <<<"$(claude_usage || true)"
set_usage_label "$five_hour" "$weekly"
