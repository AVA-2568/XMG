#!/usr/bin/env bash

[ "${XMG_XRAY_SH_LOADED:-0}" = "1" ] && return 0
XMG_XRAY_SH_LOADED=1

XMG_XRAY_SERVICE="${XMG_XRAY_SERVICE:-xray}"
XMG_XRAY_INSTALL_SCRIPT_URL="${XMG_XRAY_INSTALL_SCRIPT_URL:-https://raw.githubusercontent.com/XTLS/Xray-install/main/install-release.sh}"

xmg_xray_binary_exists() {
    xmg_cmd_exists xray
}

xmg_xray_service_exists() {
    xmg_cmd_exists systemctl || return 1
    systemctl list-unit-files 2>/dev/null | awk '{print $1}' | grep -qx "${XMG_XRAY_SERVICE}.service"
}

xmg_xray_fetch_install_script() {
    local tmp=""

    xmg_require_root

    if ! xmg_cmd_exists curl; then
        xmg_die "curl 不存在，无法下载 Xray 安装脚本"
    fi

    tmp="$(mktemp)"
    [ -n "$tmp" ] || xmg_die "创建临时文件失败"

    if ! curl -fsSL "$XMG_XRAY_INSTALL_SCRIPT_URL" -o "$tmp"; then
        rm -f "$tmp"
        xmg_die "下载 Xray 安装脚本失败"
    fi

    if [ ! -s "$tmp" ]; then
        rm -f "$tmp"
        xmg_die "下载到的 Xray 安装脚本为空"
    fi

    chmod +x "$tmp"
    printf '%s\n' "$tmp"
}

xmg_xray_install_update() {
    local script=""

    xmg_require_root

    if xmg_xray_binary_exists; then
        xmg_warn "检测到 Xray 已存在，本操作将执行安装/更新"
        if ! xmg_confirm "是否继续?"; then
            xmg_info "已取消"
            return 0
        fi
    fi

    script="$(xmg_xray_fetch_install_script)"

    xmg_info "开始安装/更新 Xray..."

    if ! bash "$script" install; then
        rm -f "$script"
        xmg_die "Xray 安装/更新失败"
    fi

    if ! bash "$script" install-geodata; then
        xmg_warn "Xray geodata 安装/更新失败，可由用户后续自行处理"
    fi

    rm -f "$script"

    xmg_info "Xray 安装/更新完成"
    xmg_warn "XMG 不处理 Xray 配置文件，请用户自行维护配置"
}

# 兼容旧调用名
xmg_xray_install() {
    xmg_xray_install_update
}

xmg_xray_uninstall() {
    local script=""

    xmg_require_root

    if ! xmg_xray_binary_exists && ! xmg_xray_service_exists; then
        xmg_warn "未检测到 Xray 已安装"
        return 0
    fi

    xmg_warn "即将卸载 Xray"
    xmg_warn "XMG 不负责备份或删除用户自定义 Xray 配置文件"

    if ! xmg_confirm "确认卸载 Xray?"; then
        xmg_info "已取消"
        return 0
    fi

    script="$(xmg_xray_fetch_install_script)"

    if ! bash "$script" remove; then
        rm -f "$script"
        xmg_die "Xray 卸载失败"
    fi

    rm -f "$script"

    xmg_info "Xray 已卸载"
}

xmg_xray_start() {
    xmg_systemctl start "$XMG_XRAY_SERVICE"
    xmg_info "Xray 已启动"
}

xmg_xray_stop() {
    xmg_systemctl stop "$XMG_XRAY_SERVICE"
    xmg_info "Xray 已停止"
}

xmg_xray_restart() {
    xmg_systemctl restart "$XMG_XRAY_SERVICE"
    xmg_info "Xray 已重启"
}

xmg_xray_status() {
    if ! xmg_cmd_exists systemctl; then
        xmg_warn "systemctl 不存在，无法查看 Xray 状态"
        return 1
    fi

    systemctl status "$XMG_XRAY_SERVICE" --no-pager || true
}

xmg_xray_logs() {
    clear
    echo "========== Xray 日志 =========="
    echo

    if xmg_cmd_exists journalctl; then
        journalctl -u "$XMG_XRAY_SERVICE" -n 80 --no-pager 2>/dev/null || true
        return 0
    fi

    xmg_warn "journalctl 不存在，无法查看 Xray 日志"
}

xmg_xray_menu() {
    local choice=""

    while true; do
        clear
        echo "========== Xray 管理 =========="
        echo "1. 安装/更新 Xray"
        echo "2. 卸载 Xray"
        echo "3. 启动 Xray"
        echo "4. 停止 Xray"
        echo "5. 重启 Xray"
        echo "6. 查看 Xray 状态"
        echo "7. 查看 Xray 日志"
        echo "0. 返回"
        echo
        echo "说明: XMG 只管理 Xray 服务生命周期，不创建/编辑/校验 Xray 配置文件。"
        echo
        printf "请选择: "

        read -r choice || return 0

        case "$choice" in
            1)
                xmg_xray_install_update
                xmg_pause
                ;;
            2)
                xmg_xray_uninstall
                xmg_pause
                ;;
            3)
                xmg_xray_start
                xmg_pause
                ;;
            4)
                xmg_xray_stop
                xmg_pause
                ;;
            5)
                xmg_xray_restart
                xmg_pause
                ;;
            6)
                xmg_xray_status
                xmg_pause
                ;;
            7)
                xmg_xray_logs
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
