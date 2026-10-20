#!/bin/sh -e
# Puts Microsoft's 32-bit d3dcompiler_43.dll into a game folder, from the DirectX June 2010
# redistributable (the file winetricks uses). Games that compile HLSL at startup through D3DX9
# otherwise run Wine's built-in compiler under emulation; with this DLL, one such game starts in
# ~20 s instead of ~190 s. Launch with WINEDLLOVERRIDES=d3dcompiler_43=n,b.
#
# Usage: get-d3dcompiler.sh <game folder>      (needs curl and cabextract)

dest="${1:?usage: $0 <game folder>}"
cache="${CACHE:-$HOME/.cache/dxredist}"
exe=directx_Jun2010_redist.exe
url=https://download.microsoft.com/download/8/4/A/84A35BF1-DAFE-4AE8-82AF-AD2AE20B6B14/$exe
sha=053f76dcbb28802e23341b6a787e3b0791c0fa5c8d4d011b1044172dbf89c73b

mkdir -p "$cache"
cd "$cache"
if ! echo "$sha  $exe" | sha256sum -c --status - 2>/dev/null; then
	curl -fL --retry 3 -o "$exe" "$url"
	echo "$sha  $exe" | sha256sum -c -
fi
cabextract -q -L -F jun2010_d3dcompiler_43_x86.cab "$exe"
cabextract -q -L -F d3dcompiler_43.dll jun2010_d3dcompiler_43_x86.cab
cp d3dcompiler_43.dll "$dest/"
echo "Copied d3dcompiler_43.dll to $dest"
