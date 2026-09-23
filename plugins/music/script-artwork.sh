#!/bin/bash
export PATH=/opt/homebrew/bin/:$PATH
export RELPATH=$(dirname $0)/../..
source $RELPATH/log_handler.sh

# sketchybar injects $NAME (the item's own name, "music") whenever it spawns
# an item's script; a manual restart for debugging -- not through sketchybar
# itself, e.g. running this file directly -- won't set it, and every
# `sketchybar --set $NAME...` call below would then silently target a
# literal ".title"/".subtitle" item that doesn't exist. That failure is
# invisible by default ($LOG_LEVEL=none swallows sendErr/sendWarn below), so
# the widget just stops updating with nothing pointing at why -- confirmed
# live: 20+ hours silently stuck on a stale track after exactly this kind of
# restart, discovered only because the displayed song stopped matching
# what was actually playing. Default it to the one item this script has ever
# actually been wired to, and warn on stderr directly (unconditional, not
# gated by $LOG_LEVEL) so a manual restart is still visibly abnormal, but
# the widget itself keeps working either way.
if [[ -z "$NAME" ]]; then
	echo "script-artwork.sh: \$NAME was unset (not started by sketchybar itself) -- defaulting to 'music'" >&2
	NAME=music
fi

### Kill any possible remaining streaming process from last config on reload
# script is made to be invoked only once per bar reload
#
# `pgrep sh` (the old check here) matches process names by prefix, and never
# matches "bash" -- it can't even see its OWN running instance, let alone a
# leftover one, so this never actually fired, though in practice this
# script's own defensive kill of prior instances on reload (below) is the
# only place a genuine duplicate could arise, and that path already works
# via the reload-time invocation itself. `pgrep -f` against the full command
# line finds every real instance (including this one, excluded via $$)
# regardless of process name, which `pgrep sh` fundamentally cannot.
pids=($(pgrep -f "$0" | grep -v "^$$\$"))

if [[ -n "$pids" ]]; then
	children=($(for p in "${pids[@]}"; do pgrep -P "$p"; done))
	# Belt and suspenders against the detached-stream case the file below
	# guards against: a leftover media-control process that already
	# reparented away from its script-artwork.sh instance won't show up as
	# a child of any pid above, but the last run recorded its own children
	# to this file before exiting, so it's still findable here.
	for i in $(cat ${TMPDIR}/sketchybar/pids 2>/dev/null); do
		children+=("$i")
	done
	sendWarn "Killing remaining media-control stream pids: ${pids[*]} ${children[*]}" "debug"
	kill -9 ${pids[@]} ${children[@]} 2>/dev/null
fi

ARTWORK_MARGIN="$1"
BAR_HEIGHT="$2"

### Open a stream to get current media continously

media-control stream | grep --line-buffered 'data' | while IFS= read -r line; do
	### List & store childs to prevent multiple background process remaining
	# Introduced because of a present bug, were the stream process detaches from the parent process causing stray processes

	if ps -p $$ >/dev/null; then
		pgrep -P $$ >${TMPDIR}/sketchybar/pids
	fi

	### Parse every field of this line in one jq call instead of nine separate
	### echo|jq forks (each field re-parsed $line fresh) — same values, 1 fork/line.
	IFS=$'\t' read -r payload_empty artworkData currentPID playing title artist album diff < <(
		jq -r '[(.payload=={}), (.payload.artworkData//"null"), (.payload.processIdentifier//"null"),
		        (.payload.playing//"null"), (.payload.title//"null"), (.payload.artist//"null"),
		        (.payload.album//"null"), (.diff//"null")] | @tsv' <<<"$line"
	)

	if ! {
		[[ $payload_empty == "true" ]] ||
			{ [[ -n $lastAppPID ]] && ! ps -p "$lastAppPID" >/dev/null; }
	}; then
		### Only trigger update for media info if process playing media still exists and current line feed isn't null

		### Set Artwork

		if [[ $artworkData != "null" ]]; then

			tmpfile=$(mktemp ${TMPDIR}sketchybar/cover.XXXXXXXXXX)

			### Dump raw artwork data into tmpfile

			echo $artworkData |
				base64 -d >$tmpfile

			### Assign corresponding extension depending on file type + convert if not supported

			case $(identify -ping -format '%m' $tmpfile) in
			"JPEG")
				ext=jpg
				mv $tmpfile $tmpfile.$ext
				;;
			"PNG")
				ext=png
				mv $tmpfile $tmpfile.$ext
				;;
			"TIFF")
				mv $tmpfile $tmpfile.tiff
				magick $tmpfile.tiff $tmpfile.jpg
				ext=jpg
				;;
			*)
				# Unrecognized/failed identify: no file was produced this
				# iteration, so nothing below should reference $tmpfile.$ext.
				ext=""
				;;
			esac

			if [[ -n $ext ]]; then
				sendLog "Artwork image generated at $tmpfile.$ext" "vomit"

				### Calculate width of media item to fit bar height nicely

				scale=$(bc <<<"scale=4;
        ( ($BAR_HEIGHT - $ARTWORK_MARGIN * 2) / $(identify -ping -format '%h' $tmpfile.$ext) )
      ")
				icon_width=$(bc <<<"scale=0;
        ( $(identify -ping -format '%w' $tmpfile.$ext) * $scale )
      ")

				### Set artwork to image, then purge image

				sketchybar --set $NAME background.image=$tmpfile.$ext \
					background.image.scale=$scale \
					icon.width=$(printf "%.0f" $icon_width)
			fi

			rm -f $tmpfile* && sendLog "Cleaned artwork image generated at $tmpfile.$ext" "vomit"
		fi

		### Set Title and artist + ?Album

		if [[ $title != "null" ]]; then

			title_label="$title"

			subtitle_label="$artist"
			if [[ -n "$album" ]]; then
				subtitle_label+=" • $album"
			fi

			sketchybar --set $NAME.title label="$title_label" \
				--set $NAME.subtitle label="$subtitle_label"
		fi

		### Set Playing state indicator

		if [[ $playing != "null" && $diff == "true" ]]; then
			case $playing in
			"true")
				sendLog "Updating playing state to play" "vomit"
				sketchybar --set $NAME icon.padding_left=-3 \
					--animate tanh 5 \
					--set $NAME icon="􀊆" \
					icon.drawing=on
				{
					sleep 5
					sketchybar --animate tanh 45 --set $NAME icon.drawing=false
				} &
				;;
			"false")
				sendLog "Updating playing state to pause" "vomit"
				sketchybar --set $NAME icon.padding_left=0 \
					--animate tanh 5 \
					--set $NAME icon="􀊄" \
					icon.drawing=on
				{
					sleep 5
					sketchybar --animate tanh 45 --set $NAME icon.drawing=false
				} &
				;;
			esac
		fi

		### Store app currently playing media to check for it's presence later

		if [[ $currentPID != "null" ]]; then
			lastAppPID=$currentPID
		fi

		sketchybar --set $NAME drawing=on \
			--set $NAME.title drawing=on \
			--set $NAME.subtitle drawing=on \
			--trigger activities_update

	else
		### If media stopped being played / app playing media is closed; hide music player

		sendLog "Media not playing $(if [[ -n $lastAppPID ]]; then echo "(media process: $lastAppPID)"; fi)" "debug"

		sketchybar --set $NAME drawing=off \
			--set $NAME.title drawing=off \
			--set $NAME.subtitle drawing=off \
			--trigger activities_update

		unset lastAppPID
	fi
done
