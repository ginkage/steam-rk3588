# Rockchip RK3588S octa core 4/8/16GB RAM SoC NVMe USB3 USB-C GbE
BOARD_NAME="RetrOLED CM5"
BOARD_VENDOR="rockchip"
BOARDFAMILY="rockchip-rk3588"
BOARD_MAINTAINER="ginkage"
BOOTCONFIG="retroled-cm5-rk3588s_defconfig"
KERNEL_TARGET="edge"
FULL_DESKTOP="yes"
BOOT_LOGO="desktop"
BOOT_FDT_FILE="rockchip/rk3588s-retroled-cm5.dtb"
BOOT_SCENARIO="spl-blobs"
IMAGE_PARTITION_TABLE="gpt"
DDR_BLOB="rk35/rk3588_ddr_lp4_2112MHz_lp5_2400MHz_v1.16.bin"
BL31_BLOB="rk35/rk3588_bl31_v1.45.elf"
ASOUND_STATE="asound.state.retroled-cm5"

function post_family_tweaks__retroledcm5_naming_audios() {
	display_alert "$BOARD" "Renaming RetrOLED CM5 audios" "info"

	mkdir -p $SDCARD/etc/udev/rules.d/
	echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-hdmi0-sound", ENV{SOUND_DESCRIPTION}="HDMI0 Audio"' > $SDCARD/etc/udev/rules.d/90-naming-audios.rules
	echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-dp0-sound", ENV{SOUND_DESCRIPTION}="DP0 Audio"' >> $SDCARD/etc/udev/rules.d/90-naming-audios.rules
	echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-wm8960-sound", ENV{SOUND_DESCRIPTION}="WM8960 Audio"' >> $SDCARD/etc/udev/rules.d/90-naming-audios.rules

	return 0
}

function post_family_tweaks__retroledcm5_gamepad_mapping() {
	display_alert "$BOARD" "Installing RetrOLED CM5 SDL gamepad mapping" "info"

	mkdir -p "${SDCARD}"/etc/environment.d
	cat > "${SDCARD}"/etc/environment.d/60-retroled-cm5-gamepad.conf << 'EOF'
SDL_GAMECONTROLLERCONFIG="03000000feca00000550000000000000,CM5 Gamepad,platform:Linux,a:b1,b:b0,x:b3,y:b2,back:b5,guide:b14,start:b4,leftstick:b12,rightstick:b13,leftshoulder:b11,rightshoulder:b10,dpup:h0.1,dpdown:h0.4,dpleft:h0.8,dpright:h0.2,leftx:a0,lefty:a1,rightx:a2,righty:a3,lefttrigger:b6,righttrigger:b7"
EOF

	return 0
}
