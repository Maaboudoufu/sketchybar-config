#!/bin/bash

##
# Draws one VPN item: the app's own menu bar glyph, in the bright variant while
# a tunnel is up and the dimmed one when none is. Both apps ship exactly that
# pair of images and switch between them the same way.
#
# Also handles the click-away that closes the popup, since sketchybar routes
# subscribed events through the item's script.
##

RELPATH="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
source "$RELPATH/plugins/vpn/lib.sh"

PROVIDER=${1:?}

if [ "$SENDER" = "mouse.exited.global" ]; then
	sketchybar --set "${NAME:?}" popup.drawing=off
	exit 0
fi

# Connecting counts as lit: the icon should react to the click, not wait out the
# handshake looking untouched.
case "$(vpn_state "$PROVIDER")" in
Connected | Connecting) VARIANT=on ;;
*) VARIANT=off ;;
esac

sketchybar --set "${NAME:?}" \
	icon.background.image="$RELPATH/assets/$PROVIDER-$VARIANT.png"
