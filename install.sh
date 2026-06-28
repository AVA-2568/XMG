#!/usr/bin/env bash
#
# install.sh - XMG 在线安装器
#

set -o errexit
set -o nounset
set -o pipefail

GITHUB_REPO="${GITHUB_REPO:-https://github.com/AVA-2568/xmg.git}"
INSTALL_DIR="/opt/xmg"
BIN_PATH="/usr/local/bin/xmg"

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
RESET="\033[0m"

info() {
    echo -e "${BLUE}[INFO]${RESET} $*"
}

ok() {
    echo -e "${GREEN}[OK]${RESET} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${RESET} $*"
}

err() {
    echo -e "${RED}[ERROR]${RESET} $*" >&2
}

need_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        err "请使用 root 用户执行安装"
        exit 1
    fi
}

check_os() {
    if [[ ! -f /etc/os-release ]]; then
        err "无法识别系统"
        exit 1
    fi

    # shellcheck disable=SC1091
    . /etc/os-release

    case "${ID}" in
        debian|ubuntu)
            ok "检测到系统：${PRETTY_NAME}"
            ;;
        *)
            warn "当前系统为：${PRETTY_NAME}，主要适配 Debian / Ubuntu"
            ;;
    esac
}

install_deps() {
    info "安装安装器依赖..."

    apt-get update
    apt-get install -y \
        git \
        curl \
        ca-certificates
}

install_xmg() {
    info "安装 XMG 到 ${INSTALL_DIR}"

    if [[ -d "${INSTALL_DIR}/.git" ]]; then
        info "检测到已有安装，执行更新..."
        git -C "${INSTALL_DIR}" pull --ff-only
    else
        rm -rf "${INSTALL_DIR}"
        git clone --depth=1 "${GITHUB_REPO}" "${INSTALL_DIR}"
    fi

    chmod +x "${INSTALL_DIR}/xmg.sh"
    chmod +x "${INSTALL_DIR}/install.sh" 2>/dev/null || true
    chmod +x "${INSTALL_DIR}/uninstall.sh" 2>/dev/null || true

    find "${INSTALL_DIR}/lib" -type f -name "*.sh" -exec chmod 644 {} \;

    ln -sf "${INSTALL_DIR}/xmg.sh" "${BIN_PATH}"

    mkdir -p /etc/xmg/backup
    mkdir -p /var/www/mask-site

    ok "XMG 安装完成"
    echo
    echo "运行命令："
    echo "  xmg"
}

main() {
    need_root
    check_os
    install_deps
    install_xmg
}

main "$@"
