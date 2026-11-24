# Qualcomm SM8250 Snapdragon 865 octa core 6GB RAM 128GB UFS WiFi6/BT handheld
source "${SRC}/config/boards/retroidpocket-rpmini.csc"
declare -g BOARDFAMILY="sm8250"         # inherited from retroidpocket-rpmini.csc; declared so the board inventory sees it
declare -g KERNEL_TARGET="current,edge" # inherited from retroidpocket-rpmini.csc; declared so the board inventory sees it
declare -g BOARD_NAME="Pocket RPMini V2"
declare -g BOARD_VENDOR="retroid"
declare -g BOARD_MAINTAINER=""
declare -g INTRODUCED="2025"
declare -g BOOT_FDT_FILE="qcom/sm8250-retroidpocket-rpminiv2.dtb"
