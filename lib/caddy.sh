#!/usr/bin/env bash
# shellcheck shell=bash
# coding: utf-8
#
# caddy.sh - Caddy 安装与服务生命周期管理
#
# 说明：
#   - 本模块只管理 Caddy 的安装、卸载、启动、停止、重启、重载和状态查看
#   - 本模块不创建、不编辑、不修改 Caddyfile
#   - 文件内容应使用 UTF-8 编码保存
#

# ===== 安全加载 =====
if [ "${XMG_CADDY_SH_LOADED:-0}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi
XMG_CADDY_SH_LOADED=1

# ===== 默认配置 =====
XMG_CADDY_SERVICE="${XMG_CADDY_SERVICE:-caddy}"
XMG_CADDY_APT_KEY_URL="${XMG_CADDY_APT_KEY_URL:-https://dl.cloudsmith.io/public/caddy/stable/gpg.key}"
XMG_CADDY_APT_SOURCE_URL="${XMG_CADDY_APT_SOURCE_URL:-https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt}"
XMG_CADDY_KEYRING_PATH="${XMG_CADDY_KEYRING_PATH:-/usr/share/keyrings/caddy-stable-archive-keyring.gpg}"
XMG_CADDY_APT_SOURCE_PATH="${XMG_CADDY_APT_SOURCE_PATH:-/etc/apt/sources.list.d/caddy-stable.list}"

# ===== 兼容函数 =====
# 如果主框架已经定义这些函数，则不会覆盖。
# 如果单独执行本文件，也能基本运行。

if ! declare -F xmg_cmd_exists >/dev/null 2>&1; then
    xmg_cmd_exists() {
        command -v "$1" >/dev/null 2>&1
    }
fi

if ! declare -F xmg_info >/dev/null 2>&1; then
    xmg_info() {
        printf '[INFO] %s\n' "$*"
    }
fi

if ! declare -F xmg_warn >/dev/null 2>&1; then
    xmg_warn() {
        printf '[WARN] %s\n' "$*" >&2
    }
fi

if ! declare -F xmg_die >/dev/null 2>&1; then
    xmg_die() {
        printf '[ERROR] %s\n' "$*" >&2
        exit 1
    }
fi

if ! declare -F xmg_require_root >/dev/null 2>&1; then
    xmg_require_root() {
        if [ "$(id -u)" -ne 0 ]; then
            xmg_die "请使用 root 用户运行，或使用 sudo 执行"
        fi
    }
fi

if ! declare -F xmg_confirm >/dev/null 2>&1; then
    xmg_confirm() {
        local prompt="${1:-确认继续?}"
        local answer=""

        printf '%s [y/N]: ' "$prompt"
        read -r answer || return 1

        case "$answer" in
            y|Y|yes|YES|Yes)
                return 0
                ;;
            *)
                return 1
                ;;
        esac
    }
fi

if ! declare -F xmg_pause >/dev/null 2>&1; then
    xmg_pause() {
        printf '\n按回车键继续...'
        read -r _ || true
    }
fi

if ! declare -F xmg_systemctl >/dev/null 2>&1; then
    xmg_systemctl() {
        local action="${1:-}"
        local service="${2:-}"

        if [ -z "$action" ] || [ -z "$service" ]; then
            xmg_die "xmg_systemctl 参数错误"
        fi

        if ! xmg_cmd_exists systemctl; then
            xmg_die "systemctl 不存在，当前系统可能不是 systemd 环境"
        fi

        systemctl "$action" "$service" || xmg_die "执行 systemctl ${action} ${service} 失败"
    }
fi

# ===== 基础检测 =====

xmg_caddy_binary_exists() {
    xmg_cmd_exists caddy
}

xmg_caddy_is_systemd_available() {
    xmg_cmd_exists systemctl
}

# ===== 安装 / 更新 =====

xmg_caddy_install_update() {
    xmg_require_root
    xmg_info "安装/更新 Caddy"

    local tmp_key=""
    local tmp_keyring=""
    local tmp_source=""

    if xmg_cmd_exists apt-get; then
        xmg_info "检测到 apt-get，使用 Debian/Ubuntu/Raspbian 安装路径"

        export DEBIAN_FRONTEND=noninteractive

        apt-get update || xmg_die "apt update 失败"

        apt-get install -y \
            debian-keyring \
            debian-archive-keyring \
            apt-transport-https \
            ca-certificates \
            curl \
            gnupg \
            || xmg_die "安装 Caddy APT 依赖失败"

        install -d -m 0755 /usr/share/keyrings \
            || xmg_die "创建 /usr/share/keyrings 失败"

        install -d -m 0755 /etc/apt/sources.list.d \
            || xmg_die "创建 /etc/apt/sources.list.d 失败"

        tmp_key="$(mktemp)" || xmg_die "创建临时 GPG key 文件失败"

        tmp_keyring="$(mktemp)" || {
            rm -f "$tmp_key"
            xmg_die "创建临时 keyring 文件失败"
        }

        tmp_source="$(mktemp)" || {
            rm -f "$tmp_key" "$tmp_keyring"
            xmg_die "创建临时 APT source 文件失败"
        }

        if ! curl -fsSL "$XMG_CADDY_APT_KEY_URL" -o "$tmp_key"; then
            rm -f "$tmp_key" "$tmp_keyring" "$tmp_source"
            xmg_die "下载 Caddy GPG key 失败"
        fi

        if ! gpg --dearmor --yes -o "$tmp_keyring" "$tmp_key"; then
            rm -f "$tmp_key" "$tmp_keyring" "$tmp_source"
            xmg_die "转换 Caddy GPG key 失败"
        fi

        if ! curl -fsSL "$XMG_CADDY_APT_SOURCE_URL" -o "$tmp_source"; then
            rm -f "$tmp_key" "$tmp_keyring" "$tmp_source"
            xmg_die "下载 Caddy APT 源配置失败"
        fi

        # 防止代理、网关、DNS 异常时写入 HTML 错误页
        if ! grep -qE '^[[:space:]]*deb[[:space:]]' "$tmp_source"; then
            rm -f "$tmp_key" "$tmp_keyring" "$tmp_source"
            xmg_die "Caddy APT 源配置内容异常"
        fi

        install -m 0644 "$tmp_keyring" "$XMG_CADDY_KEYRING_PATH" || {
            rm -f "$tmp_key" "$tmp_keyring" "$tmp_source"
            xmg_die "安装 Caddy keyring 失败"
        }

        install -m 0644 "$tmp_source" "$XMG_CADDY_APT_SOURCE_PATH" || {
            rm -f "$tmp_key" "$tmp_keyring" "$tmp_source"
            xmg_die "写入 Caddy APT 源失败"
        }

        rm -f "$tmp_key" "$tmp_keyring" "$tmp_source"

        apt-get update || xmg_die "添加 Caddy APT 源后 apt update 失败"
        apt-get install -y caddy || xmg_die "安装 Caddy 失败"

    elif xmg_cmd_exists dnf; then
        xmg_info "检测到 dnf，使用 Fedora/RHEL/CentOS Stream/Rocky/AlmaLinux 安装路径"

        dnf install -y dnf-plugins-core \
            || xmg_die "安装 dnf-plugins-core 失败"

        dnf copr enable -y @caddy/caddy \
            || xmg_die "启用 Caddy COPR 源失败"

        dnf install -y caddy \
            || xmg_die "dnf 安装 Caddy 失败"

    elif xmg_cmd_exists yum; then
        xmg_info "检测到 yum，使用 CentOS/RHEL 7 安装路径"

        yum install -y yum-plugin-copr \
            || xmg_die "安装 yum-plugin-copr 失败"

        yum copr enable -y @caddy/caddy \
            || xmg_die "启用 Caddy COPR 源失败"

        yum install -y caddy \
            || xmg_die "yum 安装 Caddy 失败"

    else
        xmg_die "未支持的系统：未检测到 apt-get / dnf / yum"
    fi

    if ! xmg_caddy_binary_exists; then
        xmg_die "安装流程结束，但未检测到 caddy 命令"
    fi

    xmg_info "Caddy 命令检测成功"

    if caddy version >/dev/null 2>&1; then
        xmg_info "Caddy 版本：$(caddy version 2>/dev/null)"
    else
        xmg_warn "无法获取 Caddy 版本，但 caddy 命令已存在"
    fi

    if xmg_caddy_is_systemd_available; then
        systemctl daemon-reload >/dev/null 2>&1 || true

        if ! systemctl enable "$XMG_CADDY_SERVICE" >/dev/null 2>&1; then
            xmg_warn "Caddy 已安装，但设置开机自启失败"
        fi

        # 服务启动失败常见原因是 Caddyfile、端口占用或权限问题。
        # 这里不直接判定安装失败。
        if ! systemctl start "$XMG_CADDY_SERVICE" >/dev/null 2>&1; then
            xmg_warn "Caddy 已安装，但服务启动失败"
            xmg_warn "请执行以下命令查看原因："
            xmg_warn "systemctl status ${XMG_CADDY_SERVICE} --no-pager"
            xmg_warn "journalctl -u ${XMG_CADDY_SERVICE} -n 100 --no-pager"
        else
            xmg_info "Caddy 服务已启动"
        fi
    else
        xmg_warn "未检测到 systemctl，仅完成 Caddy 安装"
    fi

    xmg_info "Caddy 安装/更新完成"
    xmg_warn "XMG 不处理 Caddyfile，请用户自行维护配置"
}

# ===== 卸载 =====

xmg_caddy_uninstall() {
    xmg_require_root

    if ! xmg_caddy_binary_exists; then
        xmg_warn "未检测到 Caddy 命令，可能尚未安装"
    fi

    xmg_warn "即将卸载 Caddy"
    xmg_warn "XMG 不负责备份或删除用户自定义 Caddyfile"

    if ! xmg_confirm "确认卸载 Caddy?"; then
        xmg_info "已取消"
        return 0
    fi

    if xmg_caddy_is_systemd_available; then
        systemctl stop "$XMG_CADDY_SERVICE" >/dev/null 2>&1 || true
        systemctl disable "$XMG_CADDY_SERVICE" >/dev/null 2>&1 || true
    fi

    if xmg_cmd_exists apt-get; then
        apt-get remove -y caddy || xmg_die "卸载 Caddy 失败"
        xmg_info "Caddy 已卸载"
        return 0
    fi

    if xmg_cmd_exists dnf; then
        dnf remove -y caddy || xmg_die "卸载 Caddy 失败"
        xmg_info "Caddy 已卸载"
        return 0
    fi

    if xmg_cmd_exists yum; then
        yum remove -y caddy || xmg_die "卸载 Caddy 失败"
        xmg_info "Caddy 已卸载"
        return 0
    fi

    xmg_die "未支持的系统：无法卸载 Caddy"
}

# ===== 服务生命周期 =====

xmg_caddy_start() {
    xmg_require_root
    xmg_systemctl start "$XMG_CADDY_SERVICE"
    xmg_info "Caddy 已启动"
}

xmg_caddy_stop() {
    xmg_require_root
    xmg_systemctl stop "$XMG_CADDY_SERVICE"
    xmg_info "Caddy 已停止"
}

xmg_caddy_restart() {
    xmg_require_root
    xmg_systemctl restart "$XMG_CADDY_SERVICE"
    xmg_info "Caddy 已重启"
}

xmg_caddy_reload() {
    xmg_require_root
    xmg_systemctl reload "$XMG_CADDY_SERVICE"
    xmg_info "Caddy 已重载"
}

xmg_caddy_status() {
    if ! xmg_caddy_is_systemd_available; then
        xmg_warn "systemctl 不存在，无法查看 Caddy 状态"
        return 1
    fi

    systemctl status "$XMG_CADDY_SERVICE" --no-pager || true
}

# ===== 配置校验 =====

xmg_caddy_validate_config() {
    if ! xmg_caddy_binary_exists; then
        xmg_warn "caddy 命令不存在，无法校验配置"
        return 1
    fi

    if [ -f /etc/caddy/Caddyfile ]; then
        caddy validate --config /etc/caddy/Caddyfile || return 1
    else
        xmg_warn "未找到 /etc/caddy/Caddyfile"
        return 1
    fi
}

# ===== 诊断 =====

xmg_caddy_diag() {
    echo "========== Caddy 安装诊断 =========="

    echo
    echo "[系统信息]"
    if [ -f /etc/os-release ]; then
        cat /etc/os-release
    else
        uname -a
    fi

    echo
    echo "[当前用户]"
    echo "uid=$(id -u), user=$(id -un 2>/dev/null || echo unknown)"

    echo
    echo "[包管理器检测]"
    if xmg_cmd_exists apt-get; then
        echo "apt-get: $(command -v apt-get)"
    else
        echo "apt-get: 未检测到"
    fi

    if xmg_cmd_exists dnf; then
        echo "dnf: $(command -v dnf)"
    else
        echo "dnf: 未检测到"
    fi

    if xmg_cmd_exists yum; then
        echo "yum: $(command -v yum)"
    else
        echo "yum: 未检测到"
    fi

    echo
    echo "[基础命令检测]"
    for cmd in curl gpg systemctl caddy; do
        if xmg_cmd_exists "$cmd"; then
            echo "$cmd: $(command -v "$cmd")"
        else
            echo "$cmd: 未检测到"
        fi
    done

    echo
    echo "[Caddy 版本]"
    if xmg_caddy_binary_exists; then
        caddy version 2>/dev/null || echo "无法获取 caddy version"
    else
        echo "caddy 未安装"
    fi

    echo
    echo "[APT 源文件]"
    if [ -f "$XMG_CADDY_APT_SOURCE_PATH" ]; then
        echo "存在：$XMG_CADDY_APT_SOURCE_PATH"
        sed -n '1,20p' "$XMG_CADDY_APT_SOURCE_PATH"
    else
        echo "不存在：$XMG_CADDY_APT_SOURCE_PATH"
    fi

    echo
    echo "[APT keyring]"
    if [ -f "$XMG_CADDY_KEYRING_PATH" ]; then
        echo "存在：$XMG_CADDY_KEYRING_PATH"
        ls -l "$XMG_CADDY_KEYRING_PATH"
    else
        echo "不存在：$XMG_CADDY_KEYRING_PATH"
    fi

    echo
    echo "[网络测试]"
    if xmg_cmd_exists curl; then
        if curl -fsSL -I "$XMG_CADDY_APT_KEY_URL" >/dev/null 2>&1; then
            echo "Caddy GPG key URL 可访问"
        else
            echo "Caddy GPG key URL 不可访问"
        fi

        if curl -fsSL -I "$XMG_CADDY_APT_SOURCE_URL" >/dev/null 2>&1; then
            echo "Caddy APT source URL 可访问"
        else
            echo "Caddy APT source URL 不可访问"
        fi
    else
        echo "curl 未安装，跳过网络测试"
    fi

    echo
    echo "[systemd 服务状态]"
    if xmg_caddy_is_systemd_available; then
        systemctl status "$XMG_CADDY_SERVICE" --no-pager || true
    else
        echo "systemctl 不存在"
    fi

    echo
    echo "[最近日志]"
    if xmg_caddy_is_systemd_available; then
        journalctl -u "$XMG_CADDY_SERVICE" -n 50 --no-pager 2>/dev/null || true
    else
        echo "systemctl 不存在，跳过 journalctl"
    fi
}

# ===== 菜单 =====

xmg_caddy_menu() {
    local choice=""

    while true; do
        clear
        echo "========== Caddy 管理 =========="
        echo "1. 安装/更新 Caddy"
        echo "2. 卸载 Caddy"
        echo "3. 启动 Caddy"
        echo "4. 停止 Caddy"
        echo "5. 重启 Caddy"
        echo "6. 重载 Caddy"
        echo "7. 查看 Caddy 状态"
        echo "8. 校验 Caddyfile"
        echo "9. 安装诊断"
        echo "0. 返回"
        echo
        echo "说明:"
        echo "  - XMG 只管理 Caddy 服务生命周期"
        echo "  - XMG 不创建、不编辑、不修改 Caddyfile"
        echo "  - 如需修改站点配置，请自行维护 /etc/caddy/Caddyfile"
        echo
        printf "请选择: "

        read -r choice || return 0

        case "$choice" in
            1)
                xmg_caddy_install_update
                xmg_pause
                ;;
            2)
                xmg_caddy_uninstall
                xmg_pause
                ;;
            3)
                xmg_caddy_start
                xmg_pause
                ;;
            4)
                xmg_caddy_stop
                xmg_pause
                ;;
            5)
                xmg_caddy_restart
                xmg_pause
                ;;
            6)
                xmg_caddy_reload
                xmg_pause
                ;;
            7)
                xmg_caddy_status
                xmg_pause
                ;;
            8)
                xmg_caddy_validate_config
                xmg_pause
                ;;
            9)
                xmg_caddy_diag
                xmg_pause
                ;;
            0)
                return 0
                ;;
            *)
                xmg_warn "无效选择"
                xmg_pause
                ;;
        esac
    done
}

# ===== 直接执行支持 =====
# 如果本文件被直接运行，则进入菜单。
# 如果被 source，则只加载函数。

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    xmg_caddy_menu
fi
