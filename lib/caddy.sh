#!/usr/bin/env bash

# ========== 安全集成（支持 source / 直接执行） ==========
if [ "${XMG_CADDY_SH_LOADED:-0}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi
XMG_CADDY_SH_LOADED=1

set -euo pipefail

# ========== 基础变量 ==========
CADDY_SERVICE="${CADDY_SERVICE:-caddy}"
CADDY_BIN="/usr/bin/caddy"

# ========== 基础工具 ==========
log()  { echo -e "\033[32m[INFO]\033[0m $*"; }
warn() { echo -e "\033[33m[WARN]\033[0m $*"; }
err()  { echo -e "\033[31m[ERROR]\033[0m $*" >&2; }

die() {
    err "$*"
    exit 1
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        die "请使用 root 运行"
    fi
}

cmd_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ========== 网络检测 ==========
check_network() {
    curl -fsSL https://dl.cloudsmith.io >/dev/null 2>&1 \
        || die "网络不可用，无法安装"
}

# ========== systemctl fallback ==========
svc() {
    if cmd_exists systemctl; then
        systemctl "$@"
    else
        service "$1" "$2"
    fi
}

# ========== 安装：APT ==========
install_apt() {
    log "使用 apt 安装 Caddy"

    apt-get update || die "apt update 失败"

    apt-get install -y curl gnupg apt-transport-https || die "依赖安装失败"

    mkdir -p /usr/share/keyrings

    curl -fsSL https://dl.cloudsmith.io/public/caddy/stable/gpg.key \
        | gpg --dearmor -o /usr/share/keyrings/caddy.gpg \
        || die "导入 GPG key 失败"

    cat > /etc/apt/sources.list.d/caddy.list <<EOF
deb [signed-by=/usr/share/keyrings/caddy.gpg] https://dl.cloudsmith.io/public/caddy/stable/debian any-version main
EOF

    apt-get update || die "apt update 失败"

    apt-get install -y caddy || die "Caddy 安装失败"

    log "Caddy 安装完成"
}

# ========== 安装：DNF/YUM ==========
install_rpm() {
    log "使用 dnf/yum 安装 Caddy"

    if cmd_exists dnf; then
        dnf install -y dnf-plugins-core || true
        dnf copr enable -y @caddy/caddy || warn "COPR 不可用"
        dnf install -y caddy && return 0
    fi

    if cmd_exists yum; then
        yum install -y yum-plugin-copr || true
        yum copr enable -y @caddy/caddy || warn "COPR 不可用"
        yum install -y caddy && return 0
    fi

    return 1
}

# ========== 安装：Fallback（二进制） ==========
install_binary() {
    log "使用官方二进制安装"

    tmp=$(mktemp -d)

    arch=$(uname -m)
    case "$arch" in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        *) die "不支持架构: $arch" ;;
    esac

    url="https://github.com/caddyserver/caddy/releases/latest/download/caddy_${arch}_linux.tar.gz"

    curl -L "$url" -o "$tmp/caddy.tar.gz" || die "下载失败"

    tar -xzf "$tmp/caddy.tar.gz" -C "$tmp" || die "解压失败"

    install "$tmp/caddy" /usr/bin/caddy || die "安装失败"

    rm -rf "$tmp"

    log "Caddy 二进制安装完成"
}

# ========== 安装入口 ==========
install_caddy() {
    require_root
    check_network

    if cmd_exists caddy; then
        warn "检测到已安装 Caddy，将更新"
    fi

    if cmd_exists apt-get; then
        install_apt && return
    fi

    if install_rpm; then
        log "Caddy 安装完成"
        return
    fi

    install_binary
}

# ========== 卸载 ==========
uninstall_caddy() {
    require_root

    warn "卸载 Caddy"

    if cmd_exists apt-get; then
        apt-get remove -y caddy
        return
    fi

    if cmd_exists dnf; then
        dnf remove -y caddy
        return
    fi

    if cmd_exists yum; then
        yum remove -y caddy
        return
    fi

    rm -f /usr/bin/caddy
}

# ========== 服务控制 ==========
start_caddy() {
    svc start "$CADDY_SERVICE"
    log "已启动"
}

stop_caddy() {
    svc stop "$CADDY_SERVICE"
    log "已停止"
}

restart_caddy() {
    svc restart "$CADDY_SERVICE"
    log "已重启"
}

status_caddy() {
    if cmd_exists systemctl; then
        systemctl status "$CADDY_SERVICE" --no-pager || true
    else
        service "$CADDY_SERVICE" status || true
    fi
}

# ========== 健康检查 ==========
check_port() {
    ss -lnt 2>/dev/null | grep -q ":$1 " && return 0 || return 1
}

health_check() {
    log "执行健康检测..."

    if check_port 80; then
        log "端口 80 正在监听"
    else
        warn "端口 80 未监听"
    fi

    if check_port 443; then
        log "端口 443 正在监听"
    else
        warn "端口 443 未监听"
    fi

    if curl -sI http://127.0.0.1 | grep -q "HTTP"; then
        log "HTTP 正常"
    else
        warn "HTTP 未响应"
    fi
}

# ========== 日志 ==========
logs_caddy() {
    if cmd_exists journalctl; then
        journalctl -u "$CADDY_SERVICE" -f
    else
        warn "无 journalctl"
    fi
}

# ========== 菜单 ==========
menu() {
    while true; do
        echo "==== Caddy 管理 ===="
        echo "1 安装/更新"
        echo "2 卸载"
        echo "3 启动"
        echo "4 停止"
        echo "5 重启"
        echo "6 状态"
        echo "7 日志"
        echo "8 健康检查"
        echo "0 退出"
        read -r -p "选择: " c

        case "$c" in
            1) install_caddy ;;
            2) uninstall_caddy ;;
            3) start_caddy ;;
            4) stop_caddy ;;
            5) restart_caddy ;;
            6) status_caddy ;;
            7) logs_caddy ;;
            8) health_check ;;
            0) exit 0 ;;
            *) warn "无效选项" ;;
        esac
    done
}

# ========== 入口 ==========
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    menu
fi
