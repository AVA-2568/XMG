#!/usr/bin/env bash
#
# xmg.sh - 轻量级 VPS 脚本管理器主入口
#

set -o errexit
set -o nounset
set -o pipefail

XMG_VERSION="0.1.0"

# 解析真实路径，兼容 /usr/local/bin/xmg 软链接
SOURCE="${BASH_SOURCE[0]}"
while [[ -L "${SOURCE}" ]]; do
    DIR="$(cd -P "$(dirname "${SOURCE}")" >/dev/null 2>&1 && pwd)"
    SOURCE="$(readlink "${SOURCE}")"
    [[ "${SOURCE}" != /* ]] && SOURCE="${DIR}/${SOURCE}"
done

BASE_DIR="$(cd -P "$(dirname "${SOURCE}")" >/dev/null 2>&1 && pwd)"

export XMG_VERSION
export BASE_DIR

source "${BASE_DIR}/lib/common.sh"
source "${BASE_DIR}/lib/system.sh"
source "${BASE_DIR}/lib/caddy.sh"
source "${BASE_DIR}/lib/xray.sh"
source "${BASE_DIR}/lib/site.sh"
source "${BASE_DIR}/lib/firewall.sh"
source "${BASE_DIR}/lib/menu.sh"

main() {
    need_root
    detect_os
    init_dirs
    main_menu
}

main "$@"
