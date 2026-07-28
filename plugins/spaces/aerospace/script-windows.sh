#!/bin/bash
export RELPATH=$(dirname $0)/../..
source "$RELPATH/../icon_map.sh"

##
# Aerospace workspace windows indicator
# This script updates workspace labels to show app icons for windows in each workspace
#	This script is ran by each space item and thus shouldn't update all the spaces but only the caller.
##

update_workspace_windows() {
	local workspace_id=$1
	local hide_empty=${2:-false}

	# Don't fight the logo's File/Edit/etc menu overlay: it hides every space
	# on demand, and this function would otherwise un-hide populated ones
	# again on the next focus-change event.
	if [ "$(sketchybar --query logo 2>/dev/null | jq -r '.geometry.background.drawing' 2>/dev/null)" = "on" ]; then
		return
	fi

	# Get apps in this workspace
	apps=$(aerospace list-windows --workspace "$workspace_id" --format '%{app-name}' 2>/dev/null | sort -u)

	FOCUSED_WORKSPACE=$(aerospace list-workspaces --focused 2>/dev/null)

	icon_strip=" "
	if [ "${apps}" != "" ]; then
		while read -r app; do
			icon_strip+=" $(
				__icon_map "$app"
				echo $icon_result
			)"
		done <<<"${apps}"
		sketchybar --set space.$workspace_id drawing=on label="$icon_strip" label.drawing=on

		if ! [ "$FOCUSED_WORKSPACE" = "$workspace_id" ]; then
			sketchybar --set space.$workspace_id background.drawing=on
		else
			sketchybar --set space.$workspace_id background.drawing=off
		fi

	else
		# No apps in workspace, hide label (and the whole item too, unless
		# it's the focused workspace or HIDE_EMPTY_SPACES is off)
		icon_strip=" -"
		if [ "$hide_empty" = "true" ] && [ "$FOCUSED_WORKSPACE" != "$workspace_id" ]; then
			sketchybar --set space.$workspace_id drawing=off
		else
			sketchybar --set space.$workspace_id drawing=on label.drawing=off background.drawing=off
		fi
	fi
}

update_workspace_windows "$1" "$2"
