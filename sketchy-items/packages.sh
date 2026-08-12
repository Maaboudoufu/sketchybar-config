#!/bin/bash

## Mascot image (native asset is 128x128, scaled down to fit the bar height)
CLAUDE_MASCOT_MARGIN=6
CLAUDE_MASCOT_SIZE=$(($BAR_HEIGHT - $CLAUDE_MASCOT_MARGIN * 2))
CLAUDE_MASCOT_SCALE=$(bc <<<"scale=4; $CLAUDE_MASCOT_SIZE / 128")

## Scripts
# Keep the existing item id so the More-menu layout remains unchanged.
# The mascot geometry and font are passed in because the script has to redraw
# the icon itself when toggling back from the CPU/RAM view.
SCRIPT_CLAUDE="export PATH=$PATH; $RELPATH/plugins/packages/script.sh $CLAUDE_MASCOT_SIZE $CLAUDE_MASCOT_SCALE \"$FONT\""
SCRIPT_TOGGLE_USAGE="export PATH=$PATH; $RELPATH/plugins/usage/toggle.sh"

# Start every config load in AI-usage mode, matching the update_freq below.
rm -f "${TMPDIR}sketchybar/usage_mode"

## Item properties
claude=(
  drawing=off
  script="$SCRIPT_CLAUDE"
  click_script="$SCRIPT_TOGGLE_USAGE"
  icon=" "
  icon.drawing=on
  icon.width=$CLAUDE_MASCOT_SIZE
  icon.background.drawing=on
  icon.background.image="$RELPATH/assets/claude-code-mascot.png"
  icon.background.image.scale=$CLAUDE_MASCOT_SCALE
  icon.background.height=$CLAUDE_MASCOT_SIZE
  icon.background.corner_radius=4
  icon.background.x_offset=-2
  label="--"
  label.font="$FONT:Medium:12.0"
  label.padding_left=$(($INNER_PADDINGS - 2))
  label.padding_right=3
  padding_left=$(($INNER_PADDINGS - 2))
  padding_right=$(($OUTER_PADDINGS - 2))
  update_freq=300
  updates=when_shown
)

## Item addition
sketchybar --add item moremenu.pkgs right \
  --set moremenu.pkgs "${claude[@]}" \
  --subscribe moremenu.pkgs more-menu-update

sendLog "Added Claude usage item" "vomit"
