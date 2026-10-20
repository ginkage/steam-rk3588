# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A reproducible recipe for running x86-64 Linux games from the ARM64 Steam client through Steam's FEX-Emu compatibility tool, on an RK3588 Mali-G610 using kbase. The reference games are Hollow Knight: Silksong (FEX) and a Windows Direct3D 9 game (32-bit, through Proton ARM64). `README.md` is the main deliverable: numbered steps, each a command or script followed by a check. It holds only what exists nowhere else. Everything else is downloaded or built by scripts, and the repo is not a backup.

The machine this runs on is a **RetrOLED CM5** (Radxa CM5, RK3588S), running Armbian trunk `resolute` (Ubuntu 26.04) on the mainline `edge-rockchip64` 7.x kernel. Its GPU stack comes from packages: `mali-valhall-g610-dkms` (`ginkage/mali-dkms`: kbase with low32 aliases, plus the `system-uncached` heap and other kernel patches in `/usr/src/mali-valhall-g610-g29p1/kernel-patches`), libmali with the bundled WSI layer, and Xwayland `+cixmali2`. The image is built from `armbian/build` with `armbian/tree/` copied in (README step 0). Steam is in `~/.local/share/Steam`.

The Direct3D 9 game (Proton, `games/`) hasn't been run on the CM5 yet, but the WSI low-address mapping and kbase low32 aliases it relies on are there too. It's kept for reference but isn't the current focus. Don't name the game anywhere in the repo.

## How to work here

- **Ask before changing the system.** That covers downloads, installs, `sudo`, writing outside the repo, and changing Steam's files. Turn each action into an exact command or a script in the repo, give it to the user to run (with `! <command>`), and say how to check the result. Read-only inspection (logs, `dpkg`, `/proc`, Steam's files) is fine without asking.
- Add a step to the README only once it has worked on this machine. The Direct3D 9 game (step 5) and MangoHud are the exceptions: they stay marked *(not yet confirmed on the CM5)* until they've run here.
- Steam's logs only show that processes exited. To find why a game failed, read `/tmp/fex-compat-tool-<pid>.log`, or run FEX by hand with `steamapps/compatdata/<appid>/fex-emu/` (the command is in the README's "When a game won't start").

## Layout

- `armbian/tree/` holds the CM5's image build inputs at their `armbian/build` paths, and is copied over a checkout as is (README step 0). The image is built with `BRANCH=edge`.
  - `config/boards/retroled-cm5.csc` is the CM5's board file (the user's own). Make CM5 system changes there: `ASOUND_STATE="asound.state.retroled-cm5"` (the blob is in `packages/blobs/asound.state/`), and `post_family_tweaks__retroledcm5_*` hooks with heredocs. Output switching (speaker, headphones, DP) is left to the drivers: no UCM profiles. To test a hook, source the board file with `SDCARD=<scratch root>` and a stub `display_alert`, then call the function.
  - `userpatches/customize-image.sh` (also the user's own) installs packages and the debs from `userpatches/overlay/`; for `resolute` that's `InstallRetroLiteResolute`. Packages (e.g. `steam-devices`) go there, not in the board file. Steam itself is installed per user by `steam/install-steam.sh`, not by the image.
  - `userpatches/kernel/archive/rockchip64-7.3/` holds the kernel patches and, in `dt/`, the CM5's device tree. The directory follows the edge kernel's version (Armbian's `KERNELPATCHDIR`), so it's renamed when the kernel moves on. The four `mali-dkms` patches in it are copies of that repo's `kernel-patches/`.
  - `userpatches/u-boot/legacy/u-boot-radxa-rk35xx/` holds the CM5's U-Boot defconfig and device tree.
- README's "Status and next steps" section lists what's untested and the known gaps. Keep it current.
- `steam/install-steam.sh` bootstraps the ARM64 client from `client-update.steamstatic.com`. It parses `file` and `sha2` for each package out of the `steam_client_linuxarm64` VDF manifest, and leaves an existing install alone apart from the `~/.steam/sdkarm64` link.
- `fex/`:
  - `get-rootfs.sh` fetches the x86 RootFS. It pins the URL and the XXH3 hash from `RootFS_links.json`, unpacks into `<name>.part` and renames when done, and uses `sudo` only for the `/usr/share/guestos/fex-mesa` link.
  - `install.sh` copies `fex-steam`, `rebuild.sh` and `patches/` into `~/.local/share/fex-thunks` (or `$DEST`), renders `steam-app-config.json.in` (`@FEX_THUNKS@`), then runs `rebuild.sh`.
  - `rebuild.sh` reads the `FEX bash` revision from Steam's `steamapps/common/FEX-Emu/VERSIONS.txt`, builds the patched Wayland thunks at that revision, overlays them onto Steam's stock thunks, and generates `config/ThunksDB.json` with the pressure-vessel override paths.
- Steam's FEX tool (`steamapps/common/FEX-Emu/fex-compat-tool`, a Python script) regenerates `compatdata/<appid>/fex-emu/Config.json` from `ConfigTemplate.json` on every launch. It respects a pre-set `FEX_APP_CONFIG`, which is how `fex-steam` injects its config.
- `fex/patches/fex-wayland-listener-version.patch` is a `git format-patch` of `992ecf7` on `ginkage/FEX` branch `mali-steam-thunks`. Regenerate it from the fork; never edit it by hand.

## Conventions

- Scripts are POSIX `#!/bin/sh -e`, tab-indented. Each opens with a header comment giving its purpose (why it's needed), usage and required packages. Paths can be overridden through env vars (`DEST`, `FEXTOOL`, `WORK`, `SRC`, `BUILD`, `CACHE`). Locate sibling files with `here=$(dirname "$(readlink -f "$0")")`. Make scripts safe to rerun.
- Pin downloads (URL plus hash, tag or commit), and record the exact versions in use.
- Commit messages are short and imperative. README-only commits use a `README: ` prefix. Don't commit until the user asks.
- Never commit secrets from the device.
- Check edited scripts with `sh -n`.
