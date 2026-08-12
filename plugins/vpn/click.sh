#!/bin/bash

##
# Click handling for one VPN item.
#
# Bare: rebuild the popup from live state and show it. This is a sketchybar
# popup carrying the same actions the app's own menu bar item offers, driven
# through `scutil --nc` — deliberately not the real menu bar, which is why the
# rows are built here rather than clicked through with `menubar`. Row labels
# follow each vendor's own Japanese localisation, the same source as the icons.
#
# With an action: a popup row was clicked. Do it, close the popup, then watch
# the tunnel until it settles so the icon does not sit stale.
##

# scutil lives in /usr/sbin, which is not on the PATH sketchybar hands to
# scripts spawned from a popup row.
export PATH="/usr/sbin:/usr/bin:/bin:$PATH"

RELPATH="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
source "$RELPATH/set_colors.sh"
source "$RELPATH/plugins/vpn/lib.sh"

PROVIDER=${1:?}
ACTION=$2
TARGET=$3
ITEM="vpn.$PROVIDER"
SELF="$RELPATH/plugins/vpn/click.sh"
FONT="${FONT:-SF Pro}" # popup rows are built here, outside sketchybarrc's scope

# The same haptic the more-menu and the space items give on hover. Resolved to
# an absolute path here because the row script below is an inline string run by
# sketchybar, where the alias those scripts rely on has nothing to expand it.
HAPTIC="$(command -v ft-haptic 2>/dev/null || echo "$RELPATH/ft-haptic")"

# sketchybar has no built-in hover state, so the highlight is drawn by hand off
# mouse.entered/exited. Inline rather than a helper script: it is one --set and a
# row fires this every time the pointer crosses it. The highlight goes first so
# the tap never sits between the pointer arriving and the row lighting up.
ROW_HOVER='if [ "$SENDER" = mouse.entered ]; then sketchybar --set $NAME background.drawing=on; '"$HAPTIC"' -n 1 2>/dev/null; else sketchybar --set $NAME background.drawing=off; fi'

# The theme's highlight tint carries the bar's transparency factor, which is set
# for chips drawn straight onto the wallpaper. A popup is already glass, so the
# two alphas compound and HIGH_HIGH lands ~6/255 off the popup's own background —
# invisible. Keep the theme's hue, take an alpha that actually reads on top of it.
ROW_HIGHLIGHT="0x99${HIGH_HIGH: -6}"

case "$ACTION" in
start | stop)
	scutil --nc "$ACTION" "$TARGET"
	sketchybar --set "$ITEM" popup.drawing=off
	# scutil returns as soon as the request is filed, so poll the handshake out
	# rather than leaving the wrong glyph up until the next scheduled refresh.
	#
	# Wait for the state this action was asking for, not for any settled state:
	# the extension can still be reporting the state we started from 0.4s in, and
	# "either terminal state" counted that as done and stopped watching.
	[ "$ACTION" = start ] && WANT=Connected || WANT=Disconnected
	for _ in $(seq 12); do
		sleep 0.4
		STATE="$(vpn_state "$PROVIDER")"
		sketchybar --trigger vpn_update
		[[ $STATE == "$WANT" ]] && break
	done
	exit 0
	;;
open)
	sketchybar --set "$ITEM" popup.drawing=off
	vpn_show_app "$PROVIDER"
	exit 0
	;;
esac

## Popup construction

# Already open? This click is the one that dismisses it, so close and stop —
# rebuilding rows we are about to hide costs two scutil calls for nothing.
if [ "$(sketchybar --query "$ITEM" | jq -r '.popup.drawing')" = on ]; then
	sketchybar --set "$ITEM" popup.drawing=off
	exit 0
fi

ARGS=()
ROW=0

add_row() { # $1 = icon glyph, $2 = label, $3.. = action args (none = inert row)
	local id="$ITEM.row.$ROW" cmd arg
	ARGS+=(
		--add item "$id" "popup.$ITEM"
		--set "$id"
		icon="$1"
		icon.color=$TEXT
		icon.width=22
		icon.padding_left=10
		icon.padding_right=0
		label="$2"
		label.font="$FONT:Regular:12.0"
		label.color=$TEXT
		label.padding_left=12
		label.padding_right=18
		background.drawing=off
	)
	if (($# > 2)); then
		# Tunnel names carry spaces ("NordVPN NordLynx"), so quote them for the
		# shell sketchybar runs click_script under. Single quotes rather than
		# printf %q: the backslashes %q emits end up unescaped in `sketchybar
		# --query` output, which stops it being parseable JSON.
		cmd="$SELF $PROVIDER"
		for arg in "${@:3}"; do cmd+=" '${arg//\'/\'\\\'\'}'"; done
		# Only actionable rows take the hover highlight — that is what keeps the
		# status headings below reading as captions rather than dead buttons.
		ARGS+=(
			click_script="$cmd"
			script="$ROW_HOVER"
			background.color=$ROW_HIGHLIGHT
			background.corner_radius=6
			background.height=22
			# Last, and it has to be: setting any background.* above turns
			# drawing back on, so an earlier =off leaves every row pre-lit.
			background.drawing=off
			--subscribe "$id" mouse.entered mouse.exited
		)
	else
		# Status headings mirror the native menus, which show state as a caption
		# rather than something you can click.
		ARGS+=(icon.color=$SUBTLE label.color=$SUBTLE)
	fi
	ROW=$((ROW + 1))
}

# Rows are rebuilt on every open: tunnels come and go in the apps' own UI, and
# the state they display is only true at the moment of the click.
#
# The one bar query does double duty — it also finds the other provider, whose
# popup gets closed here so the two can never sit open over each other. Its rows
# are left alone; it rebuilds them the next time it opens.
while read -r item; do
	case $item in
	"$ITEM.row."*) ARGS+=(--remove "$item") ;;
	*.row.*) ;;
	"$ITEM") ;;
	*) ARGS+=(--set "$item" popup.drawing=off) ;;
	esac
done < <(sketchybar --query bar | jq -r '.items[] | select(startswith("vpn."))')

case $PROVIDER in
wireguard)
	# One row per configured tunnel, ticked while it is up — WireGuard's own menu
	# is this same list.
	while IFS='|' read -r state tunnel; do
		[ -n "$tunnel" ] || continue
		case $state in
		Connected | Connecting) add_row "􀆅" "$tunnel" stop "$tunnel" ;;
		*) add_row " " "$tunnel" start "$tunnel" ;;
		esac
	done < <(vpn_tunnels "$PROVIDER")
	add_row "􀍟" "トンネルの管理" open
	;;
nordvpn)
	# NordVPN leads with whether you are covered and offers one connect or
	# disconnect action; picking countries stays in the app.
	TUNNEL="$(vpn_tunnels "$PROVIDER" | head -1 | cut -d'|' -f2)"
	case "$(vpn_state "$PROVIDER")" in
	Connected | Connecting)
		add_row "􀎡" "保護済み"
		[ -n "$TUNNEL" ] && add_row "􀁑" "接続解除" stop "$TUNNEL"
		;;
	*)
		add_row "􀎢" "保護されていません"
		[ -n "$TUNNEL" ] && add_row "􀋥" "クイック接続" start "$TUNNEL"
		;;
	esac
	add_row "􀄯" "NordVPNを開く" open
	;;
esac

sketchybar "${ARGS[@]}" --set "$ITEM" popup.drawing=on

# Rows size to their own text, so the hover highlight would stop at a different
# x on each one. Square them off against the widest.
#
# Measured after the popup is up because a hidden row reports no bounding rect.
# Nothing moves as a result: the popup is already as wide as its widest row, the
# labels are left-aligned, and a row's background only draws while hovered.
WIDEST=0
for ((i = 0; i < ROW; i++)); do
	W=$(sketchybar --query "$ITEM.row.$i" | jq -r '.bounding_rects["display-1"].size[0] // 0')
	W=${W%.*}
	((W > WIDEST)) && WIDEST=$W
done

if ((WIDEST > 0)); then
	WIDTHS=()
	for ((i = 0; i < ROW; i++)); do WIDTHS+=(--set "$ITEM.row.$i" width="$WIDEST"); done
	sketchybar "${WIDTHS[@]}"
fi
