#!/bin/bash

## Scripts
# Keep the existing item id so the More-menu layout remains unchanged.
SCRIPT_CLAUDE="export PATH=$PATH; $RELPATH/plugins/packages/script.sh"

## Mascot image (native asset is 128x128, scaled down to fit the bar height)
CLAUDE_MASCOT_MARGIN=6
CLAUDE_MASCOT_SIZE=$(($BAR_HEIGHT - $CLAUDE_MASCOT_MARGIN * 2))
CLAUDE_MASCOT_SCALE=$(bc <<<"scale=4; $CLAUDE_MASCOT_SIZE / 128")

## Item properties
claude=(
  drawing=off
  script="$SCRIPT_CLAUDE"
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
