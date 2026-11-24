OpenABL
=======

OpenABL replaces the Qualcomm ABL in the abl_a and abl_b partitions.
It boots this SD card through EFI\BOOT\BOOTAA64.EFI (GRUB).
Project and source: https://github.com/OpenHandheldCollective/OpenABL

WARNING: a bad ABL stops the device from booting.
Recovery then needs Qualcomm EDL mode (9008).
Keep a backup of the stock ABL outside this SD card.

Flash from Android (root):
1. Copy this openabl folder to the device.
2. Run: sh openabl.sh backup
3. Copy abl_a.img and abl_b.img to a safe place.
4. Run: sh openabl.sh flash

Flash from a PC with fastboot (unlocked bootloader):
1. Run: fastboot flash abl_a abl_signed-<CHIPSET>.elf
2. Run: fastboot flash abl_b abl_signed-<CHIPSET>.elf
fastboot cannot read the stock ABL. Back it up from Android first.

Boot Armbian:
1. Hold Volume Down at power-on. The OpenABL menu opens.
2. Set "Boot mode" to Linux.
3. Select "Start".

Restore the stock ABL:
- Run: sh openabl.sh restore
- The script reads abl_a.img and abl_b.img from its own folder.

openabl.sh also runs as root on Armbian. It finds the partitions in /dev/disk/by-partlabel.
