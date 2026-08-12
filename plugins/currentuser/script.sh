#!/bin/bash

# This file keeps its historical path because the More-menu item id is
# intentionally preserved. It now displays Codex subscription usage.

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
RELPATH="$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)"
source "$RELPATH/set_colors.sh"
source "$RELPATH/plugins/usage/lib.sh"

# This slot doubles as the CPU readout, but moremenu.pkgs's script renders both
# halves from one macmon sample — so there is nothing to do here in that mode.
usage_in_system_mode && exit 0

read -r five_hour weekly <<<"$(python3 "$RELPATH/plugins/usage/codex-rate-limits.py" 2>/dev/null || true)"

if [[ "$five_hour" =~ ^([0-9]+|-)$ && "$weekly" =~ ^([0-9]+|-)$ ]] \
    && [[ "$five_hour" != "-" || "$weekly" != "-" ]]; then
    [[ "$five_hour" == "-" ]] && five_hour="--" || five_hour="${five_hour}%"
    [[ "$weekly" == "-" ]] && weekly="--" || weekly="${weekly}%"
    label="${five_hour} · ${weekly}"

	max=0
    [[ "$five_hour" =~ ^[0-9]+%$ ]] && max=${five_hour%%%}
    if [[ "$weekly" =~ ^[0-9]+%$ ]] && (( ${weekly%%%} > max )); then
        max=${weekly%%%}
    fi
	usage_color "$max"
	color=$USAGE_COLOR
else
	label="--"
	color=$TEXT
fi

# Restore the Codex icon and its app-font: system mode swaps both for an SF
# Symbols RAM glyph in the bar font, and this script runs on the way back.
usage_render ai_user --set "${NAME:?}" label="$label" label.color=$color \
	icon=":codex:" icon.font="sketchybar-app-font:Regular:15.0" icon.color=$SELECT 2>/dev/null
