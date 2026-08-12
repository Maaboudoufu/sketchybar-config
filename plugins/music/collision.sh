#!/bin/bash
# Shared by every plugin that needs to temporarily shrink the music widget
# out of its own way while it's swapped to e (right of the notch, see
# script-position.sh) and something else wants that same stretch of bar —
# the volume slider, the more-menu popout, the alt-click CPU graph. Originally
# lived only in plugins/volume/script.sh; more-menu and the CPU graph hit the
# exact same collision (both reveal right-of-notch items on top of music)
# without it, so it moved here instead of being copy-pasted a second and
# third time.
#
# Multiple consumers can be open at once (e.g. the more-menu popped open
# while the volume slider is still settling), so shrink state is refcounted
# by consumer name rather than a single on/off marker: the first consumer to
# request it stashes the original artwork scale; only the last one to
# release it restores that scale. A consumer whose request was a no-op
# (music wasn't at e/on at the time) never gets a marker file, so releasing
# it later is always safe.
#
# "First" and "last" are each decided with one atomic filesystem call, not a
# read-then-act check — every consumer is a genuinely separate OS process
# with nothing else synchronizing them:
#   - "am I first to shrink" = did my `>file` win a noclobber race against
#     MUSIC_SHRINK_SCALE_FILE (the kernel lets exactly one racing O_EXCL
#     write succeed).
#   - "am I last to release" = did my `rmdir` on MUSIC_SHRINK_DIR succeed
#     (rmdir only succeeds against a directory that is genuinely empty at
#     that instant, and only one of several concurrent rmdir calls against
#     the same directory can win). MUSIC_SHRINK_SCALE_FILE has to live next
#     to, not inside, that directory for this — it needs to be able to go
#     fully empty (just consumer marker files) for rmdir's atomicity to mean
#     anything. An `ls`-then-decide check isn't atomic: two releases racing
#     to be "last", or a release and a fresh request racing across the
#     "am I last" instant, could land on the wrong side of it.

MUSIC_SHRINK_DIR="${TMPDIR}sketchybar/music_shrink"
MUSIC_SHRINK_SCALE_FILE="${MUSIC_SHRINK_DIR}.scale"

ARTWORK_MARGIN=5
NOTCH_RIGHT_NUDGE=12
NOTCH_HEIGHT_SHRINK=20
TITLE_FONT_SIZE=10.0
TITLE_FONT_SHRUNK=5.0
SUBTITLE_FONT_SIZE=9.0
SUBTITLE_FONT_SHRUNK=4.0

# $1 consumer name (unique per caller)  $2 NOTCH_WIDTH  $3 BAR_HEIGHT
music_shrink_for_notch() {
  local consumer="$1" notch_width="${2:-180}" bar_height="${3:-34}"
  local artwork_height=$((bar_height - ARTWORK_MARGIN * 2))

  # One query, not two: this used to check position/drawing here and read
  # the scale separately below, each its own sketchybar-daemon round trip.
  # The gate is only reachable at all while an animation is racing to start,
  # so that second round trip was pure latency sitting directly on the path
  # to the first visible frame of the shrink.
  local position drawing current_scale
  read -r position drawing current_scale < <(sketchybar --query music | jq -r '"\(.geometry.position) \(.geometry.drawing) \(.geometry.background.image.scale)"')
  [ "$position" = "e" ] && [ "$drawing" = "on" ] || return 0

  mkdir -p "$MUSIC_SHRINK_DIR"
  : >"$MUSIC_SHRINK_DIR/$consumer"

  # Only the first active consumer actually animates the shrink and stashes
  # the pre-shrink scale — noclobber races concurrent first-callers safely
  # down to exactly one winner (mirrors the create-then-check race the
  # single-consumer version used to run against $MUSIC_SLID_MARKER).
  (set -o noclobber; : >"$MUSIC_SHRINK_SCALE_FILE") 2>/dev/null || return 0

  local set_scale=()
  if [ "$current_scale" != "null" ] && [ -n "$current_scale" ]; then
    echo "$current_scale" >"$MUSIC_SHRINK_SCALE_FILE"
    local shrunk_scale
    shrunk_scale=$(bc <<<"scale=6; $current_scale * ($artwork_height - $NOTCH_HEIGHT_SHRINK) / $artwork_height")
    set_scale=(background.image.scale=$shrunk_scale)
  fi

  sketchybar --animate tanh 15 \
    --set music padding_left=$((NOTCH_RIGHT_NUDGE - notch_width)) background.height=$((artwork_height - NOTCH_HEIGHT_SHRINK)) "${set_scale[@]}" \
    --set music.title label.font.size=$TITLE_FONT_SHRUNK \
    --set music.subtitle padding_right=$((notch_width - NOTCH_RIGHT_NUDGE)) label.font.size=$SUBTITLE_FONT_SHRUNK
}

# $1 consumer name  $2 BAR_HEIGHT
music_release_for_notch() {
  local consumer="$1" bar_height="${2:-34}"
  local artwork_height=$((bar_height - ARTWORK_MARGIN * 2))

  # No marker means this consumer never actually shrunk anything — a no-op
  # request() (music wasn't at e/on) or a request() that lost the noclobber
  # race is fine to release; both leave no file here to remove.
  [ -f "$MUSIC_SHRINK_DIR/$consumer" ] || return 0
  rm -f "$MUSIC_SHRINK_DIR/$consumer"

  # Other consumers still want it shrunk — leave it alone. rmdir only
  # succeeds for whichever caller's own marker removal left the directory
  # genuinely empty, so unlike a separate emptiness read, two concurrent
  # releases (or a release racing a fresh request) can't both/either win.
  rmdir "$MUSIC_SHRINK_DIR" 2>/dev/null || return 0

  local restore_scale=()
  if [ -f "$MUSIC_SHRINK_SCALE_FILE" ]; then
    local original_scale
    original_scale=$(cat "$MUSIC_SHRINK_SCALE_FILE")
    rm -f "$MUSIC_SHRINK_SCALE_FILE"
    [ -n "$original_scale" ] && restore_scale=(background.image.scale=$original_scale)
  fi

  sketchybar --animate tanh 15 \
    --set music padding_left=0 background.height=$artwork_height "${restore_scale[@]}" \
    --set music.title label.font.size=$TITLE_FONT_SIZE \
    --set music.subtitle padding_right=0 label.font.size=$SUBTITLE_FONT_SIZE
}
