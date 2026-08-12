#!/bin/bash
export RELPATH=$(dirname $0)/../..;
source $RELPATH/set_colors.sh

GITHUB_TOKEN=$1 # (~/.github_token)

# Check for github token 
if [[ -f $1 ]]; then
	GITHUB_TOKEN_TEXT="$(cat $1)" # Should be a PAT with only notification reading permissions
  # Get all user's notifications
  # -f matters: without it curl exits 0 on 401/403, so an expired PAT or a rate
  # limit reads as "you have no notifications" instead of reaching the -- state.
  notifications="$(curl -m 15 -sf \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN_TEXT" \
    https://api.github.com/notifications )"
  
  curlSuccess=$?

  # Only an array is a notification list. On an auth or rate-limit failure the
  # API answers 200 with an object like {"message":..,"documentation_url":..},
  # and a bare `length` counted its keys as unread notifications.
  count=$(echo "$notifications" | jq 'if type == "array" then length else 0 end' 2>/dev/null)
  : "${count:=0}"

  item=(
    label="$count"
  )

  ### Set icon + label depending on success and notification number

  if [[ $curlSuccess != 0 ]];then 
    item+=(
      icon=􀋞
      icon.color=$SUBTLE
      label="--"
    )
  elif [ $count -gt 0 ]; then
    item+=(
      icon=􀝗
      icon.color=$CRITICAL
    )
  else 
    item+=(
      icon=􀋚
      icon.color=$SELECT
    )
  fi

  sketchybar --set "$NAME" "${item[@]}"
else

  ### If No github token, hide the menu item
  item=(
    width=0
		label.drawing="off"
		icon.drawing="off"
  )
  sketchybar --set "$NAME" "${item[@]}"
fi
