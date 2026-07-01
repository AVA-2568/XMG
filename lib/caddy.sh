#!/usr/bin/env bash
# shellcheck shell=bash
# coding: utf-8
#
# caddy.sh - Caddy 安装与服务生命周期管理
#
# 说明：
#   - 本模块只管理 Caddy 的安装、卸载、启动、停止、重启、重载和状态查看
#   - 本模块不创建、不编辑、不修改 Caddyfile
#   - 保留 XMG_CADDY_* 关键参数和 xmg_caddy_* 对外函数名
#   - 安装策略：
#       1. 优先使用 apt / dnf / yum
#       2. apt update 被 Cloudflare WARP 源阻塞时，临时绕过 WARP 源
#       3. 包管理器安装失败时，回退到 GitHub 官方二进制安装
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

# 新增可选参数：不影响原有主框架调用
XMG_CADDY_ENABLE_BINARY_FALLBACK="${XMG_CADDY_ENABLE_BINARY_FALLBACK:-1}"
XMG_CADDY_TEMP_DISABLE_CLOUDFLARE_SOURCE="${XMG_CADDY_TEMP_DISABLE_CLOUDFLARE_SOURCE:-1}"
XMG_CADDY_BINARY_INSTALL_PATH="${XMG_CADDY_BINARY_INSTALL_PATH:-/usr/local/bin/caddy}"

# ===== 兼容函数 =====

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
    xmg_cmd_exists caddy || [ -x "$XMG_CADDY_BINARY_INSTALL_PATH" ]
}

xmg_caddy_is_systemd_available() {
    xmg_cmd_exists systemctl
}

xmg_caddy_print_version() {
    if xmg_cmd_exists caddy; then
        caddy version 2>/dev/null || true
    elif [ -x "$XMG_CADDY_BINARY_INSTALL_PATH" ]; then
        "$XMG_CADDY_BINARY_INSTALL_PATH" version 2>/dev/null || true
    else
        return 1
    fi
}

# ===== 下载辅助 =====

xmg_caddy_download() {
    local url="${1:-}"
    local output="${2:-}"

    if [ -z "$url" ] || [ -z "$output" ]; then
        return 1
    fi

    if xmg_cmd_exists curl; then
        curl -fsSL "$url" -o "$output"
        return $?
    fi

    if xmg_cmd_exists wget; then
        wget -qO "$output" "$url"
        return $?
    fi

    return 1
}

# ===== APT 辅助：绕过 Cloudflare WARP 源 =====

XMG_CADDY_CF_DISABLED_FILES=""

xmg_caddy_has_cloudflare_apt_source() {
    grep -R "pkg.cloudflareclient.com" \
        /etc/apt/sources.list \
        /etc/apt/sources.list.d \
        >/dev/null 2>&1
}

xmg_caddy_disable_cloudflare_source_files() {
    local file=""
    local backup=""

    XMG_CADDY_CF_DISABLED_FILES=""

    if [ "$XMG_CADDY_TEMP_DISABLE_CLOUDFLARE_SOURCE" != "1" ]; then
        return 1
    fi

    if [ ! -d /etc/apt/sources.list.d ]; then
        return 1
    fi

    while IFS= read -r file; do
        [ -f "$file" ] || continue

        backup="${file}.xmg-caddy-disabled"

        if mv "$file" "$backup"; then
            XMG_CADDY_CF_DISABLED_FILES="${XMG_CADDY_CF_DISABLED_FILES}${file}|${backup}
"
            xmg_warn "已临时禁用 Cloudflare WARP APT 源：$file"
        fi
    done <<EOF
$(find /etc/apt/sources.list.d -type f \( -name '*.list' -o -name '*.sources' \) -print 2>/dev/null | while read -r f; do
    grep -q "pkg.cloudflareclient.com" "$f" 2>/dev/null && printf '%s\n' "$f"
done)
EOF

    if [ -n "$XMG_CADDY_CF_DISABLED_FILES" ]; then
        return 0
    fi

    return 1
}

xmg_caddy_restore_cloudflare_source_files() {
    local line=""
    local original=""
    local backup=""

    [ -n "$XMG_CADDY_CF_DISABLED_FILES" ] || return 0

    while IFS= read -r line; do
        [ -n "$line" ] || continue

        original="${line%%|*}"
        backup="${line#*|}"

        if [ -f "$backup" ]; then
            mv "$backup" "$original" \
                && xmg_info "已恢复 Cloudflare WARP APT 源：$original" \
                || xmg_warn "恢复 Cloudflare WARP APT 源失败：$original"
        fi
    done <<EOF
$XMG_CADDY_CF_DISABLED_FILES
EOF

    XMG_CADDY_CF_DISABLED_FILES=""
}

xmg_caddy_apt_update_smart() {
    xmg_info "执行 apt-get update"

    if apt-get update; then
        return 0
    fi

    xmg_warn "apt-get update 失败"

    if xmg_caddy_has_cloudflare_apt_source; then
        xmg_warn "检测到 Cloudflare WARP/Client APT 源"
        xmg_warn "该源缺少 GPG key 时会阻塞整个 apt update"

        if xmg_caddy_disable_cloudflare_source_files; then
            xmg_warn "已临时绕过 Cloudflare WARP 源，再次执行 apt-get update"

            if apt-get update; then
                xmg_caddy_restore_cloudflare_source_files
                return 0
            fi

            xmg_caddy_restore_cloudflare_source_files
        else
            xmg_warn "未能自动临时禁用 Cloudflare WARP 源"
            xmg_warn "如果该源写在 /etc/apt/sources.list 主文件中，请手动处理"
        fi
    fi

    return 1
}

# ===== APT 安装 =====

xmg_caddy_install_by_apt() {
    local tmp_key=""
    local tmp_source=""

    xmg_info "检测到 apt-get，使用 Debian/Ubuntu/Raspbian 安装路径"

    export DEBIAN_FRONTEND=noninteractive

    if ! xmg_caddy_apt_update_smart; then
        xmg_warn "apt update 失败，继续尝试使用现有缓存安装依赖"
    fi

    if ! apt-get install -y \
        debian-keyring \
        debian-archive-keyring \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg; then
        xmg_warn "安装 Caddy APT 依赖失败"

        if ! xmg_cmd_exists curl || ! xmg_cmd_exists gpg; then
            xmg_warn "缺少 curl 或 gpg，无法继续 APT 官方源安装"
            return 1
        fi
    fi

    install -d -m 0755 /usr/share/keyrings || return 1
    install -d -m 0755 /etc/apt/sources.list.d || return 1

    tmp_key="$(mktemp)" || return 1
    tmp_source="$(mktemp)" || {
        rm -f "$tmp_key"
        return 1
    }

    if ! xmg_caddy_download "$XMG_CADDY_APT_KEY_URL" "$tmp_key"; then
        rm -f "$tmp_key" "$tmp_source"
        xmg_warn "下载 Caddy GPG key 失败"
        return 1
    fi

    if ! gpg --dearmor --yes -o "$XMG_CADDY_KEYRING_PATH" "$tmp_key"; then
        rm -f "$tmp_key" "$tmp_source"
        xmg_warn "转换 Caddy GPG key 失败"
        return 1
    fi

    if ! xmg_caddy_download "$XMG_CADDY_APT_SOURCE_URL" "$tmp_source"; then
        rm -f "$tmp_key" "$tmp_source"
        xmg_warn "下载 Caddy APT 源配置失败"
        return 1
    fi

    if ! grep -qE '^[[:space:]]*deb[[:space:]]' "$tmp_source"; then
        rm -f "$tmp_key" "$tmp_source"
        xmg_warn "Caddy APT 源配置内容异常，可能下载到了 HTML 错误页"
        return 1
    fi

    if ! install -m 0644 "$tmp_source" "$XMG_CADDY_APT_SOURCE_PATH"; then
        rm -f "$tmp_key" "$tmp_source"
        xmg_warn "写入 Caddy APT 源失败"
        return 1
    fi

    rm -f "$tmp_key" "$tmp_source"

    if ! xmg_caddy_apt_update_smart; then
        xmg_warn "添加 Caddy APT 源后 apt update 仍失败"
        xmg_warn "继续尝试直接 apt-get install caddy"
    fi

    if apt-get install -y caddy; then
        xmg_info "APT 安装 Caddy 成功"
        return 0
    fi

    xmg_warn "APT 安装 Caddy 失败"
    return 1
}

# ===== DNF/YUM 安装 =====

xmg_caddy_install_by_dnf() {
    xmg_info "检测到 dnf，使用 Fedora/RHEL/CentOS Stream/Rocky/AlmaLinux 安装路径"

    dnf install -y dnf-plugins-core || return 1
    dnf copr enable -y @caddy/caddy || return 1
    dnf install -y caddy || return 1

    xmg_info "DNF 安装 Caddy 成功"
    return 0
}

xmg_caddy_install_by_yum() {
    xmg_info "检测到 yum，使用 CentOS/RHEL 7 安装路径"

    yum install -y yum-plugin-copr || return 1
    yum copr enable -y @caddy/caddy || return 1
    yum install -y caddy || return 1

    xmg_info "YUM 安装 Caddy 成功"
    return 0
}

# ===== GitHub 二进制回退安装 =====

xmg_caddy_get_linux_arch() {
    local machine=""

    machine="$(uname -m 2>/dev/null || true)"

    case "$machine" in
        x86_64|amd64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7l|armv7)
            echo "armv7"
            ;;
        armv6l|armv6)
            echo "armv6"
            ;;
        i386|i686)
            echo "386"
            ;;
        *)
            return 1
            ;;
    esac
}

xmg_caddy_create_user_and_dirs() {
    if ! id caddy >/dev/null 2>&1; then
        if xmg_cmd_exists useradd; then
            useradd \
                --system \
                --home /var/lib/caddy \
                --shell /usr/sbin/nologin \
                caddy 2>/dev/null \
                || useradd -r -d /var/lib/caddy -s /sbin/nologin caddy 2>/dev/null \
                || true
        fi
    fi

    install -d -m 0755 /etc/caddy
    install -d -m 0755 /var/lib/caddy
    install -d -m 0755 /var/log/caddy

    if id caddy >/dev/null 2>&1; then
        chown -R caddy:caddy /var/lib/caddy /var/log/caddy 2>/dev/null || true
    fi
}

xmg_caddy_install_systemd_unit_for_binary() {
    local unit_path="/etc/systemd/system/${XMG_CADDY_SERVICE}.service"

    if ! xmg_caddy_is_systemd_available; then
        xmg_warn "未检测到 systemctl，跳过 systemd service 创建"
        return 0
    fi

    if [ -f "/etc/systemd/system/${XMG_CADDY_SERVICE}.service" ] \
        || [ -f "/lib/systemd/system/${XMG_CADDY_SERVICE}.service" ] \
        || [ -f "/usr/lib/systemd/system/${XMG_CADDY_SERVICE}.service" ]; then
        xmg_info "检测到已有 ${XMG_CADDY_SERVICE}.service，跳过创建"
        return 0
    fi

    cat > "$unit_path" <<EOF
[Unit]
Description=Caddy web server
Documentation=https://caddyserver.com/docs/
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
User=caddy
Group=caddy
ExecStart=${XMG_CADDY_BINARY_INSTALL_PATH} run --environ --config /etc/caddy/Caddyfile
ExecReload=${XMG_CADDY_BINARY_INSTALL_PATH} reload --config /etc/caddy/Caddyfile --force
TimeoutStopSec=5s
LimitNOFILE=1048576
PrivateTmp=true
ProtectSystem=full
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
WorkingDirectory=/var/lib/caddy

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload || true
    xmg_info "已创建 systemd service：$unit_path"
}

xmg_caddy_install_by_github_binary() {
    local arch=""
    local latest_url=""
    local version=""
    local asset=""
    local url=""
    local tmp_dir=""
    local tar_file=""

    if [ "$XMG_CADDY_ENABLE_BINARY_FALLBACK" != "1" ]; then
        xmg_warn "GitHub 二进制回退安装已关闭"
        return 1
    fi

    xmg_info "尝试使用 GitHub 官方二进制安装 Caddy"

    if ! xmg_cmd_exists curl; then
        xmg_warn "缺少 curl，无法获取 GitHub latest release"
        return 1
    fi

    if ! xmg_cmd_exists tar; then
        xmg_warn "缺少 tar，无法解压 Caddy 二进制包"
        return 1
    fi

    arch="$(xmg_caddy_get_linux_arch)" || {
        xmg_warn "不支持的 CPU 架构：$(uname -m 2>/dev/null || echo unknown)"
        return 1
    }

    latest_url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/caddyserver/caddy/releases/latest)" || {
        xmg_warn "获取 Caddy latest release 失败"
        return 1
    }

    version="${latest_url##*/}"

    case "$version" in
        v*)
            ;;
        *)
            xmg_warn "无法解析 Caddy release 版本：$latest_url"
            return 1
            ;;
    esac

    asset="caddy_${version#v}_linux_${arch}.tar.gz"
    url="https://github.com/caddyserver/caddy/releases/download/${version}/${asset}"

    tmp_dir="$(mktemp -d)" || return 1
    tar_file="${tmp_dir}/${asset}"

    xmg_info "下载 Caddy：$url"

    if ! xmg_caddy_download "$url" "$tar_file"; then
        rm -rf "$tmp_dir"
        xmg_warn "下载 Caddy 二进制包失败"
        return 1
    fi

    if ! tar -xzf "$tar_file" -C "$tmp_dir"; then
        rm -rf "$tmp_dir"
        xmg_warn "解压 Caddy 二进制包失败"
        return 1
    fi

    if [ ! -f "${tmp_dir}/caddy" ]; then
        rm -rf "$tmp_dir"
        xmg_warn "二进制包中未找到 caddy 文件"
        return 1
    fi

    install -m 0755 "${tmp_dir}/caddy" "$XMG_CADDY_BINARY_INSTALL_PATH" || {
        rm -rf "$tmp_dir"
        xmg_warn "安装 Caddy 二进制文件失败"
        return 1
    }

    rm -rf "$tmp_dir"

    xmg_caddy_create_user_and_dirs
    xmg_caddy_install_systemd_unit_for_binary

    xmg_info "GitHub 二进制安装 Caddy 成功"
    "$XMG_CADDY_BINARY_INSTALL_PATH" version 2>/dev/null || true

    return 0
}

# ===== 安装 / 更新 =====

xmg_caddy_install_update() {
    xmg_require_root
    xmg_info "安装/更新 Caddy"

    local installed=0

    if xmg_cmd_exists apt-get; then
        if xmg_caddy_install_by_apt; then
            installed=1
        else
            xmg_warn "APT 安装路径失败，准备尝试其他方式"
        fi
    elif xmg_cmd_exists dnf; then
        if xmg_caddy_install_by_dnf; then
            installed=1
        else
            xmg_warn "DNF 安装路径失败，准备尝试其他方式"
        fi
    elif xmg_cmd_exists yum; then
        if xmg_caddy_install_by_yum; then
            installed=1
        else
            xmg_warn "YUM 安装路径失败，准备尝试其他方式"
        fi
    else
        xmg_warn "未检测到 apt-get / dnf / yum"
    fi

    if [ "$installed" -ne 1 ]; then
        if xmg_caddy_install_by_github_binary; then
            installed=1
        fi
    fi

    if [ "$installed" -ne 1 ]; then
        xmg_die "所有 Caddy 安装方式均失败"
    fi

    if ! xmg_caddy_binary_exists; then
        xmg_die "安装流程结束，但未检测到 caddy 命令"
    fi

    xmg_info "Caddy 命令检测成功"

    if xmg_caddy_print_version >/dev/null 2>&1; then
        xmg_info "Caddy 版本：$(xmg_caddy_print_version)"
    else
        xmg_warn "无法获取 Caddy 版本，但 caddy 命令已存在"
    fi

    if xmg_caddy_is_systemd_available; then
        systemctl daemon-reload >/dev/null 2>&1 || true

        if systemctl enable "$XMG_CADDY_SERVICE" >/dev/null 2>&1; then
            xmg_info "Caddy 已设置为开机自启"
        else
            xmg_warn "Caddy 已安装，但设置开机自启失败"
        fi

        if [ ! -f /etc/caddy/Caddyfile ]; then
            xmg_warn "未找到 /etc/caddy/Caddyfile"
            xmg_warn "本模块不会创建 Caddyfile，因此服务启动可能失败"
        fi

        if systemctl start "$XMG_CADDY_SERVICE" >/dev/null 2>&1; then
            xmg_info "Caddy 服务已启动"
        else
            xmg_warn "Caddy 已安装，但服务启动失败"
            xmg_warn "常见原因：Caddyfile 不存在、配置错误、端口占用或权限问题"
            xmg_warn "请执行以下命令查看原因："
            xmg_warn "systemctl status ${XMG_CADDY_SERVICE} --no-pager"
            xmg_warn "journalctl -u ${XMG_CADDY_SERVICE} -n 100 --no-pager"
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

    if xmg_cmd_exists apt-get && dpkg -s caddy >/dev/null 2>&1; then
        apt-get remove -y caddy || xmg_warn "通过 apt 卸载 Caddy 失败"
    elif xmg_cmd_exists dnf && rpm -q caddy >/dev/null 2>&1; then
        dnf remove -y caddy || xmg_warn "通过 dnf 卸载 Caddy 失败"
    elif xmg_cmd_exists yum && rpm -q caddy >/dev/null 2>&1; then
        yum remove -y caddy || xmg_warn "通过 yum 卸载 Caddy 失败"
    fi

    if [ -x "$XMG_CADDY_BINARY_INSTALL_PATH" ]; then
        rm -f "$XMG_CADDY_BINARY_INSTALL_PATH" \
            && xmg_info "已删除二进制文件：$XMG_CADDY_BINARY_INSTALL_PATH" \
            || xmg_warn "删除二进制文件失败：$XMG_CADDY_BINARY_INSTALL_PATH"
    fi

    if [ -f "/etc/systemd/system/${XMG_CADDY_SERVICE}.service" ]; then
        rm -f "/etc/systemd/system/${XMG_CADDY_SERVICE}.service"
        systemctl daemon-reload >/dev/null 2>&1 || true
        xmg_info "已删除 systemd service：/etc/systemd/system/${XMG_CADDY_SERVICE}.service"
    fi

    xmg_info "Caddy 卸载流程完成"
    xmg_warn "未删除 /etc/caddy/Caddyfile 和 /etc/caddy 目录"
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
    local caddy_bin=""

    if xmg_cmd_exists caddy; then
        caddy_bin="$(command -v caddy)"
    elif [ -x "$XMG_CADDY_BINARY_INSTALL_PATH" ]; then
        caddy_bin="$XMG_CADDY_BINARY_INSTALL_PATH"
    else
        xmg_warn "caddy 命令不存在，无法校验配置"
        return 1
    fi

    if [ -f /etc/caddy/Caddyfile ]; then
        "$caddy_bin" validate --config /etc/caddy/Caddyfile || return 1
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
    for cmd in apt-get dnf yum curl wget gpg tar systemctl caddy; do
        if xmg_cmd_exists "$cmd"; then
            echo "$cmd: $(command -v "$cmd")"
        else
            echo "$cmd: 未检测到"
        fi
    done

    echo
    echo "[Caddy 版本]"
    if xmg_caddy_binary_exists; then
        xmg_caddy_print_version || echo "无法获取 caddy version"
    else
        echo "caddy 未安装"
    fi

    echo
    echo "[Cloudflare WARP APT 源检测]"
    grep -R "pkg.cloudflareclient.com" \
        /etc/apt/sources.list \
        /etc/apt/sources.list.d \
        2>/dev/null || echo "未检测到 Cloudflare WARP APT 源"

    echo
    echo "[Caddy APT 源文件]"
    if [ -f "$XMG_CADDY_APT_SOURCE_PATH" ]; then
        echo "存在：$XMG_CADDY_APT_SOURCE_PATH"
        sed -n '1,20p' "$XMG_CADDY_APT_SOURCE_PATH"
    else
        echo "不存在：$XMG_CADDY_APT_SOURCE_PATH"
    fi

    echo
    echo "[Caddy APT keyring]"
    if [ -f "$XMG_CADDY_KEYRING_PATH" ]; then
        echo "存在：$XMG_CADDY_KEYRING_PATH"
        ls -l "$XMG_CADDY_KEYRING_PATH"
    else
        echo "不存在：$XMG_CADDY_KEYRING_PATH"
    fi

    echo
    echo "[Caddy 二进制路径]"
    if [ -x "$XMG_CADDY_BINARY_INSTALL_PATH" ]; then
        ls -l "$XMG_CADDY_BINARY_INSTALL_PATH"
    else
        echo "不存在：$XMG_CADDY_BINARY_INSTALL_PATH"
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
        echo "  - 安装时会优先使用系统包管理器"
        echo "  - 如果 WARP APT 源阻塞 apt update，会临时绕过"
        echo "  - 如果包管理器安装失败，会尝试 GitHub 官方二进制安装"
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

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    xmg_caddy_menu
fi
