#!/bin/sh -e
# Installs the ARM64 Steam client into ~/.local/share/Steam. Valve offers no ARM64 installer
# package, so the bootstrap is put together by hand: the client manifest (steam_client_linuxarm64)
# names the current steam_linuxarm64 and bins_linuxarm64_linuxarm64 archives and their SHA-256,
# and the two are unpacked over each other. Their entries use Windows path separators, so bsdtar
# rewrites "\" to "/". Steam then bootstraps itself (steam.sh fails, steamrtarm64/steam downloads
# the rest and quits), and the ~/.steam/sdkarm64 link that Steam's FEX-Emu tool needs is added.
#
# Usage: install-steam.sh      then start Steam with ~/.local/share/Steam/steamrtarm64/steam
# Needs: curl libarchive-tools (bsdtar)
#
# Does nothing to an existing install apart from the link: unpacking the bootstrap again would
# overwrite files Steam has since updated. Set CACHE to keep the downloads elsewhere.

steam="$HOME/.local/share/Steam"
cache="${CACHE:-$HOME/.cache/steam-arm64}"
cdn=https://client-update.steamstatic.com

# fetch <package>: download the package's current archive named in the manifest, check its SHA-256,
# and print its path.
fetch() {
	set -- $(awk -v k="\"$1\"" '
		$1 == k { f = 1 }
		f && $1 == "\"file\"" { gsub(/"/, "", $2); file = $2 }
		f && $1 == "\"sha2\"" { gsub(/"/, "", $2); print file, $2; exit }' steam_client_linuxarm64)
	[ -n "$2" ] || { echo "Package not found in steam_client_linuxarm64" >&2; exit 1; }
	if ! echo "$2  $1" | sha256sum -c --status - >/dev/null 2>&1; then
		curl -fL --retry 3 -o "$1" "$cdn/$1" >&2
		echo "$2  $1" | sha256sum -c - >&2
	fi
	echo "$cache/$1"
}

if [ -x "$steam/steamrtarm64/steam" ]; then
	echo "Steam is already installed in $steam"
else
	mkdir -p "$cache" "$steam"
	cd "$cache"
	curl -fL --retry 3 -o steam_client_linuxarm64 "$cdn/steam_client_linuxarm64"
	echo "Client version $(awk '$1 == "\"version\"" { gsub(/"/, "", $2); print $2; exit }' steam_client_linuxarm64)"
	boot=$(fetch steam_linuxarm64)
	bins=$(fetch bins_linuxarm64_linuxarm64)

	bsdtar -xf "$boot" -C "$steam" -s ',\\,/,g'
	chmod -R +x "$steam"
	bsdtar -xf "$bins" -C "$steam" -s ',\\,/,g'
	chmod -R +x "$steam/steamrtarm64"

	# steam.sh sets up ~/.steam before it fails on the missing x86 client; the ARM64 client then
	# bootstraps and quits.
	"$steam/steam.sh" || true
	"$steam/steamrtarm64/steam" || true
fi

mkdir -p "$HOME/.steam"
ln -sfn "$steam/linuxarm64" "$HOME/.steam/sdkarm64"
echo "Start Steam with $steam/steamrtarm64/steam"
