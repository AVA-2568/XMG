#!/u**/bin/env bash

# ===== 安全加载 =====**f [ "${XMG_UNINSTALL_SH_LOADED:-0** = "1" ]; then
    return 0 2>/de**null || exit 0
fi
XMG_UN**STALL_SH_LOADED=1

# 注意：
# 不默认使用 **G_LIB_DIR，避免源码目录测试时：
#   XMG_LIB**IR=./lib ./xmg menu
# 误删当前源码 lib。**MG**IN_PATH="${XMG_BIN_PATH:-/usr/loc**/bin/xmg}"
XMG_LIB_INSTALL_DIR="$**MG_LIB_INSTALL_DIR:-/usr/local/li**xmg}"

XMG_UNINSTALL_DONE=0

xmg_**install_require_absolute() {
    **cal path="$1"

    case "$path" i**        /*)
            return 0
**          ;;
        *)
         ** xmg_die "拒绝操作非绝对路径: $path"
     **     ;;
    esac
}

xmg_uninstall**eject_path_traversal() {
    loca**path="$1"

    case "$path" in
  **    *"/../"*|*"/.."|".."|"**/"*)
            xmg_die "拒绝包含**穿越的路径: $path"
            ;;
    **ac
}

xmg_uninstall_reject_danger**s_path() {
    local path="$1"

 ** case "$path" in
        ""|"/"|"***n"|"/sbin"|"/lib**"/lib64"|"/usr"|"/usr/bin"|"/usr/***n"|"/usr/local"|"/etc"|"/var"|"/v**/www"|"/var/log"|"/var/backups"|"**un"|"/**p"|"/home"|"/home/"*)
           **mg_die "拒绝删除危险路径: $path"
        **  ;;
    esac
}

xmg_uninstall_va**date_path() {
    local path="$1"**    xmg_uninstall_require_absolut**"$path"
    xmg_uninstall_reject_**th_traversal "$path"
    xmg_unin**all_reject_dangerous_path "$path"**

xmg_uninstall_safe_rm_rf() {
  **local path="$1"

    xmg_uninstal**validate_path "$path"

    if [ -**"$path" ] || [ -L "$path" ]; then**       rm -rf --one-file-system -**"$path" || xmg_die "删除失败: $path"
**      xmg_info "已删除: $path"
    e**e
        xmg_warn "不存在，跳过: $path**    fi
}

xmg_uninstall_safe_rm_f** {
    local path="$1"

    xmg_u**nstall_validate_path "$path"

   **f [ -d "$path" ] && [ ! -L "$path**]; then
        xmg_die "目标是目录，拒绝**件删除: $path"
    fi

    if [ -e "**ath" ] || [ -L "$path" ]; then
  **    rm -f -- "$path" || xmg_die "**失败: $path"
        xmg_info "已删除:**path"
    else
        xmg_warn "**在，跳过: $path"
    fi
}

xmg_uninst**l_print_program_only_plan() {
   **lear
    echo "XMG 卸载：仅删除程序文件"
  **echo "========================="
**  echo
    echo "将删除:"
    echo "**$XMG_BIN_PATH"
    echo "  $XMG_L**_INSTALL_DIR"
    echo
    echo "**删除:"
    echo "  $XMG_ETC_DIR"
  **echo "  $XMG_RUN_DIR"
    echo " **XMG_WWW_DIR"
    echo "  $XMG_LOG**IR"
    echo "  $XMG_BACKUP_DIR"
**  echo
    echo "不会卸载:"
    echo ** xray"
    echo "  caddy"
    ech**"  ufw"
    echo
}

xmg_uninstall**rint_all_plan() {
    clear
    e**o "XMG 卸载：删除程序和 XMG 数据"
    echo **============================"
   **cho
    echo "将删除:"
    echo "  $**G_BIN_PATH"
    echo "  $XMG_LIB_**STALL_DIR"
    echo "  $XMG_ETC_D**"
    echo "  $XMG_RUN_DIR"
    e**o "  $XMG_WWW_DIR"
    echo "  $X**_LOG_DIR"
    echo "  $XMG_BACKUP**IR"
    echo
    echo "不会卸载:"
   **cho "  xray"
    echo "  caddy"
 ** echo "  ufw"
    echo
}

xmg_uni**tall_program_only() {
    xmg_req**re_root
    XMG_UNINSTALL_DONE=0
**   xmg_uninstall_print_program_on**_plan

    if ! xmg_confirm "确认仅删**XMG 程序文件?"; then
        xmg_info**已取消"
        return 0
    fi

   **mg_uninstall_safe_rm_f "$XMG_BIN_**TH"
    xmg_uninstall_safe_rm_rf **XMG_LIB_INSTALL_DIR"

    XMG_UNI**TALL_DONE=1
    xmg_info "XMG 程序文**卸载"
}

xmg_uninstall_all() {
    **g_require_root
    XMG_UNINSTALL_**NE=0

    xmg_uninstall_print_all**lan

    if ! xmg_confirm "确认删除 X** 程序和 XMG 数据?"; then
        xmg_i**o "已取消"
        return 0
    fi

**  xmg_uninstall_safe_rm_f "$XMG_B**_PATH"
    xmg_uninstall_safe_rm_** "$XMG_LIB_INSTALL_DIR"
    xmg_u**nstall_safe_rm_rf "$XMG_ETC_DIR"
**  xmg_uninstall_safe_rm_rf "$XMG_**N_DIR"
    xmg_uninstall_safe_rm_** "$XMG_WWW_DIR"
    xmg_uninstall**afe_rm_rf "$XMG_LOG_DIR"
    xmg_**install_safe_rm_rf "$XMG_BACKUP_D**"

    XMG_UNINSTALL_DONE=1
    x**_info "XMG 程序和数据已卸载"
}

xmg_unins**ll_after_done() {
    if [ "${XMG**NINSTALL_DONE:-0}" = "1" ]; then
**      echo
        xmg_warn "XMG **已被删除，建议退出当前 XMG 会话"
        xmg_p**se
        clear
        exit 0
 ** fi
}

xmg_uninstall_menu() {
   **ocal choice=""

    while true; d**        clear
        echo "=====**=== XMG 卸载 =========="
        ec** "1. 仅卸载 XMG 程序文件"
        echo "** 卸载 XMG 程序文件和 XMG 数据"
        ech**"0. 返回"
        echo
        echo**说明:"
        echo "  - 本卸载器只删除 XM**自身文件"
        echo "  - 不会卸载 xray**addy/ufw"
        echo "  - 如果站点或**仍需保留，请选择 1"
        echo
        **intf "请选择: "

        read -r cho**e || return 0

        case "$cho**e" in
            1)
            **  xmg_uninstall_program_only
    **          xmg_uninstall_after_don**                xmg_pause
       **       ;;
            2)
        **      xmg_uninstall_all
         **     xmg_uninstall_after_done
   **           xmg_pause
            **  ;;
            0)
             ** return 0
                ;;
    **      *)
                xmg_warn**无效选择"
                xmg_pause
 **             ;;
        esac
    **ne
}
