#!/usr/bin/env bash

[ "${XMG_UNINSTALL_SH_LOADED:-0}" = "1" ] && return 0
XMG_UNINSTALL_SH_LOADED=1

XMG_BIN_PATH="${XMG_BIN_PATH:-/usr/local/bin/xmg}"
XMG_LIB_INSTALL_DIR="${XMG_LIB_INSTALL_DIR:-/usr/local/lib/xmg}"

xmg_uninstall_safe_rm_rf() {
    local path="$1"

    case "$path" in
        ""|"/"|"/usr"|"/usr/local"|"/etc"|"/var"|"/var/www"|"/var/log"|"/var/backups")
            xmg_die "拒绝删除危险路径: $path"
            ;;
    esac

    if [ -e "$path" ]; then
        rm -rf --one-file-system "$path"
        xmg_info "已删除: $path"
    else
        xmg_warn "不存在，跳过: $path"
    fi
}

xmg_uninstall_safe_rm_f() {
    local path="$1"

    case "$path" in
        ""|"/"|"/usr"|"/usr/local"|"/etc"|"/var")
            xmg_die "拒绝删除危险路径: $path"
            ;;
    esac

    if [ -e "$path" ] || [ -L "$path" ]; then
        rm -f "$path"
        xmg_info "已删除: $path"
    else
        xmg_warn "不存在，跳过: $path"
    fi
}

xmg_uninstall_show_plan_program_only() {
    cat <<EOF
将卸载 XMG 程序文件：

  $XMG_BIN_PATH
  $XMG_LIB_INSTALL_DIR

不会删除：

  $XMG_ETC_DIR
  $XMG_WWW_DIR
  $XMG_LOG_DIR
  $XMG_BACKUP_DIR

不会卸载或停止：

  xray
  caddy
  ufw

EOF
}

xmg_uninstall_show_plan_all() {
    cat <<EOF
将卸载 XMG 程序文件和 XMG 数据目录：

  $XMG_BIN_PATH
  $XMG_LIB_INSTALL_DIR
  $XMG_ETC_DIR
  $XMG_WWW_DIR
  $XMG_LOG_DIR
  $XMG_BACKUP_DIR

不会卸载系统软件包：

  xray
  caddy
  ufw

不会自动修改系统防火墙规则。

EOF
}

xmg_uninstall_program_only() {
    xmg_require_root

    clear
    echo "XMG 卸载：仅删除程序文件"
    echo "========================="
    echo

    xmg_uninstall_show_plan_program_only

    if ! xmg_confirm "确认仅删除 XMG 程序文件?"; then
        xmg_info "已取消"
        return 0
    fi

    xmg_uninstall_safe_rm_f "$XMG_BIN_PATH"
    xmg_uninstall_safe_rm_rf "$XMG_LIB_INSTALL_DIR"

    xmg_info "XMG 程序文件已卸载"
    echo
    xmg_warn "当前 shell 中已加载的菜单函数仍可能暂时存在，建议退出当前 xmg 会话。"
}

xmg_uninstall_all() {
    xmg_require_root

    clear
    echo "XMG 卸载：删除程序和数据"
    echo "========================"
    echo

    xmg_uninstall_show_plan_all

    xmg_warn "此操作会删除 XMG 配置、站点、日志和备份目录。"

    if ! xmg_confirm "确认删除 XMG 程序和所有 XMG 数据?"; then
        xmg_info "已取消"
        return 0
    fi

    xmg_uninstall_safe_rm_f "$XMG_BIN_PATH"
    xmg_uninstall_safe_rm_rf "$XMG_LIB_INSTALL_DIR"
    xmg_uninstall_safe_rm_rf "$XMG_ETC_DIR"
    xmg_uninstall_safe_rm_rf "$XMG_WWW_DIR"
    xmg_uninstall_safe_rm_rf "$XMG_LOG_DIR"
    xmg_uninstall_safe_rm_rf "$XMG_BACKUP_DIR"

    xmg_info "XMG 程序和数据已卸载"
    echo
    xmg_warn "不会自动卸载 xray/caddy/ufw，如需卸载请使用系统包管理器。"
}

xmg_uninstall_menu() {
    local choice=""

    while true; do
        clear
        cat <<EOF
XMG 卸载
========

1) 仅卸载 XMG 程序文件
2) 卸载 XMG 程序文件和 XMG 数据
3) 返回

说明:
- 不会卸载 xray/caddy/ufw 软件包
- 不会自动删除系统防火墙规则
- 删除前会进行危险路径保护

EOF
        printf '请选择: '
        read -r choice || return 0

        case "$choice" in
            1)
                xmg_uninstall_program_only
                xmg_pause
                ;;
            2)
                xmg_uninstall_all
                xmg_pause
                ;;
            3)
                return 0
                ;;
            *)
                xmg_warn "无效选择"
                xmg_pause
                ;;
        esac
    done
}
