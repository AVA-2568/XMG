#!/usr/b**/env bash

# ===== 安全加载 =====
if **"${XMG_UPDATE_SH_LOADED:-0}" = "1**]; then
    return 0 2>/dev/null ** exit 0
fi
XMG_UPDATE_SH_LOADED=1**# update.sh 是 Bash 库文件，明确拒绝非 Bash**主
[ -n "${BASH_VERSION:-}" ] || {**   echo "update.sh: requires bash**>&2
    return 1 2>/dev/null || e**t 1
}

XMG_REPO_RAW="${XMG_REPO_R**:-https://raw.githubusercontent.c**/AVA-2568/xmg/main}"
XMG_BIN_PATH**${XMG_BIN_PATH:-/usr/local/bin/xm**"

xmg_update_required_files() {
**  cat <<EOF
common.sh
system.sh
m**itor.sh
menu.sh
caddy.sh
xray.sh
**te.sh
firewall.sh
update.sh
unins**ll.sh
EOF
}

xmg_update_version()**
    echo "XMG_VERSION=${XMG_VERS**N:-unknown}"
    echo "XMG_LIB_DI**$XMG_LIB_DIR"
    echo "XMG_REPO_**W=$XMG_REPO_RAW"
    echo "XMG_BI**PATH=$XMG_BIN_PATH"
}

xmg_update**s_abs_path() {
    local path="$1**
    case "$path" in
        /*) **turn 0 ;;
        *)  return 1 ;;**   esac
}

xmg_update_reject_path**raversal() {
    local path="$1"
**   case "$path" in
        *"/../**|*"/.."|".."|"../"*)
            **g_die "拒绝包含路径穿越的路径: $path"
      **    ;;
    esac
}

xmg_update_req**re_install_paths_safe() {
    if **xmg_update_is_abs_path "$XMG_BIN_**TH"; then
        xmg_die "更新目标 X**_BIN_PATH 必须是绝对路径: $XMG_BIN_PATH"**   fi

    if ! xmg_update_is_abs**ath "$XMG_LIB_DIR"; then
        **g_die "更新目标 XMG_LIB_DIR 必须是绝对路径: **MG_LIB_DIR"
    fi

    xmg_updat**reject_path_traversal "$XMG_BIN_P**H"
    xmg_update_reject_path_tra**rsal "$XMG_LIB_DIR"
}

xmg_update**heck_files() {
    local missing=**    local f=""

    echo "检查 XMG **完整性"
    echo "==================**"
    echo

    if [ -x "$XMG_BIN**ATH" ] || [ -f "$XMG_BIN_PATH" ];**hen
        echo "[OK]   $XMG_BIN**ATH"
    else
        echo "[MISS**$XMG_BIN_PATH"
        missing=$(**issing + 1))
    fi

    while IF** read -r f; do
        if [ -r "$**G_LIB_DIR/$f" ]; then
           **cho "[OK]   $XMG_LIB_DIR/$f"
    **  else
            echo "[MISS] $**G_LIB_DIR/$f"
            missing**((missing + 1))
        fi
    do** < <(xmg_update_required_files)

**  echo

    if [ "$missing" -eq 0**; then
        xmg_info "文件检查通过"
**      return 0
    fi

    xmg_wa** "缺失 $missing 个文件"
    return 1
}**xmg_update_download() {
    local**rl="$1"
    local dst="$2"
    lo**l mode="${3:-0644}"
    local tmp**"

    xmg_cmd_exists curl || xmg**ie "curl 不存在，无法更新"
    xmg_cmd_ex**ts install || xmg_die "install 命令**在，无法更新"

    tmp="$(mktemp)" || x**_die "创建临时文件失败"

    xmg_update_c**anup_tmp() {
        [ -n "${tmp:**" ] && [ -e "$tmp" ] && rm -f "$t**"
    }
    trap xmg_update_clean**_tmp RETURN

    if ! curl -fsSL **url" -o "$tmp"; then
        xmg_**e "下载失败: $url"
    fi

    if [ !**s "$tmp" ]; then
        xmg_die **载结果为空: $url"
    fi

    if ! ins**ll -m "$mode" -o root -g root "$t**" "$dst"; then
        xmg_die "安**新文件失败: $dst"
    fi
}

xmg_update**ackup_if_exists() {
    local pat**"$1"

    if [ -e "$path" ] || [ ** "$path" ]; then
        xmg_back**_file "$path" || xmg_die "备份失败: $**th"
    fi
}

xmg_update_prepare_**rs() {
    xmg_mkdirs

    mkdir ** "$XMG_LIB_DIR" || xmg_die "创建库目录**: $XMG_LIB_DIR"
    mkdir -p "$(d**name "$XMG_BIN_PATH")" || xmg_die**创建命令目录失败: $(dirname "$XMG_BIN_PAT**)"
}

xmg_update_from_github() {
**  local f=""

    xmg_require_roo**    xmg_update_require_install_pa**s_safe

    xmg_warn "将从 GitHub R** 更新 XMG 文件"
    echo "源: $XMG_REP**RAW"
    echo "目标命令: $XMG_BIN_PAT**
    echo "目标库目录: $XMG_LIB_DIR"
 ** echo

    if ! xmg_confirm "确认更新**; then
        xmg_info "已取消"
   **   return 0
    fi

    xmg_updat**prepare_dirs

    xmg_update_back**_if_exists "$XMG_BIN_PATH"
    xm**update_download "$XMG_REPO_RAW/xm** "$XMG_BIN_PATH" 0755

    while **S= read -r f; do
        xmg_upda**_backup_if_exists "$XMG_LIB_DIR/$**
        xmg_update_download "$XM**REPO_RAW/lib/$f" "$XMG_LIB_DIR/$f**0644
    done < <(xmg_update_requ**ed_files)

    xmg_info "更新完成"
  **xmg_update_check_files || true
}
**mg_update_menu() {
    local choi**=""

    while true; do
        c**ar
        echo "========== 更新 / ** =========="
        echo "1. 显示版**
        echo "2. 检查本地文件完整性"
    **  echo "3. 从 GitHub 更新"
        e**o "0. 返回"
        echo
        ec** "说明:"
        echo "  - 更新只覆盖 XM**自身文件"
        echo "  - 不修改 xray/**ddy/ufw 配置"
        echo "  - 从 G**Hub 更新要求安装目标为绝对路径"
        echo
 **     printf "请选择: "

        read**r choice || return 0

        cas**"$choice" in
            1)
     **         xmg_update_version
     **         xmg_pause
              **;;
            2)
               **mg_update_check_files
           **   xmg_pause
                ;;
 **         3)
                xmg_u**ate_from_github
                x**_pause
                ;;
       **   0)
                return 0
  **            ;;
            *)
   **           xmg_warn "无效选择"
      **        xmg_pause
               **;
        esac
    done
}
