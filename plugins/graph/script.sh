#!/bin/bash
export RELPATH=$(dirname $0)/../..
source $RELPATH/set_colors.sh

## Fetch system related data

# One macmon sample covers both power and CPU load. This used to also shell out
# to `top -l1`, but that read the *user* column only — a fully loaded machine
# barely moved the graph (2.5% idle vs 3.5% with four cores pegged), because the
# load showed up under `sys`. cpu_active_ratio is already a 0-1 ratio, so it
# feeds --push directly with no bc round-trip and no scale=1 quantisation.
#
# Not cpu_usage_pct: macmon sets that to the frequency-weighted scaled ratio,
# which reads low whenever the cores are busy but clocked down (~4% where top
# says ~7%). active_ratio is the plain busy fraction. See usage/system.sh.
read -r systempower graphpoint graphpercent < <(
  macmon pipe -s 1 -i 1 |
    jq -r '"\(.sys_power) \(.cpu_active_ratio) \(.cpu_active_ratio * 100)"'
)
# macmon is an optional brew formula and can be absent or fail; without these
# the reads stay empty and sketchybar gets `--push graph` with no value.
: "${systempower:=0}" "${graphpoint:=0}" "${graphpercent:=0}"

# One read instead of three echo|awk round-trips. Trailing $topprog picks up the
# remainder of the line, so process names containing spaces survive intact.
read -r topprog_pid topprog_percent topprog < <(/bin/ps -Aceo pid,pcpu,comm -r | awk 'NR==2')

## Modify top consumming program name color to red if depassing more than 100% cpu

if [[ $(printf "%.0f" $topprog_percent) -gt 100 ]]; then
  LABEL_COLOR=$CRITICAL
else
  LABEL_COLOR=$SUBTLE
fi

## Update graph color depending on cpu load

case $(printf "%.0f" $graphpercent) in
[8-9][0-9] | 7[5-9] | 100)
  COLOR=$CRITICAL
  ;;
[5-6][0-9] | 7[0-4])
  COLOR=$WARN
  ;;
[3-5][0-9] | 2[5-9])
  COLOR=$NOTICE
  ;;
[5-9] | 1[0-9] | 2[0-4])
  COLOR=$SELECT
  ;;
*) COLOR=$SUBTLE ;;
esac

graphlabel="${topprog_percent}% - $topprog [$topprog_pid] | $(printf '%.2f' $systempower)W"

# One client spawn, not two: nothing here depends on the first call landing.
sketchybar --push $NAME $graphpoint \
  --set $NAME.percent label="$(printf "%.0f" $graphpercent)%" \
  --set $NAME graph.color=$COLOR \
  --set $NAME.label label="$graphlabel" label.color="$LABEL_COLOR"
