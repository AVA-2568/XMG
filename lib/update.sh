#!/usr/bin/env bash

[ "${XMG_UPDATE_SH_LOADED:-0}" = "1" ] && return 0
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
}

xmg_update_check_files() {
    local missing=0
    local f=""

    echo "检查 XMG 文件完整性"
    echo "===================="
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

    tmp="$(mktemp)"
    [ -n "$tmp" ] || xmg_die "创建临时文件失败"

    if ! curl -fsSL "$url" -o "$tmp"; then
        rm -f "$tmp"
        xmg_die "下载失败: $url"
    fi

    if [ ! -s "$tmp" ]; then
        rm -f "$tmp"
        xmg_die "下载结果为空: $url"
    fi

    install -m "$mode" -o root -g root "$tmp" "$dst"
    rm -f "$tmp"
}

xmg_update_from_github() {
    xmg_require_root

    local f=""

    xmg_warn "将从 GitHub Raw 更新 XMG 文件"
    echo "源: $XMG_REPO_RAW"
    echo

    if ! xmg_confirm "确认更新?"; then
        xmg_info "已取消"
        return 0
    fi

    xmg_mkdirs
    mkdir -p "$XMG_LIB_DIR"
    mkdir -p "$(dirname "$XMG_BIN_PATH")"

    if [ -e "$XMG_BIN_PATH" ] || [ -L "$XMG_BIN_PATH" ]; then
        xmg_backup_file "$XMG_BIN_PATH"
    fi

    xmg_update_download "$XMG_REPO_RAW/xmg" "$XMG_BIN_PATH" 0755

    while IFS= read -r f; do
        if [ -e "$XMG_LIB_DIR/$f" ] || [ -L "$XMG_LIB_DIR/$f" ]; then
            xmg_backup_file "$XMG_LIB_DIR/$f"
        fi

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
        printf "请选择: "

        read -r choice || return 0

        case "$choice" in
            1) xmg_update_version; xmg_pause ;;
            2) xmg_update_check_files; xmg_pause ;;
            3) xmg_update_from_github; xmg_pause ;;
            0) return 0 ;;
            *) xmg_warn "无效选择"; xmg_pause ;;
        esac
    done
}
