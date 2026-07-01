#!/usr/bin/env bash

# 既兼容 source，也兼容被直接执行
if [ "${XMG_SYSTEM_SH_LOADED:-0}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi
XMG_SYSTEM_SH_LOADED=1

XMG_CACHE_TTL="${XMG_CACHE_TTL:-3}"
XMG_SERVICE_TTL="${XMG_SERVICE_TTL:-5}"

XMG_CACHE_TS=0
XMG_SERVICE_CACHE_TS=0

XMG_STATUS_TIME="unknown"
XMG_STATUS_HOSTNAME="unknown"
XMG_STATUS_KERNEL="unknown"
XMG_STATUS_UPTIME="unknown"
XMG_STATUS_LOAD="unknown"
XMG_STATUS_MEM_PERCENT="unknown"
XMG_STATUS_MEM_DETAIL="unknown"
XMG_STATUS_DISK_ROOT="unknown"
XMG_STATUS_XRAY="unknown"
XMG_STATUS_CADDY="unknown"
XMG_STATUS_PORT_22="unknown"
XMG_STATUS_PORT_80="unknown"
XMG_STATUS_PORT_443="unknown"

# 如果项目其他地方没有定义，这里提供一个兜底实现
xmg_cmd_exists() {
    command -v "$1" >/dev/null 2>&1
}

xmg_now_s() {
    # bash 4.2+：内建时间获取，避免 fork date
    printf '%(%s)T' -1
}

xmg_read_hostname() {
    local h=""
    if read -r h < /proc/sys/kernel/hostname 2>/dev/null; then
        printf '%s' "$h"
        return 0
    fi

    hostname 2>/dev/null || echo "unknown"
}

xmg_read_kernel() {
    uname -r 2>/dev/null || echo "unknown"
}

xmg_read_time() {
    # bash 4.2+：内建格式化时间
    printf '%(%Y-%m-%d %H:%M:%S)T' -1
}

xmg_read_load() {
    local l1 l2 l3 rest
    if read -r l1 l2 l3 rest < /proc/loadavg 2>/dev/null; then
        printf '%s %s %s' "$l1" "$l2" "$l3"
        return 0
    fi
    echo "unknown"
}

xmg_read_uptime() {
    local raw sec d h m
    if ! read -r raw _ < /proc/uptime 2>/dev/null; then
        echo "unknown"
        return 0
    fi

    sec="${raw%%.*}"
    d=$((sec / 86400))
    h=$(((sec % 86400) / 3600))
    m=$(((sec % 3600) / 60))

    if [ "$d" -gt 0 ]; then
        printf '%dd %02dh %02dm' "$d" "$h" "$m"
    else
        printf '%02dh %02dm' "$h" "$m"
    fi
}

# 一次读取内存信息，返回格式：percent|detail
# 例如：37%|1482Mi/3950Mi
xmg_read_mem() {
    local key value unit
    local total_kb=0
    local avail_kb=0
    local used_kb=0
    local percent=0

    while read -r key value unit; do
        case "$key" in
            MemTotal:)
                total_kb="$value"
                ;;
            MemAvailable:)
                avail_kb="$value"
                ;;
        esac

        if [ "$total_kb" -gt 0 ] && [ "$avail_kb" -gt 0 ]; then
            break
        fi
    done < /proc/meminfo 2>/dev/null

    if [ "$total_kb" -le 0 ] || [ "$avail_kb" -lt 0 ]; then
        echo "unknown|unknown"
        return 0
    fi

    used_kb=$((total_kb - avail_kb))
    if [ "$used_kb" -lt 0 ]; then
        used_kb=0
    fi

    percent=$((used_kb * 100 / total_kb))

    printf '%s|%sMi/%sMi' \
        "${percent}%" \
        "$((used_kb / 1024))" \
        "$((total_kb / 1024))"
}

# 兼容旧调用（如果项目其他地方还在用）
xmg_read_mem_percent() {
    local r
    r="$(xmg_read_mem)"
    printf '%s' "${r%%|*}"
}

xmg_read_mem_detail() {
    local r
    r="$(xmg_read_mem)"
    printf '%s' "${r##*|}"
}

xmg_read_disk_root() {
    df -hP / 2>/dev/null | awk 'NR==2 {print $5" "$3"/"$2}' || echo "unknown"
}

xmg_service_active_read() {
    local service="$1"

    if ! xmg_cmd_exists systemctl; then
        echo "no-systemd"
        return 0
    fi

    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo "running"
    else
        echo "stopped"
    fi
}

xmg_hex_port() {
    local port="$1"
    printf '%04X' "$port"
}

xmg_proc_port_listening() {
    local port="$1"
    local hex=""
    local file
    local sl addr rem state rest

    hex="$(xmg_hex_port "$port")"

    for file in /proc/net/tcp /proc/net/tcp6; do
        [ -r "$file" ] || continue

        while read -r sl addr rem state rest; do
            # 跳过表头
            [ "$sl" = "sl" ] && continue

            # local_address 形如 0100007F:0016 或 IPv6 对应格式，取冒号后端口十六进制
            if [ "${addr##*:}" = "$hex" ] && [ "$state" = "0A" ]; then
                return 0
            fi
        done < "$file"
    done

    return 1
}

xmg_port_status() {
    local port="$1"

    if xmg_proc_port_listening "$port"; then
        echo "listen"
    else
        echo "closed"
    fi
}

# 只保留这一份，删除旧版重复定义
xmg_system_refresh_basic() {
    local force="${1:-}"
    local now=0
    local mem_result=""

    now="$(xmg_now_s)"

    if [ "$force" != "force" ] && [ $((now - XMG_CACHE_TS)) -lt "$XMG_CACHE_TTL" ]; then
        return 0
    fi

    XMG_CACHE_TS="$now"

    XMG_STATUS_TIME="$(xmg_read_time)"
    XMG_STATUS_HOSTNAME="$(xmg_read_hostname)"
    XMG_STATUS_KERNEL="$(xmg_read_kernel)"
    XMG_STATUS_UPTIME="$(xmg_read_uptime)"
    XMG_STATUS_LOAD="$(xmg_read_load)"

    # 一次读取内存信息
    mem_result="$(xmg_read_mem)"
    XMG_STATUS_MEM_PERCENT="${mem_result%%|*}"
    XMG_STATUS_MEM_DETAIL="${mem_result##*|}"

    XMG_STATUS_DISK_ROOT="$(xmg_read_disk_root)"

    XMG_STATUS_PORT_22="$(xmg_port_status 22)"
    XMG_STATUS_PORT_80="$(xmg_port_status 80)"
    XMG_STATUS_PORT_443="$(xmg_port_status 443)"
}

xmg_system_refresh_services() {
    local force="${1:-}"
    local now=0

    now="$(xmg_now_s)"

    if [ "$force" != "force" ] && [ $((now - XMG_SERVICE_CACHE_TS)) -lt "$XMG_SERVICE_TTL" ]; then
        return 0
    fi

    XMG_SERVICE_CACHE_TS="$now"

    XMG_STATUS_XRAY="$(xmg_service_active_read xray)"
    XMG_STATUS_CADDY="$(xmg_service_active_read caddy)"
}

xmg_system_refresh_all() {
    local force="${1:-}"

    xmg_system_refresh_basic "$force"
    xmg_system_refresh_services "$force"
}

xmg_status_color() {
    local value="$1"

    case "$value" in
        running|listen)
            printf '%s%s%s' "${XMG_C_GREEN:-}" "$value" "${XMG_C_RESET:-}"
            ;;
        stopped|closed)
            printf '%s%s%s' "${XMG_C_RED:-}" "$value" "${XMG_C_RESET:-}"
            ;;
        *)
            printf '%s%s%s' "${XMG_C_YELLOW:-}" "$value" "${XMG_C_RESET:-}"
            ;;
    esac
}

xmg_system_print_summary() {
    cat <<EOF
XMG System Summary
==================

Time       : $XMG_STATUS_TIME
Hostname   : $XMG_STATUS_HOSTNAME
Kernel     : $XMG_STATUS_KERNEL
Uptime     : $XMG_STATUS_UPTIME
Load       : $XMG_STATUS_LOAD
Memory     : $XMG_STATUS_MEM_PERCENT ($XMG_STATUS_MEM_DETAIL)
Disk /     : $XMG_STATUS_DISK_ROOT

Services:
  Xray      : $(xmg_status_color "$XMG_STATUS_XRAY")
  Caddy     : $(xmg_status_color "$XMG_STATUS_CADDY")

Ports:
  22/SSH    : $(xmg_status_color "$XMG_STATUS_PORT_22")
  80/HTTP   : $(xmg_status_color "$XMG_STATUS_PORT_80")
  443/HTTPS : $(xmg_status_color "$XMG_STATUS_PORT_443")
EOF
}
