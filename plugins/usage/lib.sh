#!/bin/bash

##
# Shared state + colour thresholds for the two More-menu usage slots.
#
# moremenu.pkgs and moremenu.user normally show Claude / Codex subscription
# usage. Clicking either one flips both to live CPU / RAM and back; this file
# is what the three render scripts agree on.
#
# Must be sourced AFTER set_colors.sh — usage_color reads $CRITICAL/$WARN/etc.
##

# Marker file present = system mode, absent = AI usage mode. Same
# ${TMPDIR}sketchybar convention as the music/volume slide marker.
USAGE_MODE_FILE="${TMPDIR}sketchybar/usage_mode"

# TMPDIR is wiped on reboot, so the directory has to be created by whoever gets
# here first. Without this the caches below silently fail to write until the
# first toggle, which is exactly when they are first needed.
mkdir -p "${USAGE_MODE_FILE%/*}"

usage_in_system_mode() { [ -f "$USAGE_MODE_FILE" ]; }

# Replay cache. Fetching either mode's numbers is slow — macmon costs ~0.9s per
# spawn and the Claude usage endpoint is a network round-trip with a 10s ceiling
# — so a toggle that waits for them leaves the old mode on screen for about a
# second. Instead every render hands its final sketchybar arguments here, and
# toggle.sh replays the target mode's last set on click: the icons and layout
# swap in ~20ms and the numbers correct themselves when the fetch lands.
#
# One argument per line: labels contain spaces and '·'.
usage_cache_file() { printf '%s/usage_cache_%s' "${USAGE_MODE_FILE%/*}" "$1"; }

usage_render() { # $1 = cache key ("sys" or "ai_*"), rest = sketchybar args
	local key=$1
	shift
	printf '%s\n' "$@" >"$(usage_cache_file "$key")"

	# Every render checks the mode on entry and then blocks for about a second
	# fetching numbers — long enough for a click to flip the mode underneath it.
	# Dropping the paint here, where all three render scripts converge, is what
	# stops a late arrival from putting the old mode back on screen. The cache
	# above is still written, so the next toggle replays these fresh numbers.
	local want=ai
	usage_in_system_mode && want=sys
	[ "${key%%_*}" = "$want" ] || return 0

	sketchybar "$@"
}

usage_replay() { # $@ = the cache keys that make up one mode's display
	local args=() line key file
	for key in "$@"; do
		file="$(usage_cache_file "$key")"
		[ -r "$file" ] || continue
		while IFS= read -r line; do args+=("$line"); done <"$file"
	done
	((${#args[@]})) && sketchybar "${args[@]}"
}

# $1 = 0-100 -> sets $USAGE_COLOR. Shared so a quota at 80% and a CPU at 80%
# read as the same severity instead of drifting apart in three copies.
usage_color() {
	if (($1 >= 90)); then
		USAGE_COLOR=$CRITICAL
	elif (($1 >= 70)); then
		USAGE_COLOR=$WARN
	elif (($1 >= 50)); then
		USAGE_COLOR=$NOTICE
	else
		USAGE_COLOR=$TEXT
	fi
}
