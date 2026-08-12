#!/bin/bash

##
# Shared state for the WireGuard and NordVPN items.
#
# Both apps ship their tunnels as network-extension configurations, and that is
# also what their own menu bar items drive — so `scutil --nc` can list them,
# report their state and start or stop them. It is the whole control surface
# these two widgets need, which is why their popups can offer the same actions
# as the native menus without going anywhere near the real menu bar.
##

vpn_bundle_id() { # $1 = provider key
	case $1 in
	wireguard) echo com.wireguard.macos ;;
	nordvpn) echo com.nordvpn.NordVPN ;;
	esac
}

vpn_app_name() { # $1 = provider key
	case $1 in
	wireguard) echo WireGuard ;;
	nordvpn) echo NordVPN ;;
	esac
}

# "<state>|<tunnel name>", one line per configured tunnel of one provider,
# parsed out of lines that look like:
#   * (Connected)  <uuid> VPN (com.wireguard.macos) "macbook"  [VPN:com.wireguard.macos]
# State is one of Connected / Connecting / Disconnecting / Disconnected.
vpn_tunnels() { # $1 = provider key
	scutil --nc list 2>/dev/null | grep -F "($(vpn_bundle_id "$1"))" |
		sed -n 's/^[^(]*(\([^)]*\)).*"\(.*\)".*/\1|\2/p'
}

# Surface an app's own UI.
#
# `open -a` cannot do this. Both apps are LSUIElement agents: no dock icon, no
# URL scheme, no AppleScript dictionary, and no window left for a reopen event
# to restore — WireGuard's tunnel manager and NordVPN's dashboard are built by
# their status items and by nothing else. So this drives that status item, which
# is the one place the native menu is unavoidable. The popup it is reached from
# is still entirely ours.
vpn_show_app() { # $1 = provider key
	local proc title
	proc="$(vpn_app_name "$1")"

	# An agent that is not running has no status item to drive, and System Events
	# fails with "can't get process" — straight to stderr, where a popup row's
	# click_script discards it, so the row looked dead. Launching is the one thing
	# `open -a` is good for here; the status item lands a moment after the process.
	if ! pgrep -x "$proc" >/dev/null 2>&1; then
		open -a "$proc" 2>/dev/null || return 1
		for _ in $(seq 20); do
			pgrep -x "$proc" >/dev/null 2>&1 && break
			sleep 0.25
		done
		sleep 1
	fi

	# WireGuard needs a second click to reach the manager; NordVPN's status item
	# opens its dashboard on its own. The title is localized, so take it from the
	# app rather than pinning one language.
	[ "$1" = wireguard ] && title="$(vpn_menu_string macMenuManageTunnels)"

	osascript - "$proc" "${title:-}" <<-'AS'
		on run argv
			set proc to item 1 of argv
			set wanted to item 2 of argv
			tell application "System Events" to tell process proc
				set statusItem to menu bar item 1 of menu bar 2
				click statusItem
				if wanted is not "" then
					delay 0.3
					try
						click (first menu item of menu 1 of statusItem whose name is wanted)
					on error
						-- never leave the app's own menu hanging open
						perform action "AXCancel" of menu 1 of statusItem
					end try
				end if
			end tell
		end run
	AS
}

# A string from WireGuard's own localisation, in the current UI language, so the
# menu item is found whatever the system is set to.
vpn_menu_string() { # $1 = strings key
	local res=/Applications/WireGuard.app/Contents/Resources lang
	lang="$(defaults read -g AppleLocale 2>/dev/null | cut -d_ -f1)"
	plutil -extract "$1" raw "$res/$lang.lproj/Localizable.strings" 2>/dev/null ||
		plutil -extract "$1" raw "$res/Base.lproj/Localizable.strings" 2>/dev/null
}

# One state for the provider as a whole: WireGuard can hold several tunnels and
# any live one makes the icon light up, same as its own menu bar item.
vpn_state() { # $1 = provider key
	local tunnels state
	tunnels="$(vpn_tunnels "$1")"
	for state in Connected Connecting Disconnecting; do
		grep -q "^$state|" <<<"$tunnels" && {
			echo "$state"
			return
		}
	done
	echo Disconnected
}
