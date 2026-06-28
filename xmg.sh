#!/usr/bin/env bash
#
# xmg 主入口
#

set -euo pipefail

# 解析路径
SOURCE="${BASH_SOURCE[0]}"
while [[ -L "${SOURCE}" ]]; do
    DIR="$(cd -P "$(dirname "${SOURCE}")" && pwd)"
    SOURCE="$(readlink "${SOURCE}")"
    [[ "${SOURCE}" != /* ]] && SOURCE="${DIR}/${SOURCE}"
done

BASE_DIR="$(cd -P "$(dirname "${SOURCE}")" && pwd)"

export BASE_DIR

# 加载模块
source "${BASE_DIR}/lib/common.sh"
source "${BASE_DIR}/lib/system.sh"
source "${BASE_DIR}/lib/caddy.sh"
source "${BASE_DIR}/lib/xray.sh"
source "${BASE_DIR}/lib/site.sh"
source "${BASE_DIR}/lib/firewall.sh"
source "${BASE_DIR}/lib/menu.sh"
source "${BASE_DIR}/lib/monitor.sh"   ✅ 新增

main() {
    need_root
    detect_os
    init_dirs

    monitor_loop   ✅ 直接进入监控
}

main "$@"
