#!/bin/bash
export RELPATH=$(dirname $0)/../..
source $RELPATH/set_colors.sh

ICONS_MICROPHONE=(􀊲 􀊰 􀊱) # Set mic icons

# One AppleScript round-trip per invocation. update_icon, update_label and
# toggle_mic each used to query the input volume themselves, so a single click
# paid four osascript spawns for a value that only changes when this script
# changes it. mute_mic/unmute_mic keep $VOLUME authoritative instead, so the
# icon refresh after a toggle needs no re-read.
VOLUME=$(osascript -e 'set ivol to input volume of (get volume settings)')

update_icon() {
  # Set icon + color depending on volume
  case $VOLUME in
  [6-9][0-9] | 100)
    ICON=${ICONS_MICROPHONE[2]}
    COLOR=$ACTIVE
    ;;
  [1-9] | [1-5][0-9])
    ICON=${ICONS_MICROPHONE[1]}
    COLOR=$WARN
    ;;
  *)
    ICON=${ICONS_MICROPHONE[0]}
    COLOR=$CRITICAL
    ;;
  esac

  sketchybar --animate tanh 30 --set $NAME icon=$ICON icon.color=$COLOR
}

update_label() {
  if [ "$VOLUME" != 0 ]; then
    # Store current volume in item's label
    mic=(
      label=$VOLUME
      label.drawing=off
    )
    sketchybar --set $NAME "${mic[@]}"
  fi
}

mute_mic() {
  osascript -e 'set volume input volume 0'
  VOLUME=0
}

unmute_mic() {
  # Restore from saved volume in label
  STORED_VOLUME=$(sketchybar --query $NAME | sed 's/\\n//g; s/\\\$//g; s/\\ //g' | jq -r '.label.value')
  # label resets to "" on sketchybar reload, losing the stored volume; fall back to 100
  VOLUME=${STORED_VOLUME:-100}
  osascript -e "set volume input volume $VOLUME"
}

toggle_mic() {
  if [ "$VOLUME" = 0 ]; then
    unmute_mic
  else
    update_label
    mute_mic
  fi
}

case "$SENDER" in
"mouse.clicked")
  toggle_mic
  update_icon
  ;;
*)
  update_label
  update_icon
  ;;
esac
