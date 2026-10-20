#!/bin/sh -e
# Builds 32-bit DXVK-Sarek (DXVK 3.0.2 with Mali patches: fillModeNonSolid, multiViewport,
# robustBufferAccess2 and clip/cull distances made optional) and copies d3d9/d3d11/dxgi into a
# game folder. Stock DXVK (Proton's) refuses the Mali-G610.
#
# Usage: build-dxvk.sh <game folder>
# Needs: git meson ninja-build glslang-tools g++-mingw-w64-i686-posix gcc-mingw-w64-i686-posix
# (the i686-w64-mingw32-gcc/g++ alternatives must point at the -posix variants).

dest="${1:?usage: $0 <game folder>}"
src="${SRC:-$HOME/.cache/DXVK-Sarek}"
tag=v3.0.2-mali-compat-r1
build="${BUILD:-$src/build.32}"

if [ ! -d "$src/.git" ]; then
	git clone --branch "$tag" --recursive https://github.com/zeyadadev/DXVK-Sarek "$src"
fi
git -C "$src" -c advice.detachedHead=false checkout -q "$tag"
git -C "$src" submodule update -q --init --recursive
[ -d "$build" ] || meson setup --cross-file "$src/build-win32.txt" --buildtype release "$build" "$src"
ninja -C "$build"
cp "$build/src/d3d9/d3d9.dll" "$build/src/d3d11/d3d11.dll" "$build/src/dxgi/dxgi.dll" "$dest/"
echo "Copied d3d9.dll, d3d11.dll and dxgi.dll to $dest"
