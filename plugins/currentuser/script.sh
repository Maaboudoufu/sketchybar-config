#!/bin/bash

# This file keeps its historical path because the More-menu item id is
# intentionally preserved. It now displays Codex subscription usage.

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
RELPATH="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
source "$RELPATH/set_colors.sh"

read -r five_hour weekly <<<"$(python3 "$RELPATH/plugins/usage/codex-rate-limits.py" 2>/dev/null || true)"

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
