#!/bin/bash

##
# Renders live CPU and RAM into the two More-menu usage slots.
#
# One macmon sample feeds BOTH items. moremenu.pkgs's script calls this and it
# sets moremenu.user too, rather than each item sampling for itself: macmon
# costs ~0.65s per spawn, and the two figures should come from the same instant
# anyway. moremenu.user's own script no-ops while this mode is active.
##

RELPATH="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
source "$RELPATH/set_colors.sh"
source "$RELPATH/plugins/usage/lib.sh"

FONT="${1:-SF Pro}"

ICON_CPU=􀫥 # SF Symbols "cpu"
ICON_RAM=􀫦 # SF Symbols "memorychip"

# cpu_active_ratio, not cpu_usage_pct: despite the name, macmon sets
# cpu_usage_pct to cpu_scaled_ratio, which weights each core by how far below
# its maximum frequency it is running. On an idle machine that reads ~4% where
# top and Activity Monitor both say ~7%, because the cores are busy but clocked
# down. active_ratio is the plain busy fraction and tracks top at every load.
read -r CPU RAM < <(
	macmon pipe -s 1 -i 1 2>/dev/null |
		jq -r '"\(.cpu_active_ratio * 100 | round) \(.memory.ram_usage / .memory.ram_total * 100 | round)"'
)
# macmon is an optional brew formula and can be absent or fail.
: "${CPU:=0}" "${RAM:=0}"

usage_color "$CPU"
CPU_COLOR=$USAGE_COLOR
usage_color "$RAM"
RAM_COLOR=$USAGE_COLOR

# CPU goes in the user slot and RAM in the pkgs slot, not the other way round:
# both items are right-anchored, so pkgs draws to the RIGHT of user, and the
# pairing below is what makes it read "CPU then RAM" left-to-right.
#
# icon.background.drawing=off hides the Claude mascot image that occupies the
# pkgs slot in AI mode; packages/script.sh switches it back on when it renders.
# The user slot needs its icon.font moved off sketchybar-app-font, which has no
# SF Symbols glyphs and would draw tofu.
usage_render sys \
	--set moremenu.user \
	icon="$ICON_CPU" icon.font="$FONT:Regular:14.0" icon.color=$SELECT \
	label="${CPU}%" label.color=$CPU_COLOR \
	--set moremenu.pkgs \
	icon="$ICON_RAM" icon.font="$FONT:Regular:14.0" icon.color=$SELECT \
	icon.background.drawing=off \
	label="${RAM}%" label.color=$RAM_COLOR
