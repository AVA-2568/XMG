#!/usr/bin/env bash

# ===== 安**载 =====
if [ "${XMG_MONITOR_SH_LO**ED:-0}" = "1" ]; then
    return **2>/dev/null || exit 0
fi
XMG_MONI**R_SH_LOADED=1

XMG_MONITOR_INTERV**="${XMG_MONITOR_INTERVAL:-3}"

xm**monitor_clear() {
    printf '\03**H\033[2J'
}

xmg_monitor_hide_cur**r() {
    printf '\033[?25l'
}

x**_monitor_show_cursor() {
    prin** '\033[?25h'
}

xmg_monitor_clean**() {
    xmg_monitor_show_cursor
**
# 打印带颜色状态，避免在热路径中使用 $(xmg_status**olor ...)
xmg_monitor_print_statu**line() {
    local**abel="$1"
    local value="$2"

 ** printf '  %-11** ' "$label"
    xmg_status_color **value"
    printf '\n'
}

xmg_mon**or_draw() {
    xmg_monitor_clear**    printf '%sXMG Monitor (Real-T**e)%s\n' "$XMG_C_CYAN" "$XMG_C_RES**"
    printf '===================**==\n\n'

    printf '%s系统%s\n' "$**G_C_BOLD" "$XMG_C_RESET"
    prin** '  Time       : %s\n' "$XMG_STAT**_TIME"
    printf '  Hostname   :**s\n' "$XMG_STATUS_HOSTNAME"
    p**ntf '  Kernel     : %s\n' "$XMG_S**TUS_KERNEL"
    printf '  Uptime **  : %s\n' "$XMG_STATUS_UPTIME"
  **printf '  Load       : %s\n' "$XM**STATUS_LOAD"
    printf '  Memory**   : %s (%s)\n' "$XMG_STATUS_MEM_**RCENT" "$XMG_STATUS_MEM_DETAIL"
 ** printf '  Disk /     : %s\n' "$X**_STATUS_DISK_ROOT"
    printf '\n**
    printf '%s服务%s\n' "$XMG_C_BO**" "$XMG_C_RESET"
    xmg_monitor_**int_status_line "Xray" "$XMG_STAT**_XRAY"
    xmg_monitor_print_stat**_line "Caddy" "$XMG_STATUS_CADDY"**   printf '\n'

    printf '%s监听端**s\n' "$XMG_C_BOLD" "$XMG_C_RESET"**   xmg_monitor_print_status_line **2/SSH" "$XMG_STATUS_PORT_22"
    **g_monitor_print_status_line "80/H**P" "$XMG_STATUS_PORT_80"
    xmg_**nitor_print_status_line "443/HTTP** "$XMG_STATUS_PORT_443"
    print**'\n'

    printf '操作: '
    print**'%s[m]%s 管理菜单  ' "$XMG_C_GREEN" "**MG_C_RESET"
    printf '%s[q]%s 退**n' "$XMG_C_RED" "$XMG_C_RESET"
  **printf '\n'

    printf '低资源模式: U**新=%ss, 系统缓存=%ss, 服务缓存=%ss\n' \
  **    "$XMG_MONITOR_INTERVAL" "$XMG**ACHE_TTL" "$XMG_SERVICE_TTL"
}

x**_monitor_loop() {
    local key="**
    trap 'xmg_monitor_cleanup; e**t 130' INT TERM
    trap 'xmg_mon**or_cleanup' EXIT

    xmg_monitor**ide_cursor
    xmg_system_refresh**ll force

    while true; do
    **  xmg_system_refresh_all
        **g_monitor_draw

        key=""
  **    if read -rsn1 -t "$XMG_MONITO**INTERVAL" key; then
            c**e "$key" in
                m|M)
**                  xmg_monitor_sho**cursor
                    xmg_me**_loop
                    xmg_mon**or_hide_cursor
                  **xmg_system_refresh_all force
    **              ;;
                **Q)
                    xmg_monito**show_cursor
                    x**_monitor_clear
                  **trap - EXIT
                    r**urn 0
                    ;;
    **          *)
                    **
            esac
        fi
    **ne
}
