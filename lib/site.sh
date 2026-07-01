#!/usr/bi**env**ash
#
# site.sh - 站点目录管理
#

# ===** 安全加载 =====
if [ "${XMG_SITE_SH_L**DED:-0}" = "1" ]; then
    return** 2>/dev/null || exit 0
fi
XMG_SIT**SH_LOADED=1

**路径安全检查：只允许操作 XMG_WWW_DIR 本身或其子路径
**g_site_safe_path() {
    local pa**="$1"

    case "$path" in
      **""|"/"|"/usr"|"/usr/local"|"/etc"**/var"|"/var/www**"/var/log"|"/var/backups"|"/home"**/home/"*)
            xmg_die "拒绝**危险路径: $path"
            ;;
    e**c

    case "$path" in
        "$**G_WWW_DIR"|"$XMG_WWW_DIR"/*)
    **      return 0
            ;;
   **   *)
            xmg_die "路径不在站点**下: $path"
            ;;
    esac**

xmg_site_need_git() {
    if ! **g_cmd_exists git; then
        xm**die "git 不存在，请先安装 git 后再拉取站点"
   **i
}

xmg_site_prepare**ww() {
    xmg_require_root
    x**_m**irs
    xmg_site_safe_path "$XMG_**W_DIR"

    mkdir -p "$XMG_WWW_DI** || xmg_die "创建站点目录失败: $X**_WWW_DIR"
}

# 判断站点目录是否为空，包括**文件
xmg_site_dir_has_content() {
 ** local item=""

**  [ -d "$XMG_WWW_DIR" ] || return**

    shopt -s nullglob dotglob
 ** for item in "$XMG_WWW_DIR"/*; do**       shopt -u nullglob dotglob
**      return 0
    done
    shopt**u nullglob dotglob

    return **}

# 安**空站点目录，包括隐藏文件
xmg_site_empty_dir()**
    local item=""

    xmg_requi**_root
    xmg_site_safe_path "$XM**WWW_DIR"

    [ -d "$XMG_WWW_DIR"** || mkdir -p "$XMG_WWW_DIR"

    **opt -s nullglob dotglob
    for i**m in "$XMG_WWW_DIR"/*; do
       **m -rf --one-file-system "$item" |**xmg_die "删除失败: $item"
    done
  **shopt -u nullglob dotglob
}

# 备份**站点
xmg_site_backup() {
    local **=""
    local backup=""

    xmg_**quire_root
    xmg_mkdirs
    xmg**ite_safe_path "$XMG_WWW_DIR"

   **f ! xmg_site_dir_has_content; the**        xmg_warn "站点目录为空，无需备份"
  **    return 0
    fi

    ts="$(xm**timestamp)"
    backup="$XMG_BACK**_DIR/xmg-site.${ts}.tar.gz"

    **r -czf "$backup" -C "$XMG_WWW_DIR**. || xmg_die "站点备份失败"
    xmg_inf**"当前站点已备份到 $backup"
}

# 从 GitHub **Git 仓库拉取站点
xmg_site_pull_from_git**b() {
    local repo=""
    local**mpdir=""

    xmg_require_root
  **xmg_site_need_git
    xmg_site_pr**are_www

    read -r -p "请输入 Git **地址，例如 https://github.com/user/rep**git: " repo

    if [ -z "$repo" ** then
        xmg_error "仓库地址不能为空**        return 1
    fi

    tmpd**="$(mktemp -d)" || xmg_die "创建临时目**败"

    # 函数退出时清理临时目录
    xmg_sit**cleanup_tmp() {
        [ -n "${t**dir:-}" ] && [ -d "$tmpdir" ] && ** -rf "$tmpdir"
    }
    trap xmg**ite_cleanup_tmp RETURN

    xmg_s**e_backup

    xmg_info "正在拉取仓库: $**po"

    if ! git clone --depth=1**$repo" "$tmpdir/repo"; then
     ** xmg_error "Git 仓库拉取失败，请检查地址或网络"
**      return 1
    fi

    xmg_si**_empty_dir

    shopt -s dotglob **llglob
    if ! cp -a "$tmpdir/re**"/* "$XMG_WWW_DIR"/ 2>/dev/null; **en
        shopt -u dotglob nullg**b
        xmg_die "复制站点文件失败"
    **
    shopt -u dotglob nullglob

 ** if id caddy >/dev/null 2>&1; the**        chown -R caddy:caddy "$XM**WWW_DIR" 2>/dev/null || true
    **

    find "$XMG_WWW_DIR" -type d**exec chmod 755 {} \; 2>/dev/null ** true
    find "$XMG_WWW_DIR" -ty** f -exec chmod 644 {} \; 2>/dev/n**l || true

    xmg_info "站点已部署到 $**G_WWW_DIR"
    xmg_warn "XMG 不修改 **ddyfile，如需生效请用户自行配置或重载 Caddy"
}

**清空站点
xmg_site_clear() {
    xmg_r**uire_root
    xmg_site**repare_www

    xmg_warn "即将清空 $X**_WWW_DIR"

    if xmg_confirm "确认**当前站点目录?"; then
        xmg_site_b**kup
        xmg_site_empty_dir
  **    xmg_info "站点目录已清空"
    else
 **     xmg_info "已取消"
    fi
}

# 查**点目录
xmg_site_show() {
    xmg_mkd**s

    echo**站点目录: $**G_WWW_DIR"
    echo

    if [ ! -**"$XMG_WWW_DIR" ]; then
        xm**warn "站点目录不存在: $XMG_WWW_DIR"
    **  return 0
    fi

    ls -lah "$**G_WWW_DIR"
}

# 站点菜单
xmg_site_men**) {
    local choice=""

    whil**true; do
        clear
        ec** "========== 站点目录管理 =========="
 **     echo "1. 从 Git 仓库拉取站点"
     ** echo "2. 备份当前站点"
        echo "3**清空当前站点"
        echo "4. 查看站点目录"
**      echo "0. 返回"
        echo
 **     echo "说明:"
        echo "  -**MG 只管理站点文件目录"
        echo "  - X** 不创建、不编辑、不校验 Caddyfile"
        e**o "  - 拉取站点需要系统已安装 git"
        e**o
        printf "请选择: "

       **ead -r choice || return 0

      **case "$choice" in
            1)
**              xmg_site_pull_from_**thub
                xmg_pause
  **            ;;
            2)
   **           xmg_site_backup
      **        xmg_pause
               **;
            3)
                **g_site_clear
                xmg_**use
                ;;
          **4)
                xmg_site_show
**              xmg_pause
         **     ;;
            0)
          **    return 0
                ;;
 **         *)
                xmg_w**n "无效选择"
                xmg_paus**                ;;
        esac
 ** done
}
