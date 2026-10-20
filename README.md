# x86 Steam games through FEX on the Mali-G610

Steps to run an x86-64 Linux game from the ARM64 Steam client, through Steam's FEX-Emu compatibility tool, on an RK3588 board whose Mali-G610 runs on the kbase driver. The reference games are Hollow Knight: Silksong (native x86 Linux, through FEX) and a Windows Direct3D 9 game (32-bit, through Proton ARM64).

Each step says what to run and how to check it. A step marked *(not yet confirmed on the CM5)* hasn't been run on the machine below yet.

| Path | What |
|---|---|
| `steam/` | `install-steam.sh` (ARM64 Steam client) |
| `fex/` | `get-rootfs.sh` (x86 RootFS), `fex-steam` launch wrapper, FEX app config template, `rebuild.sh` (thunk libraries), the Wayland thunk patch, `install.sh` |
| `games/` | `build-dxvk.sh` (DXVK-Sarek), `get-d3dcompiler.sh` (Microsoft's HLSL compiler), for Proton games (step 5) |
| `device/` | Vulkan layer order for MangoHud (optional) |
| `armbian/` | the CM5's Armbian build inputs: board file, mixer state, kernel and U-Boot patches, `customize-image.sh` (step 0) |

## Starting point

The steps were written on a RetrOLED CM5 (Radxa CM5, RK3588S) running Armbian trunk `resolute` (Ubuntu 26.04) on the `edge-rockchip64` kernel, 7.3-rc7. The image is built from `armbian/build` `5eda7293b` with this repo's `armbian/tree/` copied in (step 0). The image already has:

| Package | Version | From | Role |
|---|---|---|---|
| `mali-valhall-g610-dkms` | 1.0.1 | `ginkage/mali-dkms` | `valhall_kbase.ko`, the vendor kbase ported to mainline, with the low32 alias ioctl; its `kernel-patches/` add the `system-uncached` dma-heap and the rockchip render node |
| `libmali-valhall-g610-g29p1` | 1.10-1 | `ginkage/libmali-rockchip` | GBM/EGL/GLES/Vulkan, bundling the WSI layer (`VkLayer_window_system_integration`) with low-address mapping |
| `xwayland` | 2:24.1.10-1+cixmali2 | `ginkage/xserver` | Xwayland with Mali glamor |
| `libwayland-client0` | 1.26.0-1~r~ppa1 | PPA | 1.26 adds `wl_pointer.warp`, which Steam's stock Wayland thunk aborts on (step 3) |

With Steam and Silksong installed (step 1), Steam's FEX-Emu tool on the CM5 is `FEX-2607-76-g37265b1` (`steamapps/common/FEX-Emu/VERSIONS.txt`).

## When a game won't start

Steam's own logs show little: `~/.local/share/Steam/logs/gameprocess_log.txt` only records that the game's processes exited, about 2 seconds after launch. The errors are elsewhere:
- `/tmp/fex-compat-tool-<pid>.log`: the environment Steam passed to the FEX tool and the tool's own messages. The newest one belongs to the latest launch.
- FEX's and the game's stderr go to Steam's stderr: the terminal Steam was started from, if any.
- FEX can be run by hand with the config Steam wrote for the game (Silksong's app ID is 1030300). It should print `x86_64`:
  ```sh
  FEX_PORTABLE=1 FEX_APP_CONFIG_LOCATION=$HOME/.local/share/Steam/steamapps/compatdata/1030300/fex-emu/ \
    ~/.local/share/Steam/steamapps/common/FEX-Emu/usr/bin/FEX /bin/uname -m
  ```

## 0. System: the image, gamepad access and sound

Besides the GPU stack, the CM5 needs two things a plain Armbian image lacks:
- **Gamepad in games:** Steam Input creates a virtual Xbox pad through `/dev/uinput`, which is root-only unless `steam-devices` is installed. Without it, Steam sees the CM5 pad, but Silksong gets no input: its input library ignores pads it doesn't know by name.
- **Sound:** the WM8960 codec's "Left/Right Output Mixer PCM Playback" switches are off, so the DAC isn't routed to the speaker or headphone amps, and the saved mixer state brings them back off at every boot.

### On a new image

`armbian/tree/` holds the CM5's build inputs, at their paths in `armbian/build`:
- `config/boards/retroled-cm5.csc`: the board. It sets `ASOUND_STATE`, and its hooks name the sound cards and put the built-in pad's SDL mapping in `/etc/environment.d`.
- `packages/blobs/asound.state/asound.state.retroled-cm5`: the mixer state saved from this CM5 once the speaker worked, with both PCM switches on and Playback (the DAC) at 0 dB. Armbian copies it to `/var/lib/alsa/asound.state`, and `alsa-restore` restores it at boot and saves changes at shutdown.
- `userpatches/kernel/archive/rockchip64-7.3/`: the kernel patches, and the CM5's device tree in `dt/`. They add the display panel (Raydium RM67199), touch (Goodix GT9886) and fuel gauge (MAX17055) drivers, the four patches from `mali-dkms`'s `kernel-patches/`, and sound and display fixes.
- `userpatches/u-boot/legacy/u-boot-radxa-rk35xx/`: the CM5's defconfig and device tree for Radxa's U-Boot (`next-dev-v2024.10`).
- `userpatches/customize-image.sh`: for `resolute`, installs packages (among them `steam-devices` and everything steps 1–5 `apt install`) and the files below, and blacklists panthor, so that kbase drives the GPU.

`customize-image.sh` takes these from the build tree's `userpatches/overlay/`. Build the debs on an arm64 machine:

| File | Source | Build |
|---|---|---|
| `mali-valhall-g610-dkms_1.0.1_all.deb` | `ginkage/mali-dkms` `main` (`b2fceb4`) | `debuild -us -uc -b` (needs `debhelper dh-dkms dkms devscripts`) |
| `libmali-valhall-g610-g29p1_1.10-1_arm64.deb` | `ginkage/libmali-rockchip` `master` (`1163985`) | `dpkg-buildpackage -b -us -uc`, which builds every target in `debian/targets` |
| `xwayland_24.1.10-1+cixmali2_arm64.deb` | `ginkage/xserver` `24.1.10` (`f012f75`) | `sudo apt build-dep ./ && sudo apt install fakeroot`, then `DEB_BUILD_OPTIONS=nocheck dpkg-buildpackage -b -us -uc` |
| `goodix_cfg_group.bin` | `ginkage/Retro-Lite-CM5`, `armbian/userpatches/overlay/` | none: the touch controller's configuration |

Xwayland's `sync` test fails when it's built inside a running desktop session: its Xvfb finds the display socket taken. `nocheck` skips the tests.

Then build:

```sh
git clone https://github.com/armbian/build armbian-build && cd armbian-build
git checkout 5eda7293bab43a581de02f769139848b6e922328
cp -a /path/to/this/repo/armbian/tree/. .
mkdir -p userpatches/overlay
cp mali-valhall-g610-dkms_1.0.1_all.deb libmali-valhall-g610-g29p1_1.10-1_arm64.deb \
   xwayland_24.1.10-1+cixmali2_arm64.deb goodix_cfg_group.bin userpatches/overlay/
./compile.sh build BOARD=retroled-cm5 BRANCH=edge RELEASE=resolute BUILD_DESKTOP=yes BUILD_MINIMAL=no \
  DESKTOP_ENVIRONMENT=gnome DESKTOP_ENVIRONMENT_CONFIG_NAME=config_base \
  DESKTOP_APPGROUPS_SELECTED='programming remote_desktop' EXPERT=yes INSTALL_HEADERS=yes KERNEL_BTF=yes \
  KERNEL_CONFIGURE=no PREFER_DOCKER=no
```

- `INSTALL_HEADERS=yes` puts the kernel headers in the image. DKMS needs them to build kbase.
- The image was built natively (`PREFER_DOCKER=no`) on an arm64 Ubuntu 24.04 host.
- Armbian writes the build tree's `origin` URL into the image's `/etc/armbian-release` (`BUILD_REPOSITORY_URL`). Clone `armbian/build` with a plain URL, never one with a token in it.

Check: on first boot, without any manual step, the checks under "On an existing install" pass.

Status: the image built this way on 2026-10-20 works on the CM5. On its first boot, sound and the gamepad worked in Steam with no manual step. Which output plays (speaker or headphones) is left to the driver; there's no UCM profile.

### On an existing install

The same changes by hand:

```sh
# gamepad
sudo apt install steam-devices
sudo modprobe uinput        # or reboot; this applies the new udev rule now

# sound: route the DAC, then save it as the state restored at boot
amixer -c wm8960soundcard sset 'Left Output Mixer PCM' on
amixer -c wm8960soundcard sset 'Right Output Mixer PCM' on
amixer -c wm8960soundcard sset Playback 0dB
amixer -c wm8960soundcard sset Speaker 0dB
sudo alsactl store
```

Checks:
- `getfacl -p /dev/uinput` lists `user:<you>:rw-`. With a game running under Steam Input, `grep '^N: ' /proc/bus/input/devices` lists an extra (virtual) pad.
- `pw-play /usr/share/sounds/alsa/Front_Left.wav` (and `Front_Right.wav`) plays from the speaker, and still does after a reboot.

Status on the CM5: `steam-devices` with `modprobe uinput` fixed the gamepad in Silksong. The `amixer` lines gave working sound from the speaker. `alsactl store` and the reboot check have **not been tested yet**.

## 1. Steam

Valve has no ARM64 installer package, so the client is bootstrapped from its update CDN:

```sh
sudo apt install curl libarchive-tools
steam/install-steam.sh
```

`install-steam.sh`:
1. downloads the client manifest `steam_client_linuxarm64`. It names the current `steam_linuxarm64` and `bins_linuxarm64_linuxarm64` archives and their SHA-256;
2. downloads and checks both archives (kept in `~/.cache/steam-arm64`) and unpacks them into `~/.local/share/Steam`. The archives use `\` as the path separator, and bsdtar rewrites it to `/`;
3. runs `steam.sh`, which sets up `~/.steam` and then fails because the x86 client is missing. That's expected;
4. runs `steamrtarm64/steam`, which bootstraps the rest of the client and quits;
5. links `~/.steam/sdkarm64` to `~/.local/share/Steam/linuxarm64`. Steam's FEX tool needs it; without it every x86 Linux game exits with status 127.

If Steam is already installed, the script only adds the link. Unpacking the bootstrap again would overwrite files Steam has updated since.

Then start Steam and log in:
```sh
~/.local/share/Steam/steamrtarm64/steam
```

Check: Steam's window opens, and `readlink ~/.steam/sdkarm64` prints `/home/<user>/.local/share/Steam/linuxarm64`.

These steps installed Steam on the CM5 (by hand, client version 1791918634). The script does the same, but hasn't run as a whole yet.

Then install Silksong. Installing it makes Steam install its FEX-Emu tool into `steamapps/common/FEX-Emu`.

## 2. FEX RootFS

FEX's x86-64 Ubuntu 24.04 image supplies the x86 libraries games load (glibc, Mesa, the Vulkan loader). Steam's FEX tool looks for it at `/usr/share/guestos/fex-mesa`. Without it, the game exits about 2 seconds after launch, and running FEX by hand (see above) prints `RootFS path doesn't exist`.

```sh
sudo apt install curl squashfs-tools xxhash
fex/get-rootfs.sh
```

`get-rootfs.sh` downloads the 2026-08-11 image (~500 MB) and checks its XXH3 hash, unpacks it into `~/.local/share/fex-rootfs/Ubuntu_24_04` (~1.4 GB), deletes the download, and links `/usr/share/guestos/fex-mesa` to it. The link is the only part that runs `sudo`, so it asks for your password once. Rerunning the script skips what's already done.

Check: the hand-run FEX command above prints `x86_64`.

Confirmed on the CM5: the RootFS is unpacked and linked, and Silksong starts.

`https://rootfs.fex-emu.gg/RootFS_links.json` lists newer images. To use one, update `url` and `xxh3` in the script.

## 3. FEX thunks and launch wrapper

```sh
sudo apt install clang lld libclang-dev llvm-dev g++-x86-64-linux-gnu cmake ninja-build libwayland-dev
fex/install.sh
```

`install.sh` sets up `~/.local/share/fex-thunks`, then runs `rebuild.sh`, which:
1. clones FEX at the revision Steam's tool ships (`FEX bash` in `steamapps/common/FEX-Emu/VERSIONS.txt`);
2. applies `fex/patches/fex-wayland-listener-version.patch`;
3. builds the Wayland thunk pair;
4. combines it with Steam's own thunk libraries;
5. writes `config/ThunksDB.json`.

On the CM5, this is the setup Silksong runs with: the patched Wayland thunk built for Steam's `FEX-2607-76-g37265b1`.

What the pieces do:
- **`fex-steam`** (the launch wrapper):
  - points FEX at `config/` and `steam-app-config.json`;
  - sets `__GLX_VENDOR_LIBRARY_NAME=mesa`, which Unity needs to find a GLX visual;
  - disables Steam's Fossilize layer, which crashes thunked Vulkan.
- **`steam-app-config.json`:**
  - TSO and Multiblock on;
  - Vulkan and Wayland thunks loaded from this folder, so graphics go straight to the native Mali driver;
  - `VK_INSTANCE_LAYERS` cleared on the native side. Steam sets two Valve layers there that don't exist on ARM64, and re-adds them after launch options run.
- **`config/ThunksDB.json`:** Steam's ThunksDB plus pressure-vessel's `/usr/lib/pressure-vessel/overrides/...` paths. FEX misses those inside the Steam Runtime container, because it checks for a multiarch RootFS relative to the game's directory.
- **The Wayland patch:** FEX's Wayland thunk aborts on event signatures it doesn't know. libwayland 1.26 adds `wl_pointer.warp`, so the patch skips events newer than the version the game bound.
- **`config/Config.json`:** the FEX tool rewrites it from its own template. That's expected.

Untested: whether Silksong needs the Wayland thunk at all. If it doesn't, Steam's stock thunks plus the generated `ThunksDB.json` would be enough, and building FEX could be skipped.

## 4. Silksong

1. Launch options:
   ```
   ~/.local/share/fex-thunks/fex-steam %command% -force-vulkan
   ```
   Unity defaults to GL, which goes through zink. `-force-vulkan` uses the Vulkan thunk directly.
2. Turn on Steam Input for the game (Big Picture: the game → ⚙ → Properties → Controller → Enable Steam Input). The game's input library (InControl) recognises controllers by name and ignores unknown pads; through Steam Input it gets Steam's virtual Xbox pad. That needs `/dev/uinput` access (step 0).

Confirmed on the CM5: Silksong runs, with the gamepad working through Steam Input.

## 5. A Windows Direct3D 9 game (Proton) *(not yet confirmed on the CM5)*

A 32-bit Windows Direct3D 9 game runs through Proton ARM64 rather than FEX. Under Settings → Compatibility (Steam Play), run other titles with **Proton Experimental (ARM64)**. Then put DXVK-Sarek and Microsoft's HLSL compiler into the game's folder (`<game>` below):

```sh
sudo apt install meson ninja-build glslang-tools g++-mingw-w64-i686-posix gcc-mingw-w64-i686-posix cabextract
G="$HOME/.local/share/Steam/steamapps/common/<game>"
games/build-dxvk.sh "$G"
games/get-d3dcompiler.sh "$G"
```

Launch options:
```
WINEDLLOVERRIDES=d3dcompiler_43=n,b WSI_LOW_ADDRESS_MAP=1 %command%
```

- **DXVK-Sarek** replaces Proton's DXVK (3.1), which rejects the Mali because it lacks `fillModeNonSolid`, `multiViewport`, clip/cull distances and `robustBufferAccess2`.
- **`WSI_LOW_ADDRESS_MAP=1`:** a 32-bit Windows game under Wine's WoW64 needs GPU memory mapped below 4 GB. The WSI layer gives it a second mapping there through kbase's low32 alias ioctl. It prints `wsi: low-address mapping uses kbase low32 aliases`, visible with `journalctl -b | grep wsi:`.
- **`d3dcompiler_43=n,b`:** games built with D3DX9 may compile HLSL at startup. Wine's built-in compiler runs as emulated x86: the reference game took about 190 s to start with it, and about 20 s with Microsoft's.

Steam Input was on by default for the reference game.

Check: the game shows its window (the reference game after about 20 s) and logs the `wsi: low-address` line.

Other 32-bit D3D9/D3D11 games: the same DLLs and `WSI_LOW_ADDRESS_MAP=1`. The `d3dcompiler` override only matters for games that compile shaders at startup. If DXVK doesn't work for a game, `PROTON_USE_WINED3D=1 %command%` (GL through zink) is the fallback. 64-bit Windows games would need an ARM64EC build of DXVK, which doesn't exist yet.

Known problems from earlier testing, not yet checked on the CM5:
- **Display hotplug:** plugging or unplugging the DP display while the game runs leaves its picture frozen (a stale frame on DP, a grey window on the internal screen), while the game keeps running and presenting normally. The cause lies between Wine's emulated 1280×720 mode, Xwayland and GNOME, and isn't found yet. Start the game in the display setup you'll play in.
- **D24S8 depth buffer:** the Mali rejects the game's first choice (a 1280×720 D24S8 depth buffer), so it falls back to fullscreen with D16. It plays fine.

## 6. When Steam updates its FEX-Emu tool

Thunk libraries must match the FEX that loads them. When the `FEX bash` revision in `steamapps/common/FEX-Emu/VERSIONS.txt` changes, run `~/.local/share/fex-thunks/rebuild.sh`. If the Wayland patch no longer applies, rebase `mali-steam-thunks` in the `ginkage/FEX` fork onto the new revision, regenerate the patch from it (`git format-patch -1`), and update `fex/patches/` here.

## MangoHud (optional) *(not yet confirmed on the CM5)*

`sudo apt install mangohud`, then copy `device/vk_loader_settings.json` to `~/.local/share/vulkan/loader_settings.d/`. The Mali has no WSI of its own, so present-hooking layers such as MangoHud must sit above the WSI layer to draw anything; this file orders them that way. It names the layer manifests in `/usr/share/vulkan/implicit_layer.d/`: MangoHud's, and the WSI layer's from libmali.

## Status and next steps (2026-10-20)

Working on the CM5: the image from step 0 (built 2026-10-20), with sound and the gamepad working in Steam from first boot, and Silksong from Steam through FEX, with the gamepad (steps 1–4).

Not tested yet, in rough order:
1. **Sound, step 0 "On an existing install":** `sudo alsactl store`, then a reboot, with its checks. The DT routes only `SPK_LP/SPK_LN` (the left channel) to the speaker, so `Front_Right.wav` may be silent there; worth listening for.
2. **`steam/install-steam.sh` as a whole**, on a fresh user or image. Steam on the CM5 was installed by hand with the same commands.
3. **The Direct3D 9 game (step 5)** on the CM5.
4. **MangoHud** on the CM5.

Known gaps:
- **The overlay files are built and fetched by hand** (step 0). No script here builds the three debs or fetches `goodix_cfg_group.bin`.
