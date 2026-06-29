#!/usr/bin/env bash

[ "${XMG_COMMON_SH_LOADED:-0}" = "1" ] && return 0
XMG_COMMON_SH_LOADED=1

XMG_ETC_DIR="${XMG_ETC_DIR:-/etc/xmg}"
XMG_RUN_DIR="${XMG_RUN_DIR:-/run/xmg}"
XMG_LOG_DIR="${XMG_LOG_DIR:-/var/log/xmg}"
XMG_BACKUP_DIR="${XMG_BACKUP_DIR:-/var/backups/xmg}"
XMG_WWW_DIR="${XMG_WWW_DIR:-/var/www/xmg}"
XMG_COLOR="${XMG_COLOR:-auto}"

xmg_has_tty() {
    [ -t 1 ]
}

xmg_color_enabled() {
    case "$XMG_COLOR" in
        always) return 0 ;;
        never) return 1 ;;
        auto) xmg_has_tty ;;
        *) xmg_has_tty ;;
    esac
}

# ===== 替换原有的 xmg_c / xmg_reset，新增颜色缓存 =====
# 位置：在 XMG_COLOR 变量定义之后，xmg_info 函数之前

# 颜色转义序列缓存变量（初始化后直接引用，避免 $() fork）
XMG_C_RESET=""
XMG_C_BOLD=""
XMG_C_RED=""
XMG_C_GREEN=""
XMG_C_YELLOW=""
XMG_C_CYAN=""

xmg_color_init() {
    # 初始化颜色缓存，只在启动时调用一次
    if xmg_color_enabled; then
        XMG_C_RESET=$'\033[0m'
        XMG_C_BOLD=$'\033[1m'
        XMG_C_RED=$'\033[31m'
        XMG_C_GREEN=$'\033[32m'
        XMG_C_YELLOW=$'\033[33m'
        XMG_C_CYAN=$'\033[36m'
    else
        XMG_C_RESET=""
        XMG_C_BOLD=""
        XMG_C_RED=""
        XMG_C_GREEN=""
        XMG_C_YELLOW=""
        XMG_C_CYAN=""
    fi
}

# 保留原函数供非热路径使用（如 install.sh 等一次性脚本）
xmg_c() {
    local code="$1"
    if xmg_color_enabled; then
        printf '\033[%sm' "$code"
    fi
}

xmg_reset() {
    if xmg_color_enabled; then
        printf '\033[0m'
    fi
}

# 优化后的日志函数，使用缓存变量避免 $() fork
xmg_info() {
    printf '%s[INFO]%s %s\n' "$XMG_C_GREEN" "$XMG_C_RESET" "$*"
}

xmg_warn() {
    printf '%s[WARN]%s %s\n' "$XMG_C_YELLOW" "$XMG_C_RESET" "$*" >&2
}

xmg_error() {
    printf '%s[ERROR]%s %s\n' "$XMG_C_RED" "$XMG_C_RESET" "$*" >&2
}

xmg_info() {
    printf '%s[INFO]%s %s\n' "$(xmg_c 32)" "$(xmg_reset)" "$*"
}

xmg_warn() {
    printf '%s[WARN]%s %s\n' "$(xmg_c 33)" "$(xmg_reset)" "$*" >&2
}

xmg_error() {
    printf '%s[ERROR]%s %s\n' "$(xmg_c 31)" "$(xmg_reset)" "$*" >&2
}

xmg_die() {
    xmg_error "$*"
    exit 1
}

xmg_cmd_exists() {
    command -v "$1" >/dev/null 2>&1
}

xmg_require_bash() {
    if [ -z "${BASH_VERSION:-}" ]; then
        echo "错误: 需要 bash 运行" >&2
        exit 1
    fi
}

xmg_is_root() {
    [ "${EUID:-$(id -u)}" -eq 0 ]
}

xmg_require_root() {
    xmg_is_root || xmg_die "此操作需要 root 权限，请使用 sudo 或 root 用户执行"
}

xmg_mkdirs() {
    mkdir -p \
        "$XMG_ETC_DIR" \
        "$XMG_RUN_DIR" \
        "$XMG_LOG_DIR" \
        "$XMG_BACKUP_DIR" \
        "$XMG_WWW_DIR"
}

xmg_pause() {
    printf '\n按 Enter 返回...'
    # shellcheck disable=SC2162
    read _
}

xmg_confirm() {
    local prompt="${1:-确认继续?}"
    local ans=""

    printf '%s [y/N]: ' "$prompt"
    read -r ans || return 1

    case "$ans" in
        y|Y|yes|YES) return 0 ;;
        *) return 1 ;;
    esac
}

xmg_timestamp() {
    date '+%Y%m%d-%H%M%S'
}

xmg_backup_file() {
    local file="$1"
    local base=""
    local dst=""

    [ -e "$file" ] || return 0

    xmg_mkdirs
    base="$(basename "$file")"
    dst="$XMG_BACKUP_DIR/${base}.$(xmg_timestamp).bak"

    cp -a "$file" "$dst" || return 1
    xmg_info "已备份: $file -> $dst"
}

xmg_systemctl() {
    local action="$1"
    local service="$2"

    xmg_require_root

    if ! xmg_cmd_exists systemctl; then
        xmg_die "当前系统未发现 systemctl，可能不是 systemd 系统"
    fi

    case "$action" in
        start|stop|restart|reload|enable|disable|status|is-active|is-enabled)
            systemctl "$action" "$service"
            ;;
        *)
            xmg_die "非法 systemctl 操作: $action"
            ;;
    esac
}
