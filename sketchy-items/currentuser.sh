#!/bin/bash

## Scripts
# Keep the existing item id so the More-menu layout remains unchanged.
SCRIPT_CODEX="export PATH=$PATH; $RELPATH/plugins/currentuser/script.sh"

## Item properties
codex=(
	icon=":codex:"
	icon.color=$SELECT
	icon.font="sketchybar-app-font:Regular:15.0"
	icon.padding_right=2
	drawing=off
	script="$SCRIPT_CODEX"
	label="--"
	label.font="$FONT:Medium:12.0"
	padding_left=$(($INNER_PADDINGS - 2))
	padding_right=$(($INNER_PADDINGS / 2 - 1))
	label.color=$TEXT
	label.drawing=on
	label.padding_right=0
	label.padding_left=2
	update_freq=300
)

## Item addition
sketchybar --add item moremenu.user right \
	--set moremenu.user "${codex[@]}" \
	--subscribe moremenu.user more-menu-update

sendLog "Added Codex usage item" "vomit"
