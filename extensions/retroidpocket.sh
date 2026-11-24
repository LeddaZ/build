#!/usr/bin/env bash
# @description Retroid Pocket SM8250 userspace in the bsp-cli package: the ALSA UCM config, the joystick LED brightness control and color save, the KWin on-screen keyboard setting, and the schedutil CPU governor default for existing installs. A package update then delivers changes without a new image.

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
		codecs/qcom-lpass/tx-macro/SoundwireMic1EnableSeq.conf
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
		# Point the includes into the private tree.
		sed -i -E 's|(File[[:space:]]+")/|\1/Retroid/|' "${ucm}/Retroid/${file}"
	done
	rm -rf "${extract}"

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
