#!/bin/bash

## Scripts
SCRIPT_FRONT_APP="export PATH=$PATH; $RELPATH/plugins/frontapp/script.sh"
# The plugin, not an inline `yabai -m window --toggle float`: it is the same
# command behind a `command -v yabai` guard, so on an aerospace/rift setup the
# click logs instead of failing silently. The file existed but nothing used it.
SCRIPT_CLICK_FRONT_APP="export PATH=$PATH; $RELPATH/plugins/frontapp/click.sh"

## Item properties
front_app=(
  background.color=$OVERLAY
  background.height=$(($BAR_HEIGHT - 12))
  background.corner_radius=7
  background.border_width=1
  background.border_color=$BORDER_COLOR
  icon=􀢌
  icon.font="sketchybar-app-font:Regular:15.0"
  icon.color=$SELECT
  script="$SCRIPT_FRONT_APP"
  click_script="$SCRIPT_CLICK_FRONT_APP"
  padding_left=5
  label.color=$TEXT
  label.font="$FONT:Black:12.0"
  associated_display=active
)

## Item addition
sketchybar --add item front_app left \
  --set front_app "${front_app[@]}" \
  --subscribe front_app system_woke front_app_switched

sendLog "Added front app item" "vomit"
