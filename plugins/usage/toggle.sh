#!/bin/bash

##
# Click handler for both More-menu usage slots: flips them between AI
# subscription usage and live CPU / RAM. Bound to moremenu.pkgs and
# moremenu.user alike, so a click on either one toggles the pair.
##

RELPATH="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
source "$RELPATH/plugins/usage/lib.sh"

if usage_in_system_mode; then
	rm -f "$USAGE_MODE_FILE" # back to Claude / Codex usage
	FREQ=300
	REPLAY=(ai_pkgs ai_user)
else
	: >"$USAGE_MODE_FILE" # switch to CPU / RAM
	FREQ=5
	REPLAY=(sys)
fi

# Paint the target mode from its last render before anything blocks, so the
# click lands instantly. The trigger below then refreshes the numbers in place.
# Nothing to replay only on the first toggle of a fresh boot.
usage_replay "${REPLAY[@]}"

# update_freq follows the mode: subscription quotas move over minutes, CPU and
# RAM over seconds. Both items keep updates=when_shown, so the faster poll only
# runs while the More-menu is actually open.
sketchybar --set moremenu.pkgs update_freq=$FREQ \
	--set moremenu.user update_freq=$FREQ \
	--trigger more-menu-update
