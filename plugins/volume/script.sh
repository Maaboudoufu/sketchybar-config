#!/bin/bash
WIDTH=100
ICONS_VOLUME=(􀊣 􀊡 􀊥 􀊧 􀊩)
NOTCH_WIDTH=${1:-180}
BAR_HEIGHT=${2:-34}

source "$(dirname "$0")/../music/collision.sh"

volume_change() {
  
  ### Set icon + color depending on volume percentage

  case $INFO in
  [6-9][0-9] | 100)
    ICON=${ICONS_VOLUME[4]}
    ;;
  [3-5][0-9])
    ICON=${ICONS_VOLUME[3]}
    ;;
  [1-2][0-9])
    ICON=${ICONS_VOLUME[2]}
    ;;
  [1-9])
    ICON=${ICONS_VOLUME[1]}
    ;;
  0)
    ICON=${ICONS_VOLUME[0]}
    ;;
  *) ICON=${ICONS_VOLUME[4]} ;;
  esac

  sketchybar --set volume_icon icon=$ICON

  sketchybar --set $NAME slider.percentage=$INFO \
    --animate tanh 30 --set $NAME slider.width=$WIDTH

  # Music shares this side of the bar with the slider once it's been swapped
  # to e / right-of-notch (see script-position.sh) — collision.sh slides it
  # away tucked behind the physical notch for as long as this (or any other)
  # consumer needs the space, then back once everyone's released it.
  music_shrink_for_notch volume "$NOTCH_WIDTH" "$BAR_HEIGHT"

  sleep 2

  ### Check wether the volume was changed another time while sleeping

  FINAL_PERCENTAGE=$(sketchybar --query $NAME | jq -r ".slider.percentage")
  if [ "$FINAL_PERCENTAGE" -eq "$INFO" ]; then
    sketchybar --animate tanh 30 --set $NAME slider.width=0
    music_release_for_notch volume "$BAR_HEIGHT"
  fi
}

mouse_clicked() {
  osascript -e "set volume output volume $PERCENTAGE"
}

mouse_entered() {
  sketchybar --set $NAME slider.knob.drawing=on
}

mouse_exited() {
  sketchybar --set $NAME slider.knob.drawing=off
}

case "$SENDER" in
"volume_change")
  volume_change
  ;;
"mouse.clicked")
  mouse_clicked
  ;;
"mouse.entered")
  mouse_entered
  ;;
"mouse.exited")
  mouse_exited
  ;;
esac
