#!/bin/bash
export RELPATH=$(dirname $0)/../..
source $RELPATH/log_handler.sh
source $RELPATH/plugins/music/collision.sh
shopt -s expand_aliases
command -v 'ft-haptic' 2>/dev/null 1>&2 || alias ft-haptic="$RELPATH/ft-haptic"

# A fast second click (e.g. a plain click immediately followed by an
# alt-click) can start a second instance of this script while the first is
# still mid-dispatch: STATE/GRAPHSTATE below are a one-time snapshot at
# process start, but menu_set()/graph_set() don't write $NAME's icon back
# until after several sketchybar round-trips, so the second instance can read
# the pre-flip icon and dispatch into a different branch than the first is
# still running — e.g. opening the CPU graph while more-menu's own open is
# still in flight. Serialize on $NAME so the second instance's snapshot is
# always taken after the first instance has fully finished, not mid-flight.
LOCKDIR="${TMPDIR}sketchybar/more-menu"
mkdir -p "$LOCKDIR"
LOCKFILE="$LOCKDIR/$NAME.lock"
until (set -o noclobber; : >"$LOCKFILE") 2>/dev/null; do sleep 0.05; done
trap 'rm -f "$LOCKFILE"' EXIT

## Default and global settings
menuitems=($1) # What items will be in the moremenu
INNER_PADDINGS=$2
FONT="$3"
NOTCH_WIDTH=${4:-180}
BAR_HEIGHT=${5:-34}

## Define state depending on the icon of the separator (this is a bad practice tho)
ICON_VALUE="$(sketchybar --query $NAME | sed 's/\\n//g; s/\\\$//g; s/\\ //g' | jq -r '.icon.value')"
GRAPHSTATE="$(sketchybar --query graph | sed 's/\\n//g; s/\\\$//g; s/\\ //g' | jq -r '.geometry.drawing')"

if [[ $ICON_VALUE = '|' ]]; then
	STATE=on
else
	STATE=off
fi

## Internal functions
menu_set() {
	sendLog "Toggle moremenu to $1" "debug"

	# Kick off music's shrink/restore before touching the menu items
	# themselves, not after: each item in the loop below is its own
	# sketchybar IPC round-trip, so calling this afterward (as it used to)
	# meant Spotify visibly lagged behind the rest of the menu by however
	# long that loop took, on top of its own animation. Starting it first
	# lets both move at once instead of one waiting on the other.
	if [ $1 = "on" ]; then
		music_shrink_for_notch more-menu "$NOTCH_WIDTH" "$BAR_HEIGHT"
		# `drawing` is a boolean, not an animatable property: the reveal
		# below pops the pill in at full size instantly no matter what
		# --animate duration wraps it, while the shrink just kicked off is a
		# genuine multi-frame animation — confirmed by watching drawing=on
		# render at full size on the very first frame even under a
		# deliberately long tanh 90. Without this head start the pill lands
		# on top of music's still-full-size artwork/text for several frames
		# until the shrink catches up. This is well under the shrink's own
		# tanh 15 (see collision.sh) but is enough real time for it to have
		# cleared the pill's footprint first.
		sleep 0.12
	else
		music_release_for_notch more-menu "$BAR_HEIGHT"
	fi

	# One sketchybar invocation, not one per item: each iteration used to
	# spawn its own sketchybar process plus an echo|sed pipeline just to
	# turn "__" back into a space in the item name — three process spawns
	# per item, four items, all landing at the daemon staggered by however
	# long each spawn took relative to the others. A single batched --set
	# call is what makes them actually move together instead of a rolling
	# cascade the music shrink then has to race to catch up with.
	local set_args=()
	for item in ${menuitems[@]}; do
		set_args+=(--set "${item//__/ }" drawing=$1)
	done
	sketchybar --animate tanh 15 "${set_args[@]}"
	sendLog "Set \"${menuitems[*]}\" drawing to $1" "vomit"

	# When setting to on, then update menu items
	if [ $1 = "on" ]; then
		separator=(
			icon="|"
			icon.font="$FONT:Bold:16.0"
			icon.padding_left=0
			icon.padding_right=0
		)
		sketchybar --set $NAME icon.y_offset=2 \
			--animate tanh 15 \
			--set $NAME "${separator[@]}"
		sketchybar --trigger more-menu-update
	else
		separator=(
			icon="􀯶"
			icon.font="$FONT:Semibold:14.0"
			icon.padding_left=$INNER_PADDINGS
			icon.padding_right=$INNER_PADDINGS
		)
		sketchybar --set $NAME icon.y_offset=0 \
			--animate tanh 15 \
			--set $NAME "${separator[@]}"
	fi
}

graph_set() {
	sendLog "Toggle graph to $1" "debug"

	if [ $1 = "off" ]; then
		icon=􀯶
		music_release_for_notch cpu-graph "$BAR_HEIGHT"
	else
		icon=􀫰
		music_shrink_for_notch cpu-graph "$NOTCH_WIDTH" "$BAR_HEIGHT"
		sleep 0.12 # see the matching comment in menu_set()
	fi

	sketchybar --set '/graph.*/' drawing=$1 \
		--set $NAME icon=$icon \
		--trigger activities_update

	[ $1 = "off" ] && for ((i = 0; i <= 140; ++i)); do
		sketchybar --push graph 0.0
	done
}

## Main logic
case "$SENDER" in
"mouse.entered")
	ft-haptic -n 1
	;;
"mouse.clicked")
	if [ "$STATE" = "off" ]; then
		if [ "$MODIFIER" = "alt" ] && [ "$GRAPHSTATE" = "off" ]; then
			graph_set "on"
		elif [ $GRAPHSTATE = "on" ]; then
			graph_set "off"
		else
			menu_set "on"
		fi
	else
		menu_set "off"
	fi
	;;
esac
