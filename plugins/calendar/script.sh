#!/bin/bash

##
# Renders the date and clock.
#
# The clock carries seconds, so update_freq drives this once a second and there
# is nothing left to align to a minute boundary — this used to sleep out the
# remainder of the current minute to land the rollover precisely.
#
# One `date`, not two: the icon and label then always come from the same instant
# rather than straddling a second boundary on the way past midnight.
##

IFS='|' read -r DATE CLOCK < <(LC_TIME=ja_JP.UTF-8 date '+%-m月%-d日(%a)|%H:%M:%S')

sketchybar --set "${NAME:?}" icon="$DATE" label="$CLOCK"
