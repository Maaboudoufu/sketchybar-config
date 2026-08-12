#!/bin/bash
## Resolve relative to this file, not the caller's cwd: plugin scripts are the
## main consumers and sketchybar only happens to run them from the config dir.
__COLORS_DIR="${BASH_SOURCE[0]%/*}" # no dirname fork; every source path has a /
source "$__COLORS_DIR/log_handler.sh" ## Sourcing needed because it can be called outside of sketchybarrc sourcing

# Config sourcing
if [[ -n "$SKETCHYBAR_CONFIG" && -f "$SKETCHYBAR_CONFIG" ]]; then
	# External override path (useful for Nix)
	# shellcheck disable=SC1090
	source "$SKETCHYBAR_CONFIG"
elif [[ -f "$__COLORS_DIR/config.sh" ]]; then
	# Local config file in repository
	# shellcheck disable=SC1091
	source "$__COLORS_DIR/config.sh"
fi

# Defaults

export COLOR_SCHEME=${COLOR_SCHEME:-rosepine-moon}
export BAR_TRANSPARENCY=${BAR_TRANSPARENCY:-true}
: "${THEME_FILE_PATH:="./theme.sh"}"

case "$COLOR_SCHEME" in
# Rosé pine Moon theme
"rosepine-moon")
	if [[ $BAR_TRANSPARENCY == true ]]; then
		TFrate=20 # ~8% alpha - very light tint, blur does most of the work now that shadow bleed is fixed
	else
		TFrate=255
	fi

	# %02X, not bc: bc drops the leading zero for values < 16, which yields a
	# 9-character colour like 0xA232136 that sketchybar cannot parse.
	printf -v TFp '%02X' "$TFrate" # Set primary transparency factor
	[ $((TFrate + 20)) -lt 255 ] && TFrate=$((TFrate + 20))
	printf -v TFs '%02X' "$TFrate" # Set secondary transparency factor

	# Default Theme colors
	export BASE=0x${TFp}232136
	export SURFACE=0x${TFp}2a273f
	# Item chips get no blur of their own (sketchybar only blurs the bar/popup layer), so they sit
	# on top of the bar's already-blurred surface as a flat tint — keep them at the slightly
	# stronger TFs tier so they still read as distinct glass "buttons" against the bar.
	export OVERLAY=0x${TFs}393552
	export MUTED=0x${TFp}6e6a86
	export HIGH_LOW=0x${TFs}2a283e
	export HIGH_MED=0x${TFs}44415a
	export HIGH_HIGH=0x${TFs}56526e
	export SUBTLE=0xff908caa
	export TEXT=0xffe0def4
	export CRITICAL=0xffeb6f92
	export NOTICE=0xfff6c177
	export WARN=0xffea9a97
	export SELECT=0xff3e8fb0
	export GLOW=0xff9ccfd8
	export ACTIVE=0xffc4a7e7

	export BLACK=0xff181926
	export TRANSPARENT=0x00000000

	# General bar colors
	export BAR_COLOR=0x${TFp}232137
	export BORDER_COLOR=0x5AFFFFFF # translucent white rim, like a glass edge highlight

	export ICON_COLOR=$TEXT  # Color of all icons
	export LABEL_COLOR=$TEXT # Color of all labels

	export POPUP_BACKGROUND_COLOR=0x${TFs}393552
	export POPUP_BORDER_COLOR=$BORDER_COLOR

	export SHADOW_COLOR=0x50000000 # translucent black, for the floating-glass drop shadow
	;;

# Catpuccin Mocha theme
"catppuccin-mocha")
	# Default Theme colors
	export BASE=0xff1e1e2e
	export SURFACE=0xff6c7086
	export OVERLAY=0xff313244
	export MUTED=0xff6e6a86
	export SUBTLE=0xff908caa

	export TEXT=0xffcdd6f4
	export CRITICAL=0xfff38ba8
	export NOTICE=0xfff9e2af
	export WARN=0xffeba0ac
	export SELECT=0xff89b4fa
	export GLOW=0xff89dceb
	export ACTIVE=0xffcba6f7

	export HIGH_LOW=0xff1e1e2e
	export HIGH_MED=0xff45475a
	export HIGH_HIGH=0xff585b70

	export BLACK=0xff11111b
	export TRANSPARENT=0x00000000

	# General bar colors
	if [[ $BAR_TRANSPARENCY == true ]]; then
		export BAR_COLOR=0xB81f1f30
		export BORDER_COLOR=0xB845475a
	elif [[ $BAR_TRANSPARENCY == false ]]; then
		export BAR_COLOR=0xff1f1f30
		export BORDER_COLOR=0xff45475a
	fi
	export ICON_COLOR=$TEXT  # Color of all icons
	export LABEL_COLOR=$TEXT # Color of all labels

	export POPUP_BACKGROUND_COLOR=0xbe393552
	export POPUP_BORDER_COLOR=$HIGH_MED

	export SHADOW_COLOR=$TEXT
	;;
*)
	if [[ -n "$THEME_FILE_PATH" && -f "$THEME_FILE_PATH" ]]; then
		sendLog "Theme specified isn't a default theme ($COLOR_SCHEME), Loading custom theme file $THEME_FILE_PATH" "info"
		source "$THEME_FILE_PATH"
	else
		sendErr "Theme specified isn't a default theme ($COLOR_SCHEME) and no theme.sh was specified" "info"
		exit
	fi
	;;
esac
