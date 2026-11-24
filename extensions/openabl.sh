#!/usr/bin/env bash
# @description Put OpenABL (https://github.com/OpenHandheldCollective/OpenABL) and its flash script in the `openabl` folder of the EFI partition. The user flashes it to the abl partitions by hand. Enables `grub-with-dtb`. Requires `OPENABL_CHIPSET`, for example `SM8250`. The EFI partition gets the GPT type "Microsoft basic data", so that Android mounts it.

# OpenABL gives Linux the Android DTB by default. GRUB must load the board DTB: grub-with-dtb requires BOOT_FDT_FILE.
enable_extension "grub-with-dtb"

function extension_prepare_config__openabl() {
	declare -g OPENABL_VERSION="${OPENABL_VERSION:-1.2}"
	declare -g OPENABL_SHA256="${OPENABL_SHA256:-28cb97d1b387f28ddba28ed57fdc7d8b1c2ac2cdcd26af9c672620d41abddd4f}" # openabl-v1.2.tar.gz
	declare -g OPENABL_CHIPSET="${OPENABL_CHIPSET:-}"
	[[ -n "${OPENABL_CHIPSET}" ]] || exit_with_error "OPENABL_CHIPSET is not set" "${EXTENSION}"
}

# Android mounts only GPT partitions of type "Microsoft basic data". OpenABL boots from it too, as ROCKNIX does.
function post_create_partitions__openabl_efi_basic_data() {
	declare esp_type="C12A7328-F81F-11D2-BA4B-00A0C93EC93B" basic_data_type="EBD0A0A2-B9E5-4433-87C0-68B6B72699C7"
	[[ "${IMAGE_PARTITION_TABLE}" == "gpt" ]] || exit_with_error "OpenABL needs a GPT image" "IMAGE_PARTITION_TABLE=${IMAGE_PARTITION_TABLE}"
	[[ -n "${uefipart}" ]] || exit_with_error "OpenABL needs the EFI partition of the grub extension" "no uefipart"
	declare current_type
	current_type="$(sfdisk --part-type "${SDCARD}.raw" "${uefipart}")"
	[[ "${current_type^^}" == "${esp_type}" ]] || exit_with_error "Partition ${uefipart} is not the EFI partition" "type ${current_type}"
	display_alert "Setting EFI partition type" "partition ${uefipart}: Microsoft basic data, for Android" "info"
	run_host_command_logged sfdisk --part-type "${SDCARD}.raw" "${uefipart}" "${basic_data_type}"
}

function pre_umount_final_image__install_openabl() {
	declare efi_dir="${MOUNT}${UEFI_MOUNT_POINT}"
	if [[ -z "${UEFI_MOUNT_POINT}" || ! -d "${efi_dir}" ]]; then
		exit_with_error "OpenABL needs the EFI partition of the grub extension" "UEFI_MOUNT_POINT='${UEFI_MOUNT_POINT}'"
	fi

	declare tarball="openabl-v${OPENABL_VERSION}.tar.gz"
	declare cache_dir="${SRC}/cache/openabl"
	declare url="https://github.com/OpenHandheldCollective/OpenABL/releases/download/v${OPENABL_VERSION}/${tarball}"
	mkdir -p "${cache_dir}"
	if ! printf '%s  %s\n' "${OPENABL_SHA256}" "${cache_dir}/${tarball}" | sha256sum --check --quiet - 2> /dev/null; then
		display_alert "Downloading OpenABL" "${url}" "info"
		run_host_command_logged curl --fail --silent --show-error --location --retry 3 --connect-timeout 15 --max-time 300 \
			-o "${cache_dir}/${tarball}.tmp" "${url}"
		printf '%s  %s\n' "${OPENABL_SHA256}" "${cache_dir}/${tarball}.tmp" | sha256sum --check --quiet - ||
			exit_with_error "OpenABL download does not match OPENABL_SHA256" "${tarball}"
		mv "${cache_dir}/${tarball}.tmp" "${cache_dir}/${tarball}"
	fi

	declare top="openabl-v${OPENABL_VERSION}" dest="${efi_dir}/openabl" extract
	display_alert "Adding OpenABL to the EFI partition" "v${OPENABL_VERSION} ${OPENABL_CHIPSET}" "info"
	# FAT has no file owners: extract to a temporary directory, then copy without ownership.
	extract="$(mktemp -d)" # subject to TMPDIR/WORKDIR
	run_host_command_logged tar -xzf "${cache_dir}/${tarball}" -C "${extract}" \
		"${top}/${OPENABL_CHIPSET}" "${top}/LICENSE" "${top}/LICENSES.md" "${top}/LICENSES"
	(cd "${extract}/${top}/${OPENABL_CHIPSET}" && sha256sum --check --quiet "abl_signed-${OPENABL_CHIPSET}.elf.sha256") ||
		exit_with_error "OpenABL image does not match its .sha256" "${OPENABL_CHIPSET}"
	mkdir -p "${dest}"
	run_host_command_logged cp -r "${extract}/${top}/${OPENABL_CHIPSET}/." "${extract}/${top}/LICENSE" "${extract}/${top}/LICENSES.md" "${extract}/${top}/LICENSES" \
		"${SRC}/packages/bsp/openabl/openabl.sh" "${SRC}/packages/bsp/openabl/README.txt" "${dest}/"
	rm -rf "${extract}"
}
