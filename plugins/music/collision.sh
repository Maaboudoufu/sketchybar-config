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
# request it animates the shrink; only the last one to release it animates
# it back. A consumer whose request was a no-op (music wasn't at e/on at the
# time) never gets a marker file, so releasing it later is always safe.
#
# "First" and "last" are each decided with one atomic filesystem call, not a
# read-then-act check — every consumer is a genuinely separate OS process
# with nothing else synchronizing them:
#   - "am I first to shrink" = did my `>file` win a noclobber race against
#     MUSIC_SHRINK_MARKER (the kernel lets exactly one racing O_EXCL write
#     succeed).
#   - "am I last to release" = did my `rmdir` on MUSIC_SHRINK_DIR succeed
#     (rmdir only succeeds against a directory that is genuinely empty at
#     that instant, and only one of several concurrent rmdir calls against
#     the same directory can win). MUSIC_SHRINK_MARKER has to live next to,
#     not inside, that directory for this — it needs to be able to go fully
#     empty (just consumer marker files) for rmdir's atomicity to mean
#     anything. An `ls`-then-decide check isn't atomic: two releases racing
#     to be "last", or a release and a fresh request racing across the
#     "am I last" instant, could land on the wrong side of it.

MUSIC_SHRINK_DIR="${TMPDIR}sketchybar/music_shrink"
# Pure atomic "am I the first consumer to shrink" gate (see music_shrink_for_notch)
# -- no longer doubles as scale storage, see the comment there.
MUSIC_SHRINK_MARKER="${MUSIC_SHRINK_DIR}.first"

# $1 consumer name (unique per caller); callers also still pass NOTCH_WIDTH
# and BAR_HEIGHT for compatibility, unused now that hiding no longer needs
# either to compute a shrink target
music_shrink_for_notch() {
  local consumer="$1"

  local position drawing
  read -r position drawing < <(sketchybar --query music | jq -r '"\(.geometry.position) \(.geometry.drawing)"')
  [ "$position" = "e" ] && [ "$drawing" = "on" ] || return 0

  mkdir -p "$MUSIC_SHRINK_DIR"
  : >"$MUSIC_SHRINK_DIR/$consumer"

  # Only the first active consumer actually hides it — noclobber races
  # concurrent first-callers safely down to exactly one winner (mirrors the
  # create-then-check race the single-consumer version used to run against
  # $MUSIC_SLID_MARKER).
  (set -o noclobber; : >"$MUSIC_SHRINK_MARKER") 2>/dev/null || return 0

  # This used to shrink background.height/label.width/font.size toward zero
  # instead of touching drawing directly (animatable, unlike a boolean, so it
  # could shrink smoothly). Confirmed broken: background.image renders at
  # native_size * scale regardless of background.height, so the artwork
  # stayed fully visible at full size the whole time -- caught a screenshot
  # showing the full-size icon while a simultaneous query reported
  # background.height=0. drawing=off is the only property that unambiguously
  # removes an item from the render, so that's what actually hides it. No
  # animation, but correct beats smooth.
  sketchybar --set music drawing=off \
    --set music.title drawing=off \
    --set music.subtitle drawing=off
}

# $1 consumer name; callers also still pass BAR_HEIGHT for compatibility, unused now
music_release_for_notch() {
  local consumer="$1"

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

  rm -f "$MUSIC_SHRINK_MARKER"

  sketchybar --set music drawing=on \
    --set music.title drawing=on \
    --set music.subtitle drawing=on
}
