#!/bin/sh -e
# Rebuild FEX's Wayland thunks (patches/fex-wayland-listener-version.patch) for the FEX build that
# Steam's FEX-Emu compatibility tool ships, and refresh HostThunks/GuestThunks/GuestThunks_32 here:
# Steam's own thunk libraries, with the patched libwayland-client pair on top. Rerun after Steam
# updates the FEX-Emu tool, since thunk libraries must match the FEX they are loaded by.
#
# Needs: clang lld libclang-dev llvm-dev g++-x86-64-linux-gnu cmake ninja-build libwayland-dev
# (plus the OpenGL/OpenSSL/SDL2 development packages FEX's configure step looks for).

here=$(dirname "$(readlink -f "$0")")
fextool="${FEXTOOL:-$HOME/.local/share/Steam/steamapps/common/FEX-Emu}"
work="${WORK:-$HOME/.cache/fex-thunk-build}"
rev=$(awk '$1 == "FEX" && $2 == "bash" { print $3 }' "$fextool/VERSIONS.txt")
[ -n "$rev" ] || { echo "Cannot read the FEX revision from $fextool/VERSIONS.txt" >&2; exit 1; }
echo "Steam's FEX: $rev"

if [ ! -d "$work/.git" ]; then
	git clone --filter=blob:none https://github.com/FEX-Emu/FEX.git "$work"
fi
cd "$work"
git fetch -q origin "$rev" 2>/dev/null || git fetch -q origin
git reset -q --hard "$rev"
for m in External/vixl Source/Common/cpp-optparse External/fmt External/drm-headers External/xxhash \
	External/Vulkan-Headers External/jemalloc_glibc External/range-v3 External/zydis \
	External/unordered_dense External/rpmalloc External/tracy External/Catch2; do
	git submodule update -q --init --depth 1 "$m"
done
git apply "$here/patches/fex-wayland-listener-version.patch"

# The system fmt is older than FEX supports, so make FEX fall back to its bundled copy.
CC=clang CXX=clang++ cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DBUILD_THUNKS=ON \
	-DBUILD_FEXCONFIG=OFF -DBUILD_TESTING=OFF -DENABLE_LTO=OFF -DENABLE_CCACHE=OFF \
	-DCMAKE_DISABLE_FIND_PACKAGE_fmt=ON -DX86_DEV_ROOTFS=/
CCACHE_DISABLE=1 ninja -C build wayland-client-host-64 guest-libs

rm -rf "$here/HostThunks" "$here/GuestThunks" "$here/GuestThunks_32"
cp -a "$fextool/usr/lib/aarch64-linux-gnu/fex-emu/HostThunks" "$here/"
cp -a "$fextool/usr/share/fex-emu/GuestThunks" "$fextool/usr/share/fex-emu/GuestThunks_32" "$here/"
cp build/HostLibs_64/libwayland-client-host.so "$here/HostThunks/"
cp build/Guest/libwayland-client-guest.so "$here/GuestThunks/"

# Keep the pressure-vessel overlay paths in step with Steam's ThunksDB.
mkdir -p "$here/config"
python3 - "$fextool/usr/share/fex-emu/ThunksDB.json" "$here/config/ThunksDB.json" <<'EOF'
import json, sys
db = json.load(open(sys.argv[1]))
pv = "/usr/lib/pressure-vessel/overrides/lib/x86_64-linux-gnu/"
for entry in db["DB"].values():
    extra = [pv + o.split("/")[-1] for o in entry["Overlay"] if o.startswith("@PREFIX_LIB@/")]
    entry["Overlay"] += [x for x in extra if x not in entry["Overlay"]]
json.dump(db, open(sys.argv[2], "w"), indent=2)
EOF
echo "Thunks refreshed for $rev in $here"
