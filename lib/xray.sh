#!/usr/bin/env bash
#
# xray.sh - Xray 安装和配置管理
#

install_xray() {
    info "开始安装 Xray..."

    install_base_deps

    if command -v xray >/dev/null 2>&1; then
        ok "Xray 已安装"
        xray version || true
        return 0
    fi

    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

    systemctl enable xray || true

    ok "Xray 安装完成"
    xray version || true
}

uninstall_xray() {
    warn "即将卸载 Xray，默认保留配置目录"

    if confirm "确认卸载 Xray?"; then
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove || true
        ok "Xray 已卸载"
    else
        warn "已取消"
    fi
}

create_empty_xray_config() {
    mkdir -p "$(dirname "${XRAY_CONFIG}")" /var/log/xray

    if [[ -f "${XRAY_CONFIG}" ]]; then
        backup_file "${XRAY_CONFIG}"
        warn "Xray 配置已存在，已先备份"
    fi

    if [[ ! -f "${XRAY_CONFIG}" ]]; then
        cat > "${XRAY_CONFIG}" <<'EOF'
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
EOF
        ok "已创建基础 Xray 配置：${XRAY_CONFIG}"
    else
        ok "Xray 配置已存在：${XRAY_CONFIG}"
    fi
}

edit_xray_config() {
    mkdir -p "$(dirname "${XRAY_CONFIG}")"

    if [[ ! -f "${XRAY_CONFIG}" ]]; then
        create_empty_xray_config
    fi

    backup_file "${XRAY_CONFIG}"
    "${EDITOR:-nano}" "${XRAY_CONFIG}"

    if jq empty "${XRAY_CONFIG}" >/dev/null 2>&1; then
        ok "JSON 语法检查通过"

        if command -v xray >/dev/null 2>&1; then
            xray test -config "${XRAY_CONFIG}" || warn "xray test 未通过，请检查配置内容"
            systemctl restart xray || true
        fi
    else
        err "JSON 语法错误，请修复后再重启 Xray"
    fi
}

check_xray_config() {
    if [[ ! -f "${XRAY_CONFIG}" ]]; then
        err "Xray 配置不存在：${XRAY_CONFIG}"
        return 1
    fi

    jq empty "${XRAY_CONFIG}"

    if command -v xray >/dev/null 2>&1; then
        xray test -config "${XRAY_CONFIG}"
    fi
}

reload_xray() {
    check_xray_config
    systemctl restart xray
    ok "Xray 已重启"
}

xray_menu() {
    while true; do
        clear
        echo "========== Xray 管理 =========="
        echo "1. 安装 Xray"
        echo "2. 卸载 Xray"
        echo "3. 启动 Xray"
        echo "4. 停止 Xray"
        echo "5. 重启 Xray"
        echo "6. 查看 Xray 状态"
        echo "7. 创建基础 Xray 配置"
        echo "8. 编辑 Xray 配置"
        echo "9. 校验 Xray 配置"
        echo "10. 查看 Xray 日志"
        echo "0. 返回"
        echo
        read -rp "请选择: " choice

        case "${choice}" in
            1) install_xray; pause ;;
            2) uninstall_xray; pause ;;
            3) systemctl start xray; pause ;;
            4) systemctl stop xray; pause ;;
            5) systemctl restart xray; pause ;;
            6) systemctl status xray --no-pager; pause ;;
            7) create_empty_xray_config; pause ;;
            8) edit_xray_config; pause ;;
            9) check_xray_config; pause ;;
            10) journalctl -u xray -n 100 --no-pager; pause ;;
            0) break ;;
            *) warn "无效选择"; pause ;;
        esac
    done
}
