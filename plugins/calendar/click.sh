#!/bin/bash

# For 5s, show more precise time
for ((i = 0; i <= 5; ++i)); do
  sketchybar --set $NAME icon="$(LC_TIME=ja_JP.UTF-8 date '+%-m月%-d日(%a)')" label="$(date '+%H:%M:%S')" \
    label.width=65
  sleep 1
done

sketchybar --set $NAME icon="$(LC_TIME=ja_JP.UTF-8 date '+%-m月%-d日(%a)')" label="$(date '+%H:%M')" \
  label.width=50
