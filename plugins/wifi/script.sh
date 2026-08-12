#!/bin/bash
export RELPATH=$(dirname $0)/../..
source $RELPATH/set_colors.sh

# Bash does not expand aliases in non-interactive shells without this, and
# `command -v` does not see them either — so the app-bundle fallback below was
# inert and the script always took the legacy ipconfig path, which returns
# <redacted> for the SSID on macOS 15.5+. Matches wifi/click.sh.
shopt -s expand_aliases

WIFI_UNREDACTOR=$1

if ! command -v wifi-unredactor 2>/dev/null 1>&2 && [ -e "$WIFI_UNREDACTOR" ]; then
	alias wifi-unredactor="$WIFI_UNREDACTOR/Contents/MacOS/wifi-unredactor"
fi

ICON_HOTSPOT=􀉤
ICON_WIFI=􀙇
ICON_WIFI_ERROR=􀙥
ICON_WIFI_OFF=􀙈

getname() {

	if command -v wifi-unredactor 2>/dev/null 1>&2; then # Check for wifi-unredactor in path (or as alias)
		# One launch, not two: wifi-unredactor is an app bundle, so each call
		# paid a full process spawn for a single field of the same JSON.
		UNREDACTED=$(wifi-unredactor)
		read -r WIFI_PORT WIFI < <(jq -r '"\(.interface) \(.ssid)"' <<<"$UNREDACTED")
		if [[ $WIFI == "failed to retrieve SSID" ]]; then WIFI=""; fi

	else # Fallback to old system : before macos 15.5
		WIFI_PORT=$(networksetup -listallhardwareports | awk '/Hardware Port: Wi-Fi/{getline; print $2}')
		WIFI="$(ipconfig getsummary $WIFI_PORT | awk -F': ' '/ SSID : / {print $2}')"
		#$(system_profiler SPAirPortDataType | awk '/Current Network/ {getline;$1=$1; gsub(":",""); print;exit}')
		#$(ipconfig getsummary $WIFI_PORT | awk -F': ' '/ SSID : / {print $2}')
	fi

	# sed, not grep|awk: the DHCP sname field is unquoted, so $3 stopped at the
	# first space and "Jason's iPhone" came through as "Jason's".
	HOTSPOT=$(ipconfig getsummary $WIFI_PORT | sed -n 's/.*sname = //p')
	IP_ADDRESS=$(scutil --nwi | grep address | sed 's/.*://' | tr -d ' ' | head -1)
	# Apple's captive-portal probe rather than ipinfo.io: it is the endpoint
	# macOS itself already polls for this exact question, returns a ~70 byte
	# body instead of a full JSON geolocation record, and keeps the bar from
	# reporting the network's name to a third party on every wifi change.
	#
	# The body has to be checked, not the exit status: a captive portal answers
	# this URL with its own login page, and curl counts that 200 as success.
	curl -s -m 2 http://captive.apple.com/hotspot-detect.html | grep -q Success
	INTERNET_UP=$?

	### Set icon according to wifi state

	if [[ $HOTSPOT != "" ]]; then
		ICON=$ICON_HOTSPOT
		ICON_COLOR=$GLOW
		LABEL=$HOTSPOT
	elif [[ $WIFI != "" ]]; then
		ICON=$ICON_WIFI
		ICON_COLOR=$SELECT
		LABEL="$WIFI"
	elif [[ $IP_ADDRESS != "" ]]; then
		ICON=$ICON_WIFI
		ICON_COLOR=$WARN
		LABEL="オン"
	else
		ICON=$ICON_WIFI_OFF
		ICON_COLOR=$CRITICAL
		LABEL="オフ"
	fi

	### If no access to internet change icon + add a notice to the label

	# Test the icon, not the label: the label is display text and gets
	# translated, which would silently stop it ever matching "off".
	if [[ $INTERNET_UP != "0" && $ICON != "$ICON_WIFI_OFF" ]]; then
		ICON=$ICON_WIFI_ERROR
		ICON_COLOR=$SUBTLE
		# $LABEL, not $WIFI: on a hotspot or wired connection $WIFI is empty,
		# which rendered a bare " (インターネットなし)" with no network name.
		LABEL="$LABEL (インターネットなし)"
	fi

	wifi=(
		icon=$ICON
		label="$LABEL"
		icon.color=$ICON_COLOR
	)

	if [[ $WIFI == "<redacted>" ]]; then
		wifi+=(
			label.drawing=off
		)
		echo 'Wifi label hidden : redacted wifi ssid'
	else
		wifi+=(
			label.drawing=on
		)
	fi

	sketchybar --set $NAME "${wifi[@]}"
}

### For performances, only scroll on hover. The read-before-write guard this
### replaces cost a --query (3 spawns) to skip a --set (1 spawn) that, because
### entered/exited strictly alternate, was never actually skippable.
setscroll() { sketchybar --set "$NAME" scroll_texts=$1; }

case "$SENDER" in
"mouse.entered")
	setscroll on
	;;
"mouse.exited")
	setscroll off
	;;
*)
	getname
	;;
esac
