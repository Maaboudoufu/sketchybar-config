#!/bin/bash
export PATH=/opt/homebrew/bin:$PATH

# Move the music widget from q (left of notch) to e (right of notch) once
# more than THRESHOLD workspace icons are actually visible — past that point
# the growing space list starts to collide with music sitting right next to
# the notch. Visibility is recomputed from aerospace directly (mirroring
# script-windows.sh's own focused/has-windows/HIDE_EMPTY_SPACES criteria)
# rather than read back from sketchybar's per-item drawing state, since both
# this script and every space item react to the same aerospace_workspace_change
# event with no ordering guarantee between them — reading sketchybar's state
# here could see a space item's stale value from before its own handler runs.
THRESHOLD=${1:-5}
HIDE_EMPTY_SPACES=${2:-false}
INFO_WIDTH=${3:-80}
ARTWORK_HEIGHT=${4:-24}

FOCUSED=$(aerospace list-workspaces --focused 2>/dev/null)
visible=0
for ws in $(aerospace list-workspaces --all 2>/dev/null); do
	if [ "$ws" = "$FOCUSED" ] || [ "$HIDE_EMPTY_SPACES" != "true" ] || [ -n "$(aerospace list-windows --workspace "$ws" 2>/dev/null)" ]; then
		visible=$((visible + 1))
	fi
done

pos=q
[ "$visible" -gt "$THRESHOLD" ] && pos=e

current=$(sketchybar --query music | jq -r '.geometry.position')
[ "$current" = "$pos" ] && exit 0

# music.title/subtitle are pulled backward with negative padding_left so they
# sit flush against music's (the artwork icon's) edge instead of at their
# natural bar-order position — q and e grow in opposite directions from the
# notch, so which item needs the pull, and which way text aligns, flips too:
#
# q grows leftward (away from notch) in add order: music (added first) ends
# up closest to the notch; title/subtitle (added after) would naturally land
# further left of it, so both pull back by INFO_WIDTH to instead hug music's
# left edge, text right-aligned so it reads flush up to the icon.
#
# e grows rightward (away from notch) in add order: music already ends up
# closest to the notch with title naturally following right after it —
# no pull needed there. Only subtitle (added after title) needs to pull back
# by INFO_WIDTH, to stack under title instead of sitting beside it, text
# left-aligned so it reads outward from the icon.
if [ "$pos" = "q" ]; then
	title_padding_left=-$INFO_WIDTH
	subtitle_padding_left=-$INFO_WIDTH
	align=right
else
	title_padding_left=0
	subtitle_padding_left=-$INFO_WIDTH
	align=left
fi

# padding_left=0 / background.height=$ARTWORK_HEIGHT / padding_right=0 /
# label.font.size below reset any in-progress "slide toward the notch" from
# plugins/volume/script.sh (volume changes temporarily shift these while
# music is at e) — a real q<->e transition mid-slide would otherwise leave
# music stuck slid away, shrunk and tiny-fonted, since that script only knows
# how to undo its own shift, not react to a position change underneath it.
# Font sizes match music.sh's music_title/music_subtitle definitions.
sketchybar --animate tanh 20 \
	--set music position=$pos padding_left=0 background.height=$ARTWORK_HEIGHT \
	--set music.title position=$pos padding_left=$title_padding_left label.align=$align label.font.size=10.0 \
	--set music.subtitle position=$pos padding_left=$subtitle_padding_left label.align=$align padding_right=0 label.font.size=9.0
