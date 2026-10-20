#!/bin/sh -e
# Downloads FEX's x86-64 Ubuntu 24.04 RootFS, unpacks it, and links it where Steam's FEX-Emu
# compatibility tool looks for it (/usr/share/guestos/fex-mesa). Without it every x86 Linux game
# exits at once; FEX prints "RootFS path doesn't exist" to Steam's stderr. The RootFS supplies the
# x86 libraries (glibc, Mesa, the Vulkan loader) that games load under emulation.
#
# Usage: get-rootfs.sh      (asks for the sudo password once, for the link in /usr/share)
# Needs: curl squashfs-tools xxhash
#
# The image and its XXH3 hash come from https://rootfs.fex-emu.gg/RootFS_links.json
# ("Ubuntu 24.04 (SquashFS)"). The unpacked tree is ~1.4 GB; the download (~500 MB) is deleted
# afterwards. Set DEST to unpack elsewhere.

dest="${DEST:-$HOME/.local/share/fex-rootfs}"
name=Ubuntu_24_04
url=https://rootfs.fex-emu.gg/Ubuntu_24_04/2026-08-11/$name.sqsh
xxh3=3517e0e5ea25a473
link=/usr/share/guestos/fex-mesa

mkdir -p "$dest"
cd "$dest"

if [ -d "$name" ]; then
	echo "$dest/$name already unpacked"
else
	verified() { [ -f "$name.sqsh" ] && [ "$(xxhsum -H3 "$name.sqsh" | sed 's/^XXH3_//; s/ .*//')" = "$xxh3" ]; }
	if ! verified; then
		curl -fL --retry 3 -o "$name.sqsh" "$url"
		verified || { echo "$name.sqsh: XXH3 hash is not $xxh3" >&2; exit 1; }
	fi
	# Unpack beside the final name and rename at the end, so an interrupted run never leaves a
	# half-unpacked tree that looks finished. As non-root, unsquashfs can't create the image's
	# device nodes: it reports those and exits with 2 (non-fatal errors). FEX doesn't need them.
	rm -rf "$name.part"
	unsquashfs -n -q -d "$name.part" "$name.sqsh" || [ $? -eq 2 ]
	mv "$name.part" "$name"
	rm "$name.sqsh"
fi

if [ "$(readlink "$link")" = "$dest/$name" ]; then
	echo "$link already points to $dest/$name"
else
	sudo mkdir -p "$(dirname "$link")"
	sudo ln -sfn "$dest/$name" "$link"
	echo "Linked $link -> $dest/$name"
fi
