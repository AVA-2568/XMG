#!/usr/bin/env bash

[ "${XMG_FIREWALL_SH_LOADED:-0}" = "1" ] && return 0
XMG_FIREWALL_SH_LOADED=1

xmg_firewall_need_ufw() {
    if ! xmg_cmd_exists ufw; then
        xmg_die "ufw 不存在，请先安装 ufw，或使用云安全组/iptables/nftables 手动管理防火墙"
    fi
}

xmg_firewall_status() {
    xmg_firewall_need_ufw
    ufw status verbose || true
}

xmg_firewall_allow_basic() {
    xmg_require_root
    xmg_firewall_need_ufw

    ufw allow 22/tcp comment 'XMG SSH'
    ufw allow 80/tcp comment 'XMG HTTP'
    ufw allow 443/tcp comment 'XMG HTTPS'

    xmg_info "已放行 22/tcp、80/tcp、443/tcp"
    xmg_warn "如果 SSH 不是 22 端口，请自行放行真实 SSH 端口"
}

xmg_firewall_enable() {
    xmg_require_root
    xmg_firewall_need_ufw

    xmg_warn "启用 UFW 可能导致远程 SSH 断开，请确认端口已放行"

    if xmg_confirm "确认启用 UFW?"; then
        ufw --force enable
        ufw status verbose || true
    else
        xmg_info "已取消"
    fi
}

xmg_firewall_disable() {
    xmg_require_root
    xmg_firewall_need_ufw

    if xmg_confirm "确认禁用 UFW?"; then
        ufw disable
    else
        xmg_info "已取消"
    fi
}

xmg_firewall_menu() {
    local choice=""

    while true; do
        clear
        echo "========== 防火墙管理 =========="
        echo "1. 查看 UFW 状态"
        echo "2. 放行 SSH/HTTP/HTTPS"
        echo "3. 启用 UFW"
        echo "4. 禁用 UFW"
        echo "0. 返回"
        echo
        printf "请选择: "

        read -r choice || return 0

        case "$choice" in
            1) xmg_firewall_status; xmg_pause ;;
            2) xmg_firewall_allow_basic; xmg_pause ;;
            3) xmg_firewall_enable; xmg_pause ;;
            4) xmg_firewall_disable; xmg_pause ;;
            0) return 0 ;;
            *) xmg_warn "无效选择"; xmg_pause ;;
        esac
    done
}
