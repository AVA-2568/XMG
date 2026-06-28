#!/usr/bin/env bash
#
# system.sh - 非实时系统管理模块（轻量版）
#

########################################
# 基础系统信息（菜单用）
########################################

show_system_info() {
    echo
    echo "========== 系统信息 =========="

    echo "主机名: $(hostname)"

    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "系统: ${PRETTY_NAME}"
    fi

    echo "内核: $(uname -r)"

    echo
    echo "========== CPU =========="
    echo "逻辑 CPU 核心数: $(nproc)"

    echo
    echo "========== 内存 =========="
    free -h

    echo
    echo "========== 磁盘 =========="
    df -h /

    echo
    echo "========== 网络端口 =========="
    ss -lntup 2>/dev/null || echo "ss 命令不可用"
}

########################################
# 服务状态（菜单用）
########################################

show_services_status() {
    echo
    echo "========== 服务状态 =========="

    if pidof caddy >/dev/null 2>&1; then
        echo "Caddy: running"
    else
        echo "Caddy: stopped"
    fi

    if pidof xray >/dev/null 2>&1; then
        echo "Xray: running"
    else
        echo "Xray: stopped"
    fi

    echo
    echo "========== 端口监听 =========="
    ss -lntup 2>/dev/null || echo "ss 不可用"
}

########################################
# 小内存 VPS 优化
########################################

optimize_small_vps() {
    echo
    echo "[INFO] 开始优化小内存 VPS（适用于 0.5C / 512MB）"

    ########################################
    # journald 限制
    ########################################
    mkdir -p /etc/systemd/journald.conf.d

    cat > /etc/systemd/journald.conf.d/99-xmg.conf <<EOF
[Journal]
SystemMaxUse=50M
RuntimeMaxUse=20M
MaxRetentionSec=7day
EOF

    systemctl restart systemd-journald 2>/dev/null || true

    ########################################
    # Swap
    ########################################
    if swapon --show | grep -q '^'; then
        echo "[INFO] 已存在 swap，跳过创建"
    else
        echo "[INFO] 创建 512M swap..."

        if ! fallocate -l 512M /swapfile 2>/dev/null; then
            dd if=/dev/zero of=/swapfile bs=1M count=512
        fi

        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile

        if ! grep -q '^/swapfile ' /etc/fstab; then
            echo '/swapfile none swap sw 0 0' >> /etc/fstab
        fi
    fi

    ########################################
    # sysctl 优化
    ########################################
    cat > /etc/sysctl.d/99-xmg.conf <<EOF
vm.swappiness=20
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF

    sysctl --system >/dev/null 2>&1 || true

    echo "[OK] 优化完成 ✅"
}

########################################
# （可选）快速诊断
########################################

quick_diagnose() {
    echo
    echo "========== 快速诊断 =========="

    echo "[服务状态]"
    pidof caddy >/dev/null && echo "Caddy: OK" || echo "Caddy: ERROR"
    pidof xray  >/dev/null && echo "Xray: OK"  || echo "Xray: ERROR"

    echo
    echo "[端口]"
    ss -lnt 2>/dev/null | head -n 10 || true

    echo
    echo "[内存]"
    free -h

    echo
    echo "[负载]"
    cat /proc/loadavg
}
