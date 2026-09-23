#!/bin/bash
export RELPATH=$(dirname $0)/../..
shopt -s expand_aliases
command -v 'ft-haptic' 2>/dev/null 1>&2 || alias ft-haptic="$RELPATH/ft-haptic"

case "$SENDER" in
"mouse.clicked")
	open -a "Mission Control"
	;;
"mouse.entered")
	ft-haptic -n 1
	;;
esac
