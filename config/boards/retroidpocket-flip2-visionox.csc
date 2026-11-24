# Qualcomm SM8250 Snapdragon 865 octa core 8/12GB RAM 128GB UFS WiFi6/BT clamshell handheld, Visionox panel
source "${SRC}/config/boards/retroidpocket-flip2.csc"
declare -g BOARDFAMILY="sm8250"         # inherited from retroidpocket-flip2.csc; declared so the board inventory sees it
declare -g KERNEL_TARGET="current,edge" # inherited from retroidpocket-flip2.csc; declared so the board inventory sees it
declare -g BOARD_NAME="Pocket Flip 2 Visionox"
declare -g BOARD_VENDOR="retroid"
declare -g BOARD_MAINTAINER=""
declare -g INTRODUCED="2025"
declare -g MODULES="panel_visionox_vtdr6130_cog"
declare -g BOOT_FDT_FILE="qcom/sm8250-retroidpocket-flip2-visionox.dtb"
