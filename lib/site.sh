#!/usr/bin/env bash
#
# site.sh - 站点目录管理
#

backup_site() {
    if [[ -d "${WEB_ROOT}" ]] && [[ -n "$(ls -A "${WEB_ROOT}" 2>/dev/null || true)" ]]; then
        local ts
        local backup

        ts="$(date +%Y%m%d-%H%M%S)"
        backup="${BACKUP_DIR}/mask-site.${ts}.tar.gz"

        tar -czf "${backup}" -C "${WEB_ROOT}" .
        ok "当前站点已备份到 ${backup}"
    else
        warn "站点目录为空，无需备份"
    fi
}

pull_site_from_github() {
    local repo

    install_base_deps

    read -rp "请输入 GitHub 仓库地址，例如 https://github.com/user/repo.git: " repo

    if [[ -z "${repo}" ]]; then
        err "仓库地址不能为空"
        return 1
    fi

    backup_site

    rm -rf "${WEB_ROOT:?}/"*
    rm -rf /tmp/xmg-site

    info "正在拉取仓库：${repo}"

    if git clone --depth=1 "${repo}" /tmp/xmg-site; then
        shopt -s dotglob
        cp -a /tmp/xmg-site/* "${WEB_ROOT}/" || true
        shopt -u dotglob

        rm -rf /tmp/xmg-site

        chown -R caddy:caddy "${WEB_ROOT}" 2>/dev/null || true
        find "${WEB_ROOT}" -type d -exec chmod 755 {} \;
        find "${WEB_ROOT}" -type f -exec chmod 644 {} \;

        ok "站点已部署到 ${WEB_ROOT}"
    else
        err "GitHub 仓库拉取失败，请检查地址或网络"
        return 1
    fi
}

clear_site() {
    warn "即将清空 ${WEB_ROOT}"

    if confirm "确认清空?"; then
        backup_site
        rm -rf "${WEB_ROOT:?}/"*
        ok "站点目录已清空"
    else
        warn "已取消"
    fi
}

show_site_dir() {
    mkdir -p "${WEB_ROOT}"
    ls -lah "${WEB_ROOT}"
}

site_menu() {
    while true; do
        clear
        echo "========== 站点目录管理 =========="
        echo "1. 从 GitHub 拉取站点"
        echo "2. 备份当前站点"
        echo "3. 清空当前站点"
        echo "4. 查看站点目录"
        echo "0. 返回"
        echo
        read -rp "请选择: " choice

        case "${choice}" in
            1) pull_site_from_github; pause ;;
            2) backup_site; pause ;;
            3) clear_site; pause ;;
            4) show_site_dir; pause ;;
            0) break ;;
            *) warn "无效选择"; pause ;;
        esac
    done
}
