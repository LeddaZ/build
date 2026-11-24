#!/bin/sh
# Back up, flash or restore the ABL partitions (abl_a, abl_b) with OpenABL.
# Run as root on the device, from Android or Linux: sh openabl.sh backup|flash|restore
set -e

dir=$(cd "$(dirname "$0")" && pwd)

part() {
	for p in "/dev/block/by-name/$1" "/dev/disk/by-partlabel/$1"; do
		if [ -e "$p" ]; then
			echo "$p"
			return 0
		fi
	done
	echo "Partition $1 not found." >&2
	return 1
}

need_backup() {
	for s in a b; do
		if [ ! -s "$dir/abl_$s.img" ]; then
			echo "$dir/abl_$s.img not found. Run: sh $0 backup" >&2
			exit 1
		fi
	done
}

case "$1" in
	backup)
		for s in a b; do
			if [ -e "$dir/abl_$s.img" ]; then
				echo "$dir/abl_$s.img exists. Not overwritten." >&2
				exit 1
			fi
		done
		for s in a b; do
			p=$(part "abl_$s")
			dd if="$p" of="$dir/abl_$s.img" bs=1M
		done
		sync
		echo "Backup done. Copy abl_a.img and abl_b.img to a safe place."
		;;
	flash)
		need_backup
		set -- "$dir"/abl_signed-*.elf
		if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
			echo "Expected one abl_signed-*.elf in $dir." >&2
			exit 1
		fi
		elf=$1
		(cd "$dir" && sha256sum -c "$(basename "$elf").sha256")
		size=$(wc -c < "$elf")
		want=$(sha256sum < "$elf" | cut -d ' ' -f 1)
		for s in a b; do
			p=$(part "abl_$s")
			dd if="$elf" of="$p" bs=1M
			sync
			got=$(head -c "$size" "$p" | sha256sum | cut -d ' ' -f 1)
			if [ "$got" != "$want" ]; then
				echo "$p does not match $elf after the write. Do not restart. Run: sh $dir/openabl.sh restore" >&2
				exit 1
			fi
		done
		echo "OpenABL is on abl_a and abl_b."
		;;
	restore)
		need_backup
		for s in a b; do
			p=$(part "abl_$s")
			dd if="$dir/abl_$s.img" of="$p" bs=1M
		done
		sync
		echo "The backup is on abl_a and abl_b."
		;;
	*)
		echo "Usage: sh $0 backup|flash|restore" >&2
		exit 2
		;;
esac
