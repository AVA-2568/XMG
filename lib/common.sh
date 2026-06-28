#!/usr/bin/env bash
#
# common.sh - 公共变量和函数
#

PANEL_DIR="/etc/xmg"
BACKUP_DIR="${PANEL_DIR}/backup"
WEB_ROOT="/var/www/mask-site"
CADDYFILE="/etc/caddy/Caddyfile"
XRAY_CONFIG="/usr/local/etc/xray/config.json"

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

pause() {
    echo
    read -rp "按 Enter 返回菜单..."
}

need_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        err "请使用 root 用户运行"
        exit 1
    fi
}

detect_os() {
    if [[ ! -f /etc/os-release ]]; then
        err "无法识别系统，仅支持 Debian / Ubuntu"
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

init_dirs() {
    mkdir -p "${PANEL_DIR}" "${BACKUP_DIR}" "${WEB_ROOT}"
}

install_base_deps() {
    info "安装基础依赖..."

    apt-get update
    apt-get install -y \
        curl \
        wget \
        git \
        jq \
        tar \
        unzip \
        nano \
        ca-certificates \
        gnupg \
        lsb-release \
        debian-keyring \
        debian-archive-keyring \
        apt-transport-https \
        procps \
        iproute2

    ok "基础依赖安装完成"
}

backup_file() {
    local file="$1"

    if [[ -f "${file}" ]]; then
        local base
        local ts

        base="$(basename "${file}")"
        ts="$(date +%Y%m%d-%H%M%S)"

        cp -a "${file}" "${BACKUP_DIR}/${base}.${ts}.bak"
        ok "已备份 ${file} 到 ${BACKUP_DIR}/${base}.${ts}.bak"
    fi
}

service_exists() {
    local svc="$1"
    systemctl list-unit-files | awk '{print $1}' | grep -qx "${svc}.service"
}

confirm() {
    local msg="$1"
    local ans

    read -rp "${msg} [y/N]: " ans

    case "${ans}" in
        y|Y|yes|YES)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}
