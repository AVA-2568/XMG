#!/usr/bin/env bash
# shellcheck shell=bash
# coding: utf-8
#
# update.sh - XMG 更新与版本检查模块
#
# 说明：
#   - 本模块只更新 XMG 自身文件
#   - 不修改 xray / caddy / ufw 配置
#   - 不修改站点目录
#   - 从 GitHub Raw 更新时要求安装目标为绝对路径
#   - 文件内容应使用 UTF-8 编码保存
#

# update.sh 是 Bash 库文件，明确拒绝非 Bash 宿主
if [ -z "${BASH_VERSION:-}" ]; then
    echo "update.sh: requires bash" >&2
    return 1 2>/dev/null || exit 1
fi

# ===== 安全加载 =====
if [ "${XMG_UPDATE_SH_LOADED:-0}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi
XMG_UPDATE_SH_LOADED=1

XMG_REPO_RAW="${XMG_REPO_RAW:-https://raw.githubusercontent.com/AVA-2568/xmg/main}"
XMG_BIN_PATH="${XMG_BIN_PATH:-/usr/local/bin/xmg}"

xmg_update_required_files() {
    cat <<EOF
common.sh
system.sh
monitor.sh
menu.sh
caddy.sh
xray.sh
site.sh
firewall.sh
update.sh
uninstall.sh
EOF
}

xmg_update_version() {
    echo "XMG_VERSION=${XMG_VERSION:-unknown}"
    echo "XMG_LIB_DIR=$XMG_LIB_DIR"
    echo "XMG_REPO_RAW=$XMG_REPO_RAW"
    echo "XMG_BIN_PATH=$XMG_BIN_PATH"
}

xmg_update_is_abs_path() {
    local path="$1"

    case "$path" in
        /*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

xmg_update_reject_path_traversal() {
    local path="$1"

    case "$path" in
        *"/../"*|*"/.."|".."|"../"*)
            xmg_die "拒绝包含路径穿越的路径: $path"
            ;;
    esac
}

xmg_update_reject_dangerous_path() {
    local path="$1"

    case "$path" in
        ""|"/"|"/bin"|"/sbin"|"/lib"|"/lib64"|"/usr"|"/usr/bin"|"/usr/sbin"|"/usr/local"|"/etc"|"/var"|"/var/www"|"/var/log"|"/var/backups"|"/run"|"/tmp"|"/home"|"/home/"*)
            xmg_die "拒绝使用危险更新目标路径: $path"
            ;;
    esac
}

xmg_update_require_install_paths_safe() {
    if ! xmg_update_is_abs_path "$XMG_BIN_PATH"; then
        xmg_die "更新目标 XMG_BIN_PATH 必须是绝对路径: $XMG_BIN_PATH"
    fi

    if ! xmg_update_is_abs_path "$XMG_LIB_DIR"; then
        xmg_die "更新目标 XMG_LIB_DIR 必须是绝对路径: $XMG_LIB_DIR"
    fi

    xmg_update_reject_path_traversal "$XMG_BIN_PATH"
    xmg_update_reject_path_traversal "$XMG_LIB_DIR"

    # 这里不能把 /usr/local/bin/xmg 和 /usr/local/lib/xmg 拒绝掉，
    # 但要拒绝其父级危险目录。
    xmg_update_reject_dangerous_path "$XMG_BIN_PATH"
    xmg_update_reject_dangerous_path "$XMG_LIB_DIR"
}

xmg_update_check_files() {
    local missing=0
    local f=""

    echo "检查 XMG 文件完整性"
    echo "=================="
    echo

    if [ -x "$XMG_BIN_PATH" ] || [ -f "$XMG_BIN_PATH" ]; then
        echo "[OK]   $XMG_BIN_PATH"
    else
        echo "[MISS] $XMG_BIN_PATH"
        missing=$((missing + 1))
    fi

    while IFS= read -r f; do
        if [ -r "$XMG_LIB_DIR/$f" ]; then
            echo "[OK]   $XMG_LIB_DIR/$f"
        else
            echo "[MISS] $XMG_LIB_DIR/$f"
            missing=$((missing + 1))
        fi
    done < <(xmg_update_required_files)

    echo

    if [ "$missing" -eq 0 ]; then
        xmg_info "文件检查通过"
        return 0
    fi

    xmg_warn "缺失 $missing 个文件"
    return 1
}

xmg_update_download() {
    local url="$1"
    local dst="$2"
    local mode="${3:-0644}"
    local tmp=""

    xmg_cmd_exists curl || xmg_die "curl 不存在，无法更新"
    xmg_cmd_exists install || xmg_die "install 命令不存在，无法更新"

    tmp="$(mktemp)" || xmg_die "创建临时文件失败"

    xmg_update_cleanup_tmp() {
        if [ -n "${tmp:-}" ] && [ -e "$tmp" ]; then
            rm -f -- "$tmp"
        fi
    }
    trap xmg_update_cleanup_tmp RETURN

    if ! curl -fsSL "$url" -o "$tmp"; then
        xmg_die "下载失败: $url"
    fi

    if [ ! -s "$tmp" ]; then
        xmg_die "下载结果为空: $url"
    fi

    if ! install -m "$mode" -o root -g root "$tmp" "$dst"; then
        xmg_die "安装更新文件失败: $dst"
    fi
}

xmg_update_backup_if_exists() {
    local path="$1"

    if [ -e "$path" ] || [ -L "$path" ]; then
        xmg_backup_file "$path" || xmg_die "备份失败: $path"
    fi
}

xmg_update_prepare_dirs() {
    xmg_mkdirs

    mkdir -p "$XMG_LIB_DIR" || xmg_die "创建库目录失败: $XMG_LIB_DIR"
    mkdir -p "$(dirname "$XMG_BIN_PATH")" || xmg_die "创建命令目录失败: $(dirname "$XMG_BIN_PATH")"
}

xmg_update_from_github() {
    local f=""

    xmg_require_root
    xmg_update_require_install_paths_safe

    xmg_warn "将从 GitHub Raw 更新 XMG 文件"
    echo "源: $XMG_REPO_RAW"
    echo "目标命令: $XMG_BIN_PATH"
    echo "目标库目录: $XMG_LIB_DIR"
    echo

    if ! xmg_confirm "确认更新?"; then
        xmg_info "已取消"
        return 0
    fi

    xmg_update_prepare_dirs

    xmg_update_backup_if_exists "$XMG_BIN_PATH"
    xmg_update_download "$XMG_REPO_RAW/xmg" "$XMG_BIN_PATH" 0755

    while IFS= read -r f; do
        xmg_update_backup_if_exists "$XMG_LIB_DIR/$f"
        xmg_update_download "$XMG_REPO_RAW/lib/$f" "$XMG_LIB_DIR/$f" 0644
    done < <(xmg_update_required_files)

    xmg_info "更新完成"
    xmg_update_check_files || true
}

xmg_update_menu() {
    local choice=""

    while true; do
        clear
        echo "========== 更新 / 版本 =========="
        echo "1. 显示版本"
        echo "2. 检查本地文件完整性"
        echo "3. 从 GitHub 更新"
        echo "0. 返回"
        echo
        echo "说明:"
        echo "  - 更新只覆盖 XMG 自身文件"
        echo "  - 不修改 xray/caddy/ufw 配置"
        echo "  - 不修改站点目录"
        echo "  - 从 GitHub 更新要求安装目标为绝对路径"
        echo
        printf "请选择: "

        read -r choice || return 0

        case "$choice" in
            1)
                xmg_update_version
                xmg_pause
                ;;
            2)
                xmg_update_check_files
                xmg_pause
                ;;
            3)
                xmg_update_from_github
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
