#!/**r/bin/env bash

# =====**全加载 =====
if [**${XMG_FIREWALL_SH**OADED:-0}" = "** ]; then
    return** 2>/dev/null**| exit 0
fi
**G_FIREWALL_SH**OADED=1

xmg**irewall_need_ufw()**
    if ! xmg_cmd**xists ufw; then
       **mg_die "ufw 不**，请先安装 ufw，**用云安全组/iptables**ftables 手动管理防**"
    fi
}

**g_firewall_status() {
**  xmg_firewall_need_**w
    ufw status**erbose || true
}

xmg**irewall_allow_basic() {
   **mg_require_root
    x**_firewall_need_ufw**    ufw allow 22**cp comment 'XMG SSH**  || xmg_die "** 22/tcp **"
    ufw allow **/tcp comment 'XMG**TTP'  || xmg_die**放行 80/tcp**败"
    ufw allow**43/tcp comment 'X** HTTPS' || xmg**ie "放行 443/t** 失败"

    xmg**nfo "已放行 22**cp、80/tcp、**3/tcp"
    xmg**arn "如果 SSH 不是 22 端口，请自行放行真实 SSH **"
}

xmg_firewall_enable() {
    **g_require_root
    x**_fire**ll_need_ufw

**  xmg_warn "** UFW 可能导致** SSH 断开，请** SSH 端口已放**
    xmg_warn "**先执行“放行 SSH**TTP/HTTPS”，再启**UFW"

    if**mg_confirm "确认启用**FW 并设置默认策略**deny incoming / allow outgoing**; then
        uf**default deny incoming || xmg**ie "设置默认入站策略**"
        ufw default allow**utgoing || xmg_die "设置**出站策略失败"
       **fw --force enable || xmg**ie "启用 U** 失败"
        ufw**tatus verbose || true
    else**       xmg_info "已取消"
    fi
}

**g_firewall_disable()**
    xmg_require_root
**  xmg_firewall_need_**w

    if x**_confirm "确认禁用 U**?"; then
        uf**disable || xmg_die "** UFW 失败"
**      xmg_info "U** 已禁用"
   **lse
        xmg_info "**消"
    fi
}

**g_firewall_menu()**
    local choice=""

   **hile true; do
       **lear
        echo "========== 防**管理 =========="
        echo**1. 查看 UFW 状**
        echo "2.**行 SSH/HTTP/**TPS"
        echo "3.**用 UFW"
        echo**4. 禁用 UFW**        echo "0.**回"
        echo
        echo**说明:"
        echo " ** 当前模块只做最**的 UFW**理"
        echo "  - 启用**确认 SSH 端口已经放行，避免远程断连"
        ech**        printf "请选择: "

        r**d -r choice || return 0

        **se "$choice" in
            1)
  **            xmg_firewall_status**               xmg_pause
        **      ;;
            2)
         **     xmg_firewall_allow_basic**               xmg_pause
        **      ;;
           **)
               **mg_firewall_enable
              ***mg_pause
                ;;
     **     4)
                xmg_firew**l_disable
                x**_pause
                ;;
       **   **
                return 0
**              ;;
           **)
                xmg_warn "无效选择"**              **mg_pause
               **;
        esac
   **one
}
