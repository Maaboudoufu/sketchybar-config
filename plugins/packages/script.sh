#!/bin/bash

# This file keeps its historical path because the More-menu item id is
# intentionally preserved. It now displays Claude Code subscription usage.

RELPATH="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
source "$RELPATH/set_colors.sh"
source "$RELPATH/plugins/usage/lib.sh"

MASCOT_SIZE="${1:-22}"
MASCOT_SCALE="${2:-0.17}"
FONT="${3:-SF Pro}"

# This slot doubles as the RAM readout. In system mode hand off to system.sh,
# which renders RAM here and CPU into moremenu.user from a single macmon sample.
if usage_in_system_mode; then
  exec "$RELPATH/plugins/usage/system.sh" "$FONT"
fi

set_usage_label() {
  local five_hour="$1" weekly="$2" label color max

  if [[ "$five_hour" =~ ^[0-9]+$ && "$weekly" =~ ^[0-9]+$ ]]; then
    label="${five_hour}% · ${weekly}%"
    max=$(( five_hour > weekly ? five_hour : weekly ))
    usage_color "$max"
    color=$USAGE_COLOR
  else
    label="--"
    color=$TEXT
  fi

  # Restore the mascot icon: system mode swaps it for an SF Symbols CPU glyph,
  # and this script is what runs on the way back.
  usage_render ai_pkgs --set "${NAME:?}" label="$label" label.color=$color \
    icon=" " \
    icon.background.drawing=on \
    icon.background.image="$RELPATH/assets/claude-code-mascot.png" \
    icon.background.image.scale=$MASCOT_SCALE \
    icon.background.height=$MASCOT_SIZE 2>/dev/null
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
