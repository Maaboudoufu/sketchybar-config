#!/bin/bash

## Scripts
SCRIPT_CALENDAR="export PATH=$PATH; $RELPATH/plugins/calendar/script.sh"

# Seconds are always shown, so the clock ticks every second and the label is
# sized for HH:MM:SS. Clicking used to reveal seconds for five seconds at a
# time; there is nothing left for it to reveal.
calendar=(
  icon="$(LC_TIME=ja_JP.UTF-8 date '+%-m月%-d日(%a)')"
  label="$(date '+%H:%M:%S')"
  icon.font="$FONT:Black:12.0"
  icon.padding_right=0
  label.width=65
  label.align=center
  label.padding_right=0
  update_freq=1
  script="$SCRIPT_CALENDAR"
)

sketchybar --add item calendar right \
  --set calendar "${calendar[@]}"

add_separator "0" "right"

sendLog "Added calendar (date) item" "vomit"