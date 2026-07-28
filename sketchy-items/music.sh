#!/bin/bash

## Scripts & defaults
ARTWORK_MARGIN=5
ARTWORK_HEIGHT=$(($BAR_HEIGHT - $ARTWORK_MARGIN * 2))
TITLE_MARGIN=$((3 + $BAR_HEIGHT / 4))
# Allow override from global config via MUSIC_INFO_WIDTH
INFO_WIDTH=${MUSIC_INFO_WIDTH:-80}

SCRIPT_MUSIC="export PATH=$PATH; $RELPATH/plugins/music/script-artwork.sh $ARTWORK_MARGIN $BAR_HEIGHT"
SCRIPT_CLICK_MUSIC_ARTWORK="export PATH=$PATH; media-control toggle-play-pause"
SCRIPT_MUSIC_TITLE="export PATH=$PATH; $RELPATH/plugins/music/script-title.sh"
SCRIPT_CLICK_MUSIC_TITLE="export PATH=$PATH; $menubarImportCmd -s \"Control Center,NowPlaying\""
SCRIPT_CENTER_SEP="export PATH=$PATH; $RELPATH/plugins/music/script-separator.sh"

## Item properties
# position=q on all three: matches the padding_left defaults below, which are
# only correct for q. On a reload, --set re-applies these to the (already
# existing) items, but --add is a no-op on existing items so `position` isn't
# reset alongside them — without pinning it back to q here too, an item left
# at e from before the reload would end up with e's position but q's padding,
# dragging title/subtitle 80px left onto the artwork. See script-position.sh's
# forced re-run below, which corrects back to e when warranted.
music_artwork=(
	position=q
	drawing=off
	script="$SCRIPT_MUSIC"
	click_script="$SCRIPT_CLICK_MUSIC_ARTWORK"
	icon="􀊆"
	icon.drawing=off
	icon.color=$HIGH_MED
	icon.shadow.drawing=on
	icon.shadow.color=$BAR_COLOR
	icon.shadow.distance=3
	icon.align=center
	label.drawing=off
	icon.padding_right=0
	icon.padding_left=-3
	background.drawing=on
	background.height=$ARTWORK_HEIGHT
	background.image.border_color=$MUTED
	background.image.border_width=1
	background.image.corner_radius=4
	background.image.padding_right=1
	update_freq=0
	padding_left=0
	padding_right=8
)

music_title=(
	position=q
	label=Title
	drawing=off
	script="$SCRIPT_MUSIC_TITLE"
	click_script="$SCRIPT_CLICK_MUSIC_TITLE"
	label.color=$TEXT
	icon.drawing=off
	label.align=right
	label.width=$INFO_WIDTH
	label.max_chars=13
	label.font="$FONT:Semibold:10.0"
	scroll_texts=on
	padding_left=-$INFO_WIDTH
	padding_right=0
	y_offset=$(($BAR_HEIGHT / 2 - $TITLE_MARGIN))
)

music_subtitle=(
	position=q
	label=SubTitle
	drawing=off
	script="$SCRIPT_MUSIC_TITLE"
	click_script="$SCRIPT_CLICK_MUSIC_TITLE"
	label.color=$SUBTLE
	icon.drawing=off
	label.align=right
	label.width=$INFO_WIDTH
	label.max_chars=14
	label.font="$FONT:Semibold:9.0"
	scroll_texts=on
	padding_left=-$INFO_WIDTH
	padding_right=0
	y_offset=$((-($BAR_HEIGHT / 2) + $TITLE_MARGIN))
)

center_separator=(
	icon="|"
	script="$SCRIPT_CENTER_SEP"
	icon.color=$SUBTLE
	icon.font="$FONT:Bold:16.0"
	icon.y_offset=2
	label.drawing=off
	icon.padding_left=0
	icon.padding_right=0
	update_freq=0
	updates=on
)

## Item addition
sketchybar \
	--add event activities_update \
	--add item separator_center center \
	--set separator_center "${center_separator[@]}" \
	--subscribe separator_center activities_update \
	--add item music q \
	--set music "${music_artwork[@]}" \
	--add item music.title q \
	--set music.title "${music_title[@]}" \
	--add item music.subtitle q \
	--set music.subtitle "${music_subtitle[@]}"

sendLog "Added media player (TITLE_MARGIN=$TITLE_MARGIN)" "vomit"

# Reposition music to the right of the notch once the (aerospace-only)
# workspace list grows past MUSIC_SWAP_THRESHOLD — see script-position.sh.
# A dedicated invisible item, not `music` itself: `music`'s script is a
# long-running media-control stream that gets killed and restarted on every
# event it's subscribed to, so piling a workspace-change subscription onto it
# would restart that stream on every workspace change.
if [ "$WINDOW_MANAGER" = "aerospace" ]; then
	SCRIPT_MUSIC_POSITION="export PATH=$PATH; $RELPATH/plugins/music/script-position.sh $MUSIC_SWAP_THRESHOLD $HIDE_EMPTY_SPACES $INFO_WIDTH $ARTWORK_HEIGHT"
	sketchybar --add item music_position_watcher center \
		--set music_position_watcher drawing=off updates=on script="$SCRIPT_MUSIC_POSITION" \
		--subscribe music_position_watcher aerospace_workspace_change

	# Run once now against the position=q baseline just set above, rather than
	# waiting for the next aerospace_workspace_change event: on a reload that
	# happens while already past MUSIC_SWAP_THRESHOLD, that event may not fire
	# again for a while, leaving music stuck at q (colliding with the space
	# list) until it does.
	$RELPATH/plugins/music/script-position.sh "$MUSIC_SWAP_THRESHOLD" "$HIDE_EMPTY_SPACES" "$INFO_WIDTH" "$ARTWORK_HEIGHT"
fi
