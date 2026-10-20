#!/bin/sh -e
# Sets up ~/.local/share/fex-thunks for x86 Linux games run through Steam's FEX-Emu compatibility
# tool on the Mali: the launch wrapper (fex-steam), its FEX app config, a FEX config pointing at the
# RootFS, and the thunk libraries - Steam's own plus the Wayland pair rebuilt with our patch, built by
# rebuild.sh for the FEX revision Steam ships.
#
# Needs Steam's FEX-Emu tool installed (steamapps/common/FEX-Emu) and the build packages listed in
# rebuild.sh. Set DEST to install elsewhere.

here=$(dirname "$(readlink -f "$0")")
dest="${DEST:-$HOME/.local/share/fex-thunks}"

mkdir -p "$dest/config" "$dest/patches"
cp "$here/fex-steam" "$here/rebuild.sh" "$dest/"
cp "$here"/patches/*.patch "$dest/patches/"
sed "s#@FEX_THUNKS@#$dest#g" "$here/steam-app-config.json.in" > "$dest/steam-app-config.json"

# The compat tool rewrites this from its template when it runs; this is only the starting point.
[ -f "$dest/config/Config.json" ] || cat > "$dest/config/Config.json" <<JSON
{
  "Config": {
    "X87ReducedPrecision": "1",
    "RootFS": "/usr/share/guestos/fex-mesa/",
    "ThunkHostLibs": "$dest/HostThunks",
    "ThunkGuestLibs": "$dest/GuestThunks"
  }
}
JSON

"$dest/rebuild.sh"
echo "Silksong-style launch options: $dest/fex-steam %command%  (add -force-vulkan for Unity games)"
