#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# Colors

spmt='\033[38;5;5;1m> \033[0m\033[48;5;0m'                   # >_
sqes='\033[48;5;0;38;5;8m[\033[38;5;4m?\033[38;5;8m]\033[0m' # [?]
scac='\033[48;5;0;38;5;8m[\033[38;5;1mx\033[38;5;8m]\033[0m' # [x]
sexc='\033[48;5;0;38;5;8m[\033[38;5;2mo\033[38;5;8m]\033[0m' # [o]
smak='\033[48;5;0;38;5;8m[\033[38;5;5m+\033[38;5;8m]\033[0m' # [+]
swrn='\033[48;5;0;38;5;8m[\033[38;5;3m!\033[38;5;8m]\033[0m' # [!]
syon='(\033[38;5;2;1my\033[38;5;0m/\033[38;5;1;1mn\033[0m)'  # (y/n)

RESET="\033[0m"

# Logging helpers
log() { echo -e "${sexc} $1${RESET}"; }
success() { echo -e "${smak} $1${RESET}"; }
error() {
	echo -e "${scac} $1${RESET}" >&2
	exit 1
}

# Ensure dependencies
for cmd in git brew curl jq; do
	command -v "$cmd" >/dev/null 2>&1 || error "$cmd not found. Please install it first."
done

CONFIG_DIR="$HOME/.config/sketchybar"

### Clone config
# Move the old config aside rather than `rm -rf` it. config.sh is gitignored,
# so it exists only on disk — a blind delete here permanently loses the user's
# own settings (and anything else untracked) with no way to recover them.
if [ -e "$CONFIG_DIR" ]; then
	BACKUP_DIR="$CONFIG_DIR.backup-$(date +%Y%m%d-%H%M%S)"
	mv "$CONFIG_DIR" "$BACKUP_DIR"
	success "Existing config preserved at $BACKUP_DIR"
	log "Copy your settings back afterwards: cp \"$BACKUP_DIR/config.sh\" \"$CONFIG_DIR/\""
fi

log "Cloning sketchybar-config repository..."
git clone --depth 1 https://github.com/Maaboudoufu/sketchybar-config "$CONFIG_DIR"
success "Cloned sketchybar-config repository."

### Install dependencies
log "Installing SketchyBar dependencies..."
brew tap FelixKratz/formulae
brew install sketchybar media-control macmon imagemagick ||
	error "Failed to install formulae."
brew install --cask sf-symbols font-sketchybar-app-font font-sf-pro ||
	error "Failed to install casks."
success "Installed dependencies."

### Download latest icon map with jq
log "Fetching latest icon map..."
latest_tag=$(curl -fsSL https://api.github.com/repos/kvndrsslr/sketchybar-app-font/releases/latest |
	jq -r .tag_name)

log "Latest release tag: $latest_tag"

font_url="https://github.com/kvndrsslr/sketchybar-app-font/releases/download/${latest_tag}/icon_map.sh"
output_path="$CONFIG_DIR/dyn-icon_map.sh"

mkdir -p "$(dirname "$output_path")"
log "Downloading icon map from $font_url..."
if curl -fsSL -o "$output_path" "$font_url"; then
  chmod +x "$output_path"
  success "Downloaded dyn-icon_map.sh → $output_path"
else
  error "Failed to download dyn-icon_map.sh."
  exit 1
fi

### Wifi-unredactor install
read -rp "$(echo -e "${sqes} Do you want to install 'wifi-unredactor' (used to get wifi name in macos 15.5 and later) ? ${syon}: ${RESET}")" install_wifi_unredactor

PREVIOUS_DIR=$PWD
TEMP_DIR=$(mktemp -d)

if [[ "$install_wifi_unredactor" =~ ^[Yy]$ ]]; then
	log "Cloning noperator/wifi-unredactor repository... "
	git clone --depth 1 https://github.com/noperator/wifi-unredactor "$TEMP_DIR"
	success "Cloned noperator/wifi-unredactor repository."
	log "Running wifi-unredactor installer..."
	cd $TEMP_DIR
	# `set -e` aborts on a failed build before any `$?` test could run, so the
	# diagnostic has to hang off the command itself.
	./build-and-install.sh || error "Error compiling wifi-unredactor."
	success "Installed and compiled wifi-unredactor in ~/Applications (do not move)."
	cd "$PREVIOUS_DIR"
	rm -rf "$TEMP_DIR"
	success "Cleaned $TEMP_DIR."
else
	log "Skipped wifi-unredactor installation setup."
fi

### GitHub Notifications Setup
read -rp "$(echo -e "${sqes} Do you want to enable GitHub notifications in SketchyBar? ${syon}: ${RESET}")" enable_github

if [[ "$enable_github" =~ ^[Yy]$ ]]; then
	read -rsp "$(echo -e "${sqes} Please enter your Classic GitHub Token: ${RESET}")" github_token
	echo
	if [[ -n "$github_token" ]]; then
		echo "$github_token" >"$HOME/.github_token"
		chmod 600 "$HOME/.github_token"
		success "GitHub token saved to ~/.github_token (permissions set to 600)."
	else
		# log, not error: error() exits 1, which skipped the reload below and
		# left a cloned config that was never actually loaded.
		log "No token entered. Skipping GitHub notifications setup."
	fi
else
	log "Skipped GitHub notifications setup."
fi

### Restart SketchyBar
log "Restarting SketchyBar..."
brew services restart sketchybar
sketchybar --reload
success "SketchyBar loaded and reloaded."
