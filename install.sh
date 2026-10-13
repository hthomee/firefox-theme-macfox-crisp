#!/usr/bin/env bash
#
# MacFox Crisp installer
#
# Optional: it only copies files. The repository IS the chrome folder, so
# cloning it into <profile>/chrome works just as well.
#
# Copies the upstream macFox theme unchanged (macfox/), the MacFox Crisp overlay
# (crisp/) and the two small loader files (userChrome.css, userContent.css).
#
# Usage:
#   ./install.sh                   # auto-detect the default Firefox profile
#   ./install.sh /path/to/profile  # install into a specific profile folder
#
# macOS only. After running, fully restart Firefox (Cmd+Q) to apply the theme.
# An existing `chrome` folder is backed up first.

set -euo pipefail

# The upstream theme (macfox/), copied unchanged.
UPSTREAM_FILES=(
	userChrome.css
	userContent.css
	variables.css
	navbar.css
	urlbar.css
	icons.css
	tabbar.css
)

# MacFox Crisp's overlay (crisp/): only what differs from upstream.
CRISP_FILES=(
	crisp.css
	variables.css
	navbar.css
	urlbar.css
	tabbar.css
	chrome.css
)

# SVG icons (shield states, star) referenced from the overlay.
ICON_FILES=(
	shield.svg
	shield-warning.svg
	shield-disabled.svg
	shield-insecure.svg
	star.svg
	star-filled.svg
)

# Resolve the directory this script lives in (the repo root).
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

FIREFOX_DIR="${HOME}/Library/Application Support/Firefox"

die() { printf 'Error: %s\n' "$1" >&2; exit 1; }

# --------------------------------------------------------------------------
# Determine the target profile folder.
# --------------------------------------------------------------------------
profile=""

if [[ $# -ge 1 ]]; then
	profile="$1"
else
	[[ -d "$FIREFOX_DIR" ]] || die "Firefox directory not found at $FIREFOX_DIR"
	ini="${FIREFOX_DIR}/profiles.ini"

	if [[ -f "$ini" ]]; then
		# Prefer the [Install*] section's Default (the profile Firefox launches).
		rel="$(awk -F= '/^\[Install/{f=1} f&&/^Default=/{print $2; exit}' "$ini" || true)"
		# Fall back to a [Profile*] entry marked Default=1.
		if [[ -z "$rel" ]]; then
			rel="$(awk -F= '
				/^\[Profile/{p=""; d=0}
				/^Path=/{p=$2}
				/^Default=1/{d=1}
				d&&p{print p; exit}' "$ini" || true)"
		fi
		[[ -n "$rel" ]] && profile="${FIREFOX_DIR}/${rel}"
	fi

	# Last resort: glob for a *.default-release folder.
	if [[ -z "$profile" ]]; then
		profile="$(find "${FIREFOX_DIR}/Profiles" -maxdepth 1 -name '*.default-release' 2>/dev/null | head -n1 || true)"
	fi
fi

[[ -n "$profile" ]] || die "Could not determine a Firefox profile. Pass one explicitly: ./install.sh /path/to/profile"
[[ -d "$profile" ]] || die "Profile folder does not exist: $profile"

# --------------------------------------------------------------------------
# Check the sources first, so nothing is half-installed.
# --------------------------------------------------------------------------
for f in userChrome.css userContent.css; do
	[[ -f "${SCRIPT_DIR}/${f}" ]] || die "Missing loader file: ${SCRIPT_DIR}/${f}"
done
for f in "${UPSTREAM_FILES[@]}"; do
	[[ -f "${SCRIPT_DIR}/macfox/${f}" ]] || die "Missing upstream file: ${SCRIPT_DIR}/macfox/${f}"
done
for f in "${CRISP_FILES[@]}"; do
	[[ -f "${SCRIPT_DIR}/crisp/${f}" ]] || die "Missing overlay file: ${SCRIPT_DIR}/crisp/${f}"
done
for f in "${ICON_FILES[@]}"; do
	[[ -f "${SCRIPT_DIR}/crisp/icons/${f}" ]] || die "Missing icon: ${SCRIPT_DIR}/crisp/icons/${f}"
done

# --------------------------------------------------------------------------
# Back up an existing chrome folder, then copy the theme in.
# --------------------------------------------------------------------------
chrome_dir="${profile}/chrome"

if [[ -d "$chrome_dir" && -n "$(ls -A "$chrome_dir" 2>/dev/null)" ]]; then
	backup="${chrome_dir}.backup-$(date +%Y%m%d-%H%M%S)"
	cp -R "$chrome_dir" "$backup"
	printf 'Existing chrome folder backed up to:\n  %s\n\n' "$backup"
fi

mkdir -p "$chrome_dir/macfox" "$chrome_dir/crisp/icons"

printf 'Installing MacFox Crisp into:\n  %s\n\n' "$chrome_dir"

for f in "${UPSTREAM_FILES[@]}"; do
	cp "${SCRIPT_DIR}/macfox/${f}" "$chrome_dir/macfox/"
	printf '  macfox/%s\n' "$f"
done

for f in "${CRISP_FILES[@]}"; do
	cp "${SCRIPT_DIR}/crisp/${f}" "$chrome_dir/crisp/"
	printf '  crisp/%s\n' "$f"
done
for f in "${ICON_FILES[@]}"; do
	cp "${SCRIPT_DIR}/crisp/icons/${f}" "$chrome_dir/crisp/icons/"
	printf '  crisp/icons/%s\n' "$f"
done

# The files Firefox itself loads: they pull in macfox/ first, then crisp/.
cp "${SCRIPT_DIR}/userChrome.css" "$chrome_dir/userChrome.css"
cp "${SCRIPT_DIR}/userContent.css" "$chrome_dir/userContent.css"
printf '  userChrome.css, userContent.css (load macfox/ then crisp/)\n'

cat <<'MSG'

Done. Next steps:
  1. In about:config, make sure these are set to true (create them as Boolean if
     they do not exist):
       toolkit.legacyUserProfileCustomizations.stylesheets   (required)
       svg.context-properties.content.enabled                (required, icons)
       browser.theme.native-theme                            (recommended)
     Optional, pill-shaped Tahoe look:
       userChrome.tahoeUI.enabled
  2. Fully restart Firefox (Cmd+Q, then reopen) to apply the theme.
MSG
