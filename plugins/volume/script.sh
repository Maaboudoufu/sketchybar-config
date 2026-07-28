#!/bin/bash
WIDTH=100
ICONS_VOLUME=(􀊣 􀊡 􀊥 􀊧 􀊩)
NOTCH_WIDTH=${1:-180}
BAR_HEIGHT=${2:-34}

# Same ARTWORK_MARGIN as sketchy-items/music.sh's music_artwork — duplicated
# rather than threaded through, since volume.sh is sourced before music.sh so
# music.sh's own computed value doesn't exist yet at that point. Keep these
# two in sync if the artwork margin ever changes.
ARTWORK_MARGIN=5
ARTWORK_HEIGHT=$((BAR_HEIGHT - ARTWORK_MARGIN * 2))

# How much to pull the slide-in short of the full notch width, and how much
# to shrink the artwork by while tucked in — the physical notch cutout isn't
# exactly NOTCH_WIDTH/BAR_HEIGHT, so sliding/sizing to those exact figures can
# still leave a sliver of artwork visible past the real notch's edges.
NOTCH_RIGHT_NUDGE=12
NOTCH_HEIGHT_SHRINK=20

# Same font sizes as sketchy-items/music.sh's music_title/music_subtitle,
# duplicated for the same sourcing-order reason as ARTWORK_MARGIN above.
# Static, so — unlike background.image.scale — no need to read the current
# value live or stash it anywhere for restore; the original is just these
# constants.
TITLE_FONT_SIZE=10.0
TITLE_FONT_SHRUNK=5.0
SUBTITLE_FONT_SIZE=9.0
SUBTITLE_FONT_SHRUNK=4.0

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
  # to e / right-of-notch (see script-position.sh) — instead of hiding it
  # outright, slide it one notch-width to the left so it animates away
  # tucked behind the physical notch, then slide it back once the slider
  # settles back to collapsed. Only music's own padding_left needs to move:
  # title/subtitle are positioned relative to it in the bracket and slide
  # along automatically. subtitle's padding_right absorbs the same shift in
  # the opposite direction so whatever comes after it in the bracket (e.g.
  # the cpu graph) doesn't get dragged along too.
  #
  # A marker file (not a local variable) tracks who needs restoring:
  # overlapping volume_change invocations race on the same $NAME
  # slider.percentage check below, so the invocation that slides music away
  # isn't necessarily the one whose FINAL_PERCENTAGE check later fires the
  # restore — a local flag would leave it stuck slid away in that case.
  # background.height only resizes the (transparent-fill, border-only) frame
  # — the actual visible cover art is drawn via background.image at its own
  # independent background.image.scale, which background.height does NOT
  # affect. The real shrink has to scale the image itself, proportionally to
  # the same height reduction. Its current scale varies per track (computed
  # by script-artwork.sh from that track's actual image pixel size), so it's
  # read live and stashed in the marker file's contents — not just touched —
  # so whichever invocation ends up restoring knows the right value to go
  # back to.
  #
  # The marker's existence is also the gate for whether to shrink at all, not
  # just position/drawing: without it, a second overlapping invocation would
  # read "current scale" AFTER the first has already shrunk it, store that
  # already-shrunk value as if it were the original, and corrupt what
  # restore later sets it back to. Created via noclobber so two invocations
  # checking "does it exist" in the same instant can't both win — only one
  # `>` succeeds, the other fails and skips the block entirely.
  MUSIC_SLID_MARKER="${TMPDIR}sketchybar/music_slid_by_volume"
  if [ "$(sketchybar --query music | jq -r .geometry.position)" = "e" ] &&
    [ "$(sketchybar --query music | jq -r .geometry.drawing)" = "on" ] &&
    (set -o noclobber; : >"$MUSIC_SLID_MARKER") 2>/dev/null; then
    CURRENT_SCALE=$(sketchybar --query music | jq -r '.geometry.background.image.scale')
    SET_SCALE=()
    if [ "$CURRENT_SCALE" != "null" ] && [ -n "$CURRENT_SCALE" ]; then
      echo "$CURRENT_SCALE" >"$MUSIC_SLID_MARKER"
      SHRUNK_SCALE=$(bc <<<"scale=6; $CURRENT_SCALE * ($ARTWORK_HEIGHT - $NOTCH_HEIGHT_SHRINK) / $ARTWORK_HEIGHT")
      SET_SCALE=(background.image.scale=$SHRUNK_SCALE)
    else
      touch "$MUSIC_SLID_MARKER"
    fi
    sketchybar --animate tanh 20 \
      --set music padding_left=$((NOTCH_RIGHT_NUDGE - NOTCH_WIDTH)) background.height=$((ARTWORK_HEIGHT - NOTCH_HEIGHT_SHRINK)) "${SET_SCALE[@]}" \
      --set music.title label.font.size=$TITLE_FONT_SHRUNK \
      --set music.subtitle padding_right=$((NOTCH_WIDTH - NOTCH_RIGHT_NUDGE)) label.font.size=$SUBTITLE_FONT_SHRUNK
  fi

  sleep 2

  ### Check wether the volume was changed another time while sleeping

  FINAL_PERCENTAGE=$(sketchybar --query $NAME | jq -r ".slider.percentage")
  if [ "$FINAL_PERCENTAGE" -eq "$INFO" ]; then
    sketchybar --animate tanh 30 --set $NAME slider.width=0
    if [ -f "$MUSIC_SLID_MARKER" ]; then
      ORIGINAL_SCALE=$(cat "$MUSIC_SLID_MARKER")
      rm -f "$MUSIC_SLID_MARKER"
      RESTORE_SCALE=()
      [ -n "$ORIGINAL_SCALE" ] && RESTORE_SCALE=(background.image.scale=$ORIGINAL_SCALE)
      sketchybar --animate tanh 20 \
        --set music padding_left=0 background.height=$ARTWORK_HEIGHT "${RESTORE_SCALE[@]}" \
        --set music.title label.font.size=$TITLE_FONT_SIZE \
        --set music.subtitle padding_right=0 label.font.size=$SUBTITLE_FONT_SIZE
    fi
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
