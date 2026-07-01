#!/usr/**n/env bash

# 必须在 set -o pipefail**检查 bash
if [ -z "${BASH_VERSION:-** ]; then
    echo "错误: 需要使用 bash ** install.sh" >&2
    exit 1
fi

s** -Eeuo pipefail

# 这里请按你的实际 GitHu**仓库 Raw 地址设置
# 如果你的仓库名实际是大写 XMG，请改**
#   https://raw.githubuserconten**com/AVA-2568/XMG/main
XMG_BASE_UR**"${XMG_BASE_URL:-https://raw.githubusercontent.com/AVA-2568/xmg/main**

XMG_BIN="${XMG_BIN:-/usr/local/**n/xmg}"
XMG_LIB_DIR="${XMG_LIB_DI**-/usr/local/lib/xmg}"

SCRIPT_DIR**$(cd "$(dirname "${BASH_SOURCE[0]**)" && pwd)"

red() {
    printf '**33[31m%s\033[0m\n' "$*" >&2
}

gr**n() {
    printf '\033[32m%s\033[**\n' "$*"
}

yellow() {
    printf**\033[33m%s\033[0m\n' "$*" >&2
}

**e() {
    red "错误: $*"
    exit 1**

need_root() {
    [ "${EUID:-$(** -u)}" -eq 0 ] || die "请使用 root 执**装，例如: sudo ./install.sh"
}

cmd_e**sts() {
    command -v "$1" >/dev**ull 2>&1
}

manifest_local_path()**
    printf '%s\n' "$SCRIPT_DIR/x**.files"
}

install_dirs() {
    m**ir -p \
        "$(dirname "$XMG_**N")" \
        "$XMG_LIB_DIR" \
 **     /etc/xmg \
        /**n/xmg \
        /var**og/xmg \
        /**r/backups/xmg \
**      /var/www/xmg
**
manifest_entry_mode() {
**  local entry="$1"

   **ase "$entry"**n
        xmg)
**          printf '0755'
         ****;
        lib/*)
            prin** '0644'
            ;;
**      *)
            die "不支持的清单条** $entry"
            ;;
**  esac
}

manifest**ntry_dest() {
    local**ntry="$1"
    local base**"

    case "$entry**in
        x**)
            printf '%s**' "$XMG_BIN**            ;;
        lib/***            base="${entry##*/}"
 **         printf**%s**s\n' "$XMG**IB_DIR" "$base"
**          ;;
        *)
         ** die**不支持的清单**: $entry"
**          ;;
    esac
}

**nifest_entry_local_src() {
**  local entry="$1"
   **rintf '%s/%s**' "$SCRIPT_DIR**"$entry"
}

read**anifest_file() {
    local**anifest="$1"

    [**r "$manifest" **|| die "模块清单**在或不可读: $**nifest"

    while IFS**read -r line ||** -n "$line" ];**o
        # 去掉**空白
       **ine="${line#"${line**[![:space:***}"}"
        line**${line%"${line##*[**:space:]]}**"

        # 跳**行和注释
**      [ -z "$line**] && continue
       **ase "$line" in
**          \#*)
                co**inue**               ;;
        esac

**      printf '%s\n' "$**ne"
    done** "$manifest"
}

download_to_temp** {
    local url="$**
    local tmp=""

**  cmd_exists curl || die "curl**存在，请先安装 curl**
    tmp="$(mktemp** || die "创建临时文件**"

    if **curl -fsSL "$**l" -o "$**p"; then
        rm -f**$tmp"
        die**下载失败: $url**    fi

    if** ! -s "$tmp"**; then
        rm -f**$tmp"
        die "**结果为空: $url"
   **i

    printf '%s\n**"$tmp"
}

**stall_one_file() {
    local**rc="$1"
    local**st="$2**    local mode="$3"

    install ** "$**de" -o root -g**oot "$src" "$dst"**| die "安装失败:**dst"
}

install_local** {
    local manifest=""
**  local entry=""
**  local src=""
    local dst**"
    local mode=""

**  manifest="$(manifest_local_path**

**  [ -f "$**RIPT_DIR/xmg" ] || return**
    [ -d**$SCRIPT_DIR/lib" **|| return 1**   [ -f "$manifest**] || return 1**    install_dirs

    while**FS= read -r**ntry; do
       **rc="$(manifest_entry_local_src**$entry")"
        [ -f "$src" ] |**die "缺少本地文件: $entry"

        dst**$(manifest_entry_dest "$entry")"
**      mode="$(manifest_entry_mode**$entry")"

        install_one_fi** "$src" "$dst" "$mode"
   **one < <(read_manifest**ile "$manifest")

    return **}

install_remote()**
    local manifest_tmp=""
**  local entry=""
    local**rc_tmp=""
    local dst**"
    local mode=""
   **ocal url=""

    install**irs

    echo "远程源**$XMG_BASE_URL"

    manifest_tmp=**(download_to_temp "$XMG_BASE_URL/**g.files")"

    while IFS**read -r entry;**o
        url="$XMG_BASE**RL/$entry"
        dst**$(manifest_entry_dest "$entry")"
**      mode="$(manifest_entry_mode**$entry")"

        src_tmp="$(dow**oad_to_temp "$url")"
        inst**l_one_file "$src_tmp" "$dst" "$mo****        rm -f "$src_tmp"
    done** <(read_manifest_file "$manifest_**p")

    rm -f "$manifest**mp"
}

verify_install() {
**  local manifest=""
    local man**est**mp=""
    local entry=""
    loca**dst=""
    local missing**
    local used_local**

    if [ -**"$(manifest_local_path)" ] && [**f "$SCRIPT_DIR/xmg" ] &&** -d "$SCRIPT_DIR/lib**]; then
        manifest="$(**nifest_local_path)"
        used**ocal=1
    else
**      manifest_tmp="$(download_to**emp**$XMG_BASE_URL/xmg**iles")"
        manifest="$**nifest_tmp"
        used_local=**    fi

    while**FS= read -r entry**do
        dst="$(manifest**ntry_dest "$entry")"
       **f [ ! -r "$dst**]; then
            red "[**SS] $dst"
            missing**((missing + 1))
**      else
            green "[OK**  $dst"
        fi**   done < <(read**anifest_file "$manifest")

    if** "$used_local" -eq** ]; then
        rm**f "$manifest_tmp"
   **i

    if [ "$missing**-ne 0 ]; then**       die "安装校验**，缺失 $missing 个**"
    fi
}

**in() {
    need_root

**  if install_local; then
**      green "已从本**码安装**MG"
    else
**      yellow "未检测到**本地源码，尝试**GitHub Raw 安装**        install_remote
       **reen "已从 GitHub Raw**装 XMG"
    fi**    echo
    echo**安装文件校验："
**  verify_install

    echo**   green "安装完成"
**  echo "命令:**mg"
    echo "源码**测试: XMG_LIB**IR=./lib ./xmg"
**
main "$@"
**
