#!/usr/bin/env bash
# @description Retroid Pocket SM8250 userspace in the bsp-cli package: the ALSA UCM config, the joystick LED brightness control and color save, the KWin on-screen keyboard setting, the default KDE scale, the SDL controller mapping, the joystick calibration tool, the PipeWire quantum, a fixed Wi-Fi MAC, the QRTR and PD mapper modules in the initrd, and the schedutil CPU governor default for existing installs. A package update then delivers changes without a new image. KDE images also get a Wayland login screen with the on-screen keyboard.

function extension_prepare_config__retroidpocket() {
	# RetroidPocket/alsa-ucm-conf, branch rp/v1.2.13
	declare -g RETROIDPOCKET_UCM_COMMIT="${RETROIDPOCKET_UCM_COMMIT:-512385df94a0ebc6fee2a967b837c30e007e010f}"
	declare -g RETROIDPOCKET_UCM_SHA256="${RETROIDPOCKET_UCM_SHA256:-020c9e7c47236d0276e10ad849c1644df39e0bfaa3148675209e8c64fd1268ef}"
}

# ucm2/ucm.conf from alsa-ucm-conf loads the Retroid config. Minimal images lack the package.
function post_family_config__retroidpocket_ucm_package() {
	add_packages_to_image "alsa-ucm-conf"
}

# The UCM files go in a private tree, /usr/share/alsa/ucm2/Retroid.
# They do not overwrite alsa-ucm-conf files, and they do not depend on its version.
function post_family_tweaks_bsp__retroidpocket_ucm() {
	declare tarball="alsa-ucm-conf-${RETROIDPOCKET_UCM_COMMIT}.tar.gz"
	declare cache_dir="${SRC}/cache/retroidpocket"
	declare url="https://github.com/RetroidPocket/alsa-ucm-conf/archive/${RETROIDPOCKET_UCM_COMMIT}.tar.gz"
	mkdir -p "${cache_dir}"
	if ! printf '%s  %s\n' "${RETROIDPOCKET_UCM_SHA256}" "${cache_dir}/${tarball}" | sha256sum --check --quiet - 2> /dev/null; then
		display_alert "Downloading Retroid Pocket UCM config" "${url}" "info"
		run_host_command_logged curl --fail --silent --show-error --location --retry 3 --connect-timeout 15 --max-time 300 \
			-o "${cache_dir}/${tarball}.tmp" "${url}"
		printf '%s  %s\n' "${RETROIDPOCKET_UCM_SHA256}" "${cache_dir}/${tarball}.tmp" | sha256sum --check --quiet - ||
			exit_with_error "Retroid Pocket UCM download does not match RETROIDPOCKET_UCM_SHA256" "${tarball}"
		mv "${cache_dir}/${tarball}.tmp" "${cache_dir}/${tarball}"
	fi

	display_alert "Adding to bsp-cli" "${BOARD}: Retroid Pocket UCM config" "info"
	# shellcheck disable=SC2154 # $destination is the target dir of the bsp building function
	declare extract ucm="${destination}/usr/share/alsa/ucm2"
	extract="$(mktemp -d)" # subject to TMPDIR/WORKDIR
	run_host_command_logged tar -xzf "${cache_dir}/${tarball}" -C "${extract}" --strip-components=1

	# The files that Qualcomm/sm8250/RetroidPocket.conf includes, directly or through other files.
	declare -a files=(
		Qualcomm/sm8250/RetroidPocket.conf
		Qualcomm/sm8250/HiFi-RP.conf
		codecs/qcom-lpass/rx-macro/init.conf
		codecs/qcom-lpass/rx-macro/HeadphoneEnableSeq.conf
		codecs/qcom-lpass/rx-macro/HeadphoneDisableSeq.conf
		codecs/qcom-lpass/tx-macro/HeadphoneMicEnableSeq.conf
		codecs/qcom-lpass/tx-macro/HeadphoneMicDisableSeq.conf
		codecs/qcom-lpass/wsa-macro/SpeakerEnableSeq.conf
		codecs/qcom-lpass/wsa-macro/SpeakerDisableSeq.conf
		codecs/wcd938x/init.conf
		codecs/wcd938x/HeadphoneEnableSeq.conf
		codecs/wcd938x/HeadphoneDisableSeq.conf
		codecs/wcd938x/HeadphoneMicEnableSeq.conf
		codecs/wcd938x/HeadphoneMicDisableSeq.conf
		codecs/wsa881x/init.conf
		codecs/wsa881x/DefaultEnableSeq.conf
		codecs/wsa881x/SpeakerEnableSeq.conf
		codecs/wsa881x/SpeakerDisableSeq.conf
		lib/card-init.conf
		lib/ctl-remap.conf
	)
	declare file
	for file in "${files[@]}"; do
		install -Dm644 "${extract}/ucm2/${file}" "${ucm}/Retroid/${file}"
	done
	rm -rf "${extract}"

	# Armbian changes replace files of the tarball: packages/bsp/retroidpocket/ucm.
	declare overlay="${SRC}/packages/bsp/retroidpocket/ucm"
	while IFS= read -r file; do
		install -Dm644 "${overlay}/${file}" "${ucm}/Retroid/${file}"
	done < <(cd "${overlay}" && find . -type f -name '*.conf' -printf '%P\n')

	# Point the includes into the private tree.
	find "${ucm}/Retroid" -type f -name '*.conf' -exec sed -i -E 's|(File[[:space:]]+")/|\1/Retroid/|' {} +

	# The card long name comes from the SMBIOS data of the boot loader (U-Boot or OpenABL).
	# Link each known name to the Retroid Pocket config, as ROCKNIX does.
	mkdir -p "${ucm}/conf.d/sm8250"
	declare name
	for name in RetroidPocket \
		retroidpocket-RetroidPocket5 retroidpocket-RetroidPocketFlip2 retroidpocket-RetroidPocketMini retroidpocket-RetroidPocketMiniV2 \
		retroidpocket-RetroidPocket5- retroidpocket-RetroidPocketFlip2- retroidpocket-RetroidPocketMini- retroidpocket-RetroidPocketMiniV2- \
		retroid-RetroidPocket5- retroid-RetroidPocketMini-; do
		ln -sfn ../../Retroid/Qualcomm/sm8250/RetroidPocket.conf "${ucm}/conf.d/sm8250/${name}.conf"
	done
}

# Joystick LEDs: a brightness control for the desktop, and the colors saved across reboots.
function post_family_tweaks_bsp__retroidpocket_leds() {
	display_alert "Adding to bsp-cli" "${BOARD}: joystick LED brightness control and color save" "info"
	install -Dm755 "${SRC}/packages/bsp/retroidpocket/retroid-leds" "${destination}/usr/lib/retroid-leds/retroid-leds"
	install -Dm644 "${SRC}/packages/bsp/retroidpocket/retroid-leds.service" "${destination}/usr/lib/systemd/system/retroid-leds.service"
	postinst_functions+=(retroidpocket_bsp_cli_postinst_leds)
}

# Copied inline into the bsp-cli postinst, so no return or local.
# Enable the service. On a running system, restart it: the stop saves the colors.
function retroidpocket_bsp_cli_postinst_leds() {
	if [[ "$1" == "configure" ]]; then
		systemctl --no-reload enable retroid-leds.service > /dev/null 2>&1 || true
		if [[ -d /run/systemd/system ]]; then
			systemctl daemon-reload
			systemctl restart retroid-leds.service || true
		fi
	fi
}

# On-screen keyboard for the touchscreen. plasma-keyboard is in Plasma 6.4 and later: resolute.
function post_family_config__retroidpocket_onscreen_keyboard() {
	[[ "${BUILD_DESKTOP}" == "yes" && "${DESKTOP_ENVIRONMENT}" == "kde-plasma" && "${RELEASE}" == "resolute" ]] || return 0
	display_alert "Adding on-screen keyboard for ${BOARD}" "plasma-keyboard" "info"
	add_packages_to_image "plasma-keyboard"
}

# KWin starts plasma-keyboard as input method. Without the package, KWin starts no input method.
function post_family_tweaks_bsp__retroidpocket_onscreen_keyboard() {
	display_alert "Adding to bsp-cli" "${BOARD}: KWin input method plasma-keyboard" "info"
	add_file_from_stdin_to_bsp_destination "/etc/xdg/kwinrc" <<- 'KWINRC'
		[Wayland]
		InputMethod=/usr/share/applications/org.kde.plasma.keyboard.desktop
	KWINRC
}

# The login screen runs on KWin Wayland, so its keyboard button shows plasma-keyboard.
# The file name sorts after armbian.conf (armbian-firstlogin), which sets InputMethod=none.
# Not in bsp-cli: other desktops with SDDM have no KWin.
function pre_customize_image__retroidpocket_sddm_keyboard() {
	[[ -x "${SDCARD}/usr/bin/kwin_wayland" && -x "${SDCARD}/usr/bin/sddm" && -f "${SDCARD}/usr/share/applications/org.kde.plasma.keyboard.desktop" ]] || return 0
	display_alert "Configuring SDDM for ${BOARD}" "Wayland login screen with plasma-keyboard" "info"
	mkdir -p "${SDCARD}/etc/sddm.conf.d"
	cat <<- 'SDDM_CONF' > "${SDCARD}/etc/sddm.conf.d/retroidpocket-keyboard.conf"
		[General]
		DisplayServer=wayland
		GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell
		InputMethod=

		[Wayland]
		CompositorCommand=kwin_wayland --drm --no-lockscreen --no-global-shortcuts --locale1 --inputmethod plasma-keyboard
	SDDM_CONF
}

# Default KDE scale of the built-in display. The board config sets RETROIDPOCKET_KDE_SCALE; empty keeps the KDE default.
# The autostart entry sets the scale once per user, at the first Plasma login.
function post_family_tweaks_bsp__retroidpocket_kde_scale() {
	[[ -n "${RETROIDPOCKET_KDE_SCALE:-}" ]] || return 0
	display_alert "Adding to bsp-cli" "${BOARD}: KDE scale ${RETROIDPOCKET_KDE_SCALE}" "info"
	install -Dm755 "${SRC}/packages/bsp/retroidpocket/retroid-kde-scale" "${destination}/usr/bin/retroid-kde-scale"
	add_file_from_stdin_to_bsp_destination "/etc/xdg/autostart/retroid-kde-scale.desktop" <<- AUTOSTART
		[Desktop Entry]
		Type=Application
		Name=Retroid Pocket display scale
		Exec=/usr/bin/retroid-kde-scale ${RETROIDPOCKET_KDE_SCALE}
		OnlyShowIn=KDE;
		NoDisplay=true
		X-KDE-autostart-phase=2
	AUTOSTART
}

# The login screen runs KWin as user sddm. Give it the same scale. KWin adds the other output settings.
function pre_customize_image__retroidpocket_sddm_scale() {
	[[ -n "${RETROIDPOCKET_KDE_SCALE:-}" && -x "${SDCARD}/usr/bin/kwin_wayland" && -x "${SDCARD}/usr/bin/sddm" ]] || return 0
	display_alert "Configuring SDDM for ${BOARD}" "login screen scale ${RETROIDPOCKET_KDE_SCALE}" "info"
	mkdir -p "${SDCARD}/var/lib/sddm/.config"
	cat <<- KWIN_OUTPUTS > "${SDCARD}/var/lib/sddm/.config/kwinoutputconfig.json"
		[
		    {
		        "data": [
		            {
		                "connectorName": "DSI-1",
		                "scale": ${RETROIDPOCKET_KDE_SCALE}
		            }
		        ],
		        "name": "outputs"
		    }
		]
	KWIN_OUTPUTS
	chroot_sdcard chown -R sddm:sddm /var/lib/sddm/.config
}

# SDL mapping for the built-in controller. SDL has no Linux entry for it.
# The face buttons use the Nintendo layout: A right, B bottom, X top, Y left.
# systemd sets environment.d variables in every desktop session.
function post_family_tweaks_bsp__retroidpocket_gamepad_mapping() {
	display_alert "Adding to bsp-cli" "${BOARD}: SDL controller mapping" "info"
	add_file_from_stdin_to_bsp_destination "/etc/environment.d/60-retroid-gamepad.conf" <<- 'GAMEPAD'
		SDL_GAMECONTROLLERCONFIG=03000000202000000130000001000000,Retroid Pocket Controller,platform:Linux,a:b1,b:b0,x:b2,y:b3,back:b6,start:b7,guide:b8,leftshoulder:b4,rightshoulder:b5,leftstick:b9,rightstick:b10,dpup:b11,dpdown:b12,dpleft:b13,dpright:b14,leftx:a0,lefty:a1,rightx:a3,righty:a4,lefttrigger:a7,righttrigger:a6,
	GAMEPAD
}

# Stick calibration: retroid-joystick-calibrate writes a udev hwdb override for the controller axes.
function post_family_tweaks_bsp__retroidpocket_joystick_calibrate() {
	display_alert "Adding to bsp-cli" "${BOARD}: joystick calibration tool" "info"
	install -Dm755 "${SRC}/packages/bsp/retroidpocket/retroid-joystick-calibrate" "${destination}/usr/bin/retroid-joystick-calibrate"
}

# The audio goes through the ADSP. With a PipeWire quantum of 256 (5.3 ms), games cause xruns.
# Use 1024 (21 ms) while a node of the sound card is active. WirePlumber 0.4 (noble) ignores this file.
function post_family_tweaks_bsp__retroidpocket_audio_quantum() {
	display_alert "Adding to bsp-cli" "${BOARD}: PipeWire quantum for the sound card" "info"
	add_file_from_stdin_to_bsp_destination "/etc/wireplumber/wireplumber.conf.d/60-retroid-audio.conf" <<- 'WIREPLUMBER'
		monitor.alsa.rules = [
		  {
		    matches = [
		      { node.name = "~alsa_output.platform-sound.*" }
		      { node.name = "~alsa_input.platform-sound.*" }
		    ]
		    actions = {
		      update-props = {
		        node.force-quantum = 1024
		      }
		    }
		  }
		]
	WIREPLUMBER
}

# The initrd boots the ADSP. The ADSP looks up its audio domain over QRTR at boot.
# Without qrtr_smd and qcom_pd_mapper in the initrd, the lookup fails and the sound card does not register.
# udev in the initrd loads the modules when their devices appear.
function post_family_tweaks_bsp__retroidpocket_dsp_modules_in_initrd() {
	display_alert "Adding to bsp-cli" "${BOARD}: QRTR and PD mapper modules in initrd" "info"
	declare file_added_to_bsp_destination
	add_file_from_stdin_to_bsp_destination "/etc/initramfs-tools/hooks/retroidpocket-dsp" <<- 'DSP_HOOK'
		#!/bin/sh
		[ "$1" = "prereqs" ] && exit 0
		. /usr/share/initramfs-tools/hook-functions
		manual_add_modules qrtr qrtr_smd qcom_pd_mapper qcom_sysmon
	DSP_HOOK
	run_host_command_logged chmod -v +x "${file_added_to_bsp_destination}"
}

# The QCA6390 Wi-Fi (ath11k) reports a firmware default MAC, 00:03:7f:12:xx:xx, not a unit MAC.
# Set a fixed, locally administered MAC from the SoC serial. Fall back to /etc/machine-id.
function post_family_tweaks_bsp__retroidpocket_wifi_mac() {
	display_alert "Adding to bsp-cli" "${BOARD}: fixed Wi-Fi MAC from the SoC serial" "info"
	declare file_added_to_bsp_destination
	add_file_from_stdin_to_bsp_destination "/usr/lib/armbian/retroidpocket-wifi-mac" <<- 'WIFI_MAC_SCRIPT'
		#!/bin/bash
		# udev gives the interface name.
		set -u
		ifname="${1:?interface name}"
		id="$(cat /sys/devices/soc0/serial_number 2> /dev/null)"
		[[ -n ${id} ]] || id="$(< /etc/machine-id)"
		h="$(printf 'wlan:%s' "${id}" | sha256sum | cut -c1-10)"
		exec /usr/sbin/ip link set dev "${ifname}" address "02:${h:0:2}:${h:2:2}:${h:4:2}:${h:6:2}:${h:8:2}"
	WIFI_MAC_SCRIPT
	run_host_command_logged chmod -v +x "${file_added_to_bsp_destination}"

	# Only the internal Wi-Fi. udev runs the script before NetworkManager takes the link.
	add_file_from_stdin_to_bsp_destination "/etc/udev/rules.d/90-retroidpocket-wifi-mac.rules" <<- 'WIFI_MAC_RULE'
		ACTION=="add", SUBSYSTEM=="net", KERNELS=="0000:01:00.0", DRIVERS=="ath11k_pci", RUN+="/usr/lib/armbian/retroidpocket-wifi-mac $name"
	WIFI_MAC_RULE
}

function post_family_tweaks_bsp__retroidpocket_governor() {
	postinst_functions+=(retroidpocket_bsp_cli_postinst_governor)
}

# Copied inline into the bsp-cli postinst, so no return or local.
# Existing installs have an empty GOVERNOR: the kernel default (conservative) applies. Set schedutil.
# A governor that the user set stays.
function retroidpocket_bsp_cli_postinst_governor() {
	if [[ "$1" == "configure" && -f /etc/default/cpufrequtils ]] && grep -q '^GOVERNOR=$' /etc/default/cpufrequtils; then
		sed -i 's/^GOVERNOR=$/GOVERNOR=schedutil/' /etc/default/cpufrequtils
	fi
}
