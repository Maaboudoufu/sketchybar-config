#!/bin/bash

## Scripts
SCRIPT_VPN="export PATH=$PATH; $RELPATH/plugins/vpn/script.sh"
# FONT is exported rather than left to click.sh's default: the popup rows are
# built outside sketchybarrc's scope, and a hardcoded fallback there would keep
# drawing SF Pro after the config switched fonts.
SCRIPT_CLICK_VPN="export PATH=$PATH; export FONT=\"$FONT\"; $RELPATH/plugins/vpn/click.sh"

## Icon geometry
# The assets are each app's own menu bar glyph, lifted from its Assets.car (see
# assets/extract-vpn-icons.swift). WireGuard ships only a small raster, used at
# its native 44px square. NordVPN ships a vector too, rasterised there at a
# generous 288x240 — small raster and small-target vector both anti-alias away
# to the same soft result, so this renders big and leaves the downscale to
# sketchybar. *_SOURCE_HEIGHT below must track whatever the generator emits.
# Scale is target height over source height, and the two targets differ
# because the apps themselves draw the mountain shorter than the dragon.
WIREGUARD_SOURCE_HEIGHT=44
NORDVPN_SOURCE_HEIGHT=240
WIREGUARD_ICON_HEIGHT=18
NORDVPN_ICON_HEIGHT=14

# Round the icon box UP from the scaled width. NordVPN's artwork fills its
# source edge to edge with no margin of its own, so a box even a fraction of a
# point short shaves the right-hand slope off the mountain.
WIREGUARD_ICON_WIDTH=$((($WIREGUARD_ICON_HEIGHT * 44 + $WIREGUARD_SOURCE_HEIGHT - 1) / $WIREGUARD_SOURCE_HEIGHT))
NORDVPN_ICON_WIDTH=$((($NORDVPN_ICON_HEIGHT * 288 + $NORDVPN_SOURCE_HEIGHT - 1) / $NORDVPN_SOURCE_HEIGHT))

# Chip edge spacing, set through item padding because icon.padding_* does not
# move an icon that is drawn as icon.background.image — setting it changes the
# query output and nothing on screen.
#
# The two numbers differ because the artwork does: at this scale the dragon
# carries about 5pt of margin inside its own canvas while the mountain runs
# right to the edge of its, so the mountain needs that much more before it sits
# level with the dragon against the chip border.
WIREGUARD_EDGE_PADDING=4
NORDVPN_EDGE_PADDING=9

## Item properties
vpn=(
	icon=" "
	icon.background.drawing=on
	label.drawing=off
	# The gap between the two icons. The dragon carries generous margins inside
	# its own artwork and the mountain carries none, so without this the pair sit
	# ~5pt apart against the 7-8pt rhythm the chips either side keep. The outer
	# edges override these per item, below.
	padding_left=2
	padding_right=2
	update_freq=3
	popup.align=center
	popup.height=26
)

## Item addition
# Added after the battery/wifi group and therefore drawn to its left; NordVPN
# goes on first so WireGuard ends up leftmost of the pair.
sketchybar --add event vpn_update

NORDVPN_APP="/Applications/NordVPN.app"
WIREGUARD_APP="/Applications/WireGuard.app"

VPN_ITEMS=()
[ -d "$NORDVPN_APP" ] && VPN_ITEMS+=(vpn.nordvpn)
[ -d "$WIREGUARD_APP" ] && VPN_ITEMS+=(vpn.wireguard)
[ ${#VPN_ITEMS[@]} -eq 0 ] && return 0 # sourced, so return rather than exit

# Divides this chip from the battery/wifi one, the same way separator.1 divides
# that group from the volume controls.
add_separator "2" "right"

if [ -d "$NORDVPN_APP" ]; then
	sketchybar --add item vpn.nordvpn right \
		--set vpn.nordvpn "${vpn[@]}" \
		script="$SCRIPT_VPN nordvpn" \
		click_script="$SCRIPT_CLICK_VPN nordvpn" \
		icon.width=$NORDVPN_ICON_WIDTH \
		padding_right=$NORDVPN_EDGE_PADDING \
		icon.background.image="$RELPATH/assets/nordvpn-off.png" \
		icon.background.image.scale=$(bc <<<"scale=4; $NORDVPN_ICON_HEIGHT / $NORDVPN_SOURCE_HEIGHT") \
		icon.background.height=$NORDVPN_ICON_HEIGHT \
		--subscribe vpn.nordvpn vpn_update mouse.exited.global

	sendLog "Added NordVPN item" "vomit"
fi

if [ -d "$WIREGUARD_APP" ]; then
	sketchybar --add item vpn.wireguard right \
		--set vpn.wireguard "${vpn[@]}" \
		script="$SCRIPT_VPN wireguard" \
		click_script="$SCRIPT_CLICK_VPN wireguard" \
		icon.width=$WIREGUARD_ICON_WIDTH \
		padding_left=$WIREGUARD_EDGE_PADDING \
		icon.background.image="$RELPATH/assets/wireguard-off.png" \
		icon.background.image.scale=$(bc <<<"scale=4; $WIREGUARD_ICON_HEIGHT / $WIREGUARD_SOURCE_HEIGHT") \
		icon.background.height=$WIREGUARD_ICON_HEIGHT \
		--subscribe vpn.wireguard vpn_update mouse.exited.global

	sendLog "Added WireGuard item" "vomit"
fi

## Chip
# Its own bracket rather than joining base-controls: these are network controls
# you act on, not status readouts like the battery and wifi they sat with.
sketchybar --add bracket vpn_controls "${VPN_ITEMS[@]}" \
	--set vpn_controls "${zones[@]}"

sendLog "Added VPN bracket for ${VPN_ITEMS[*]}" "vomit"
