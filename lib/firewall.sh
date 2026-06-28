#!/usr/bin/env bash
#
# firewall.sh - 简单防火墙管理
#

install_ufw_if_needed() {
    if ! command -v ufw >/dev/null 2>&1; then
        apt-get update
        apt-get install -y ufw
    fi
}

open_common_ports() {
    install_ufw_if_needed

    ufw allow 22/tcp || true
    ufw allow 80/tcp || true
    ufw allow 443/tcp || true

    ok "已放行 22/80/443 TCP"
}

open_custom_port() {
    local port

    read -rp "请输入要开放的 TCP 端口: " port

    if ! [[ "${port}" =~ ^[0-9]+$ ]]; then
        err "端口必须是数字"
        return 1
    fi

    if (( port < 1 || port > 65535 )); then
        err "端口范围必须是 1-65535"
        return 1
    fi

    install_ufw_if_needed
    ufw allow "${port}/tcp"

    ok "已放行 TCP 端口：${port}"
}

show_firewall_status() {
    if command -v ufw >/dev/null 2>&1; then
        ufw status numbered
    else
        warn "ufw 未安装"
    fi
}

enable_ufw() {
    install_ufw_if_needed
    ufw enable
}

firewall_menu() {
    while true; do
        clear
        echo "========== 防火墙管理 =========="
        echo "1. 放行 22/80/443"
        echo "2. 放行自定义 TCP 端口"
        echo "3. 查看防火墙状态"
        echo "4. 启用 ufw"
        echo "0. 返回"
        echo
        read -rp "请选择: " choice

        case "${choice}" in
            1) open_common_ports; pause ;;
            2) open_custom_port; pause ;;
            3) show_firewall_status; pause ;;
            4) enable_ufw; pause ;;
            0) break ;;
            *) warn "无效选择"; pause ;;
        esac
    done
}
