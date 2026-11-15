#!/bin/bash
# 02-apply-goldberg.sh — 给 Steam 版 Valheim 打 Goldberg 补丁（Mac）
# 用法:
#   ./02-apply-goldberg.sh --goldberg-dir ~/goldberg
#   ./02-apply-goldberg.sh --goldberg-dir ~/goldberg --account-name PlayerB --steam-id 76561198000000002
#   ./02-apply-goldberg.sh --goldberg-dir ~/goldberg --app /Applications/Valheim.app

set -uo pipefail

C_RESET=$'\033[0m'
C_CYAN=$'\033[0;36m'
C_GREEN=$'\033[0;32m'
C_YELLOW=$'\033[0;33m'
C_RED=$'\033[0;31m'
C_GRAY=$'\033[0;90m'
C_MAGENTA=$'\033[0;35m'

line() { printf '%s\n' "--------------------------------------------------------------"; }
head() { printf '\n%s== %s ==%s\n' "$C_CYAN" "$1" "$C_RESET"; }
ok()   { printf '  %s[OK]%s   %s\n' "$C_GREEN" "$C_RESET" "$1"; }
warn() { printf '  %s[WARN]%s %s\n' "$C_YELLOW" "$C_RESET" "$1"; }
bad()  { printf '  %s[FAIL]%s %s\n' "$C_RED" "$C_RESET" "$1"; }
info() { printf '         %s%s%s\n' "$C_GRAY" "$1" "$C_RESET"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/role.sh
source "$SCRIPT_DIR/lib/role.sh" 2>/dev/null || true

GOLDBERG_DIR=""
APP=""
ACCOUNT_NAME=""
STEAM_ID=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --goldberg-dir) GOLDBERG_DIR="$2"; shift 2 ;;
        --app)          APP="$2"; shift 2 ;;
        --account-name) ACCOUNT_NAME="$2"; shift 2 ;;
        --steam-id)     STEAM_ID="$2"; shift 2 ;;
        -h|--help)
            echo "用法: $0 --goldberg-dir <目录> [--app <Valheim.app>] [--account-name <名字>] [--steam-id <ID>]"
            exit 0 ;;
        *) bad "未知参数: $1"; exit 1 ;;
    esac
done

# ---------- 读角色配置 ----------
REPO_ROOT="$(find_repo_root "$SCRIPT_DIR" 2>/dev/null || true)"
MY_ROLE="host"
if [[ -n "$REPO_ROOT" ]]; then
    eval "$(read_role_conf "$REPO_ROOT")"
    MY_ROLE="$(this_machine_role "$REPO_ROOT")"
fi

# 命令行没指定身份时，用配置里的
if [[ -z "$ACCOUNT_NAME" || -z "$STEAM_ID" ]]; then
    read -r CONF_NAME CONF_SID CONF_ROLE <<< "$(my_identity "$REPO_ROOT" 2>/dev/null || echo 'PlayerA 76561198000000001 host')"
    [[ -z "$ACCOUNT_NAME" ]] && ACCOUNT_NAME="$CONF_NAME"
    [[ -z "$STEAM_ID" ]] && STEAM_ID="$CONF_SID"
fi

printf '\n%sValheim LAN Coop - 应用 Goldberg 补丁（Mac）%s\n' "$C_RESET" "$C_RESET"

# ---------- 平台检查 ----------
if [[ "$(uname -s)" != "Darwin" ]]; then
    printf '\n%s[FAIL]%s 本脚本只能在 macOS 上运行（当前: %s）\n\n' "$C_RED" "$C_RESET" "$(uname -s)"
    exit 1
fi

line

# ---------- 定位 App ----------
head "定位 Valheim.app"
if [[ -z "$APP" ]]; then
    for p in "/Applications/Valheim.app" "$HOME/Applications/Valheim.app"; do
        [[ -d "$p" ]] && { APP="$p"; break; }
    done
fi
if [[ -z "$APP" || ! -d "$APP" ]]; then
    bad "未找到 Valheim.app"
    info "请用 --app 指定，例如: --app /Applications/Valheim.app"
    exit 1
fi
ok "App: $APP"

# ---------- Steam 进程 ----------
head "检查 Steam 进程"
if pgrep -x "steam_osx" >/dev/null 2>&1 || pgrep -x "Steam" >/dev/null 2>&1; then
    warn "Steam 正在运行"
    read -r -p "  关闭 Steam 后继续? (y/N) " ans
    if [[ "$ans" == "y" ]]; then
        osascript -e 'quit app "Steam"' 2>/dev/null
        sleep 3
        pkill -x "steam_osx" 2>/dev/null
        pkill -x "Steam" 2>/dev/null
        sleep 1
        ok "Steam 已关闭"
    else
        exit 1
    fi
else
    ok "Steam 未运行"
fi

# ---------- 定位 Goldberg dylib ----------
head "定位 Goldberg dylib"
if [[ -z "$GOLDBERG_DIR" ]]; then
    bad "请用 --goldberg-dir 指定 Goldberg 解压目录"
    info "下载: https://github.com/Mr_Goldberg/goldberg_emulator/releases"
    exit 1
fi

SRC=""
for c in \
    "$GOLDBERG_DIR/libsteam_api.dylib" \
    "$GOLDBERG_DIR/lib/libsteam_api.dylib" \
    "$GOLDBERG_DIR/release/libsteam_api.dylib" \
    "$GOLDBERG_DIR/build/libsteam_api.dylib" \
    "$GOLDBERG_DIR/build/macos/libsteam_api.dylib"
do
    [[ -f "$c" ]] && { SRC="$c"; break; }
done

if [[ -z "$SRC" ]]; then
    bad "在 $GOLDBERG_DIR 找不到 libsteam_api.dylib"
    info "当前目录内容:"
    ls -la "$GOLDBERG_DIR" 2>/dev/null | while read -r l; do info "  $l"; done
    info "找不到 macOS 版说明该 release 只提供 Windows 构建"
    info "解决: 从源码编译，或用 CrossOver 备选方案"
    exit 1
fi
ok "源文件: $SRC ($(stat -f%z "$SRC") bytes)"

# ---------- 架构校验 ----------
head "架构校验"
MACHINE=$(uname -m)
SRC_ARCH=$(lipo -archs "$SRC" 2>/dev/null || echo "unknown")
info "本机: $MACHINE"
info "dylib: $SRC_ARCH"

if [[ "$MACHINE" == "arm64" ]]; then
    if [[ "$SRC_ARCH" != *"arm64"* ]]; then
        bad "架构不匹配！Apple Silicon 需要 arm64，实际 $SRC_ARCH"
        info "继续会闪退。建议中止。"
        read -r -p "  仍要继续? (y/N) " ans
        [[ "$ans" != "y" ]] && exit 1
    else
        ok "架构匹配"
    fi
else
    if [[ "$SRC_ARCH" != *"x86_64"* ]]; then
        bad "架构不匹配！需要 x86_64，实际 $SRC_ARCH"
        read -r -p "  仍要继续? (y/N) " ans
        [[ "$ans" != "y" ]] && exit 1
    else
        ok "架构匹配"
    fi
fi

# ---------- 备份并覆盖 ----------
head "备份并覆盖 dylib"
DYLIB=$(find "$APP" -name "libsteam_api.dylib" -not -name "*.orig" 2>/dev/null | head -1)
if [[ -z "$DYLIB" ]]; then
    bad "未找到 libsteam_api.dylib"
    info "搜索所有 steam_api 相关文件:"
    find "$APP" -name "*steam_api*" 2>/dev/null | while read -r f; do info "  $f"; done
    exit 1
fi
ok "目标: $DYLIB"

if [[ ! -f "$DYLIB.orig" ]]; then
    cp -p "$DYLIB" "$DYLIB.orig"
    ok "已备份 → $DYLIB.orig"
else
    info "备份已存在，保留原始 .orig"
fi

if ! cp -f "$SRC" "$DYLIB"; then
    bad "覆盖失败（可能权限不足）"
    info "尝试: sudo cp '$SRC' '$DYLIB'"
    exit 1
fi
ok "已覆盖 ($(stat -f%z "$DYLIB") bytes)"

# ---------- steam_settings ----------
head "创建 steam_settings"
# Goldberg 在 macOS 上可能从多个位置查找，两处都写
TARGETS=(
    "$APP/Contents/MacOS/steam_settings"
    "$(dirname "$DYLIB")/steam_settings"
)

for ss in "${TARGETS[@]}"; do
    mkdir -p "$ss" || { warn "无法创建 $ss（权限？）"; continue; }

    printf '892970' > "$ss/steam_appid.txt"
    cat > "$ss/configs.user.ini" <<EOF
[user::general]
account_name=$ACCOUNT_NAME
account_steamid=$STEAM_ID
language=schinese
EOF
    cat > "$ss/configs.main.ini" <<'EOF'
[main::general]
enable_lan_only=1

[main::connectivity]
disable_networking=0
EOF
    ok "已写入: $ss"
done

info "身份: $ACCOUNT_NAME / $STEAM_ID"
if [[ "$MY_ROLE" == "host" ]]; then
    info "角色: 主机（开世界）— 来自 config/role.conf"
else
    info "角色: 客机（加入）— 来自 config/role.conf"
fi
info "enable_lan_only=1（关键：跳过 Steam ticket 校验）"

# ---------- 重签名 ----------
head "重签名"
info "执行: codesign --force --deep --sign - $APP"
if codesign --force --deep --sign - "$APP" 2>&1 | while read -r l; do info "$l"; done; then
    ok "重签名完成"
else
    warn "重签名报错，尝试清理扩展属性后重试"
    xattr -cr "$APP" 2>/dev/null
    if codesign --force --deep --sign - "$APP" 2>/dev/null; then
        ok "重试成功"
    else
        bad "重签名失败"
        info "手动执行: xattr -cr '$APP' && codesign --force --deep --sign - '$APP'"
    fi
fi

xattr -dr com.apple.quarantine "$APP" 2>/dev/null && ok "已清除 quarantine"

# ---------- 验证 ----------
head "验证结果"
ALL_OK=1
for f in "$DYLIB" "$DYLIB.orig"; do
    if [[ -f "$f" ]]; then ok "$(basename "$f") ($(stat -f%z "$f") bytes)"; else bad "$(basename "$f") 缺失"; ALL_OK=0; fi
done
for ss in "${TARGETS[@]}"; do
    if [[ -d "$ss" ]]; then
        ok "$ss"
        for f in steam_appid.txt configs.user.ini configs.main.ini; do
            [[ -f "$ss/$f" ]] && info "  $f" || { bad "  $f 缺失"; ALL_OK=0; }
        done
    fi
done

line
if [[ $ALL_OK -eq 1 ]]; then
    ok "补丁应用成功"
    printf '\n%s下一步: ./03-resign.sh（若上面重签名已成功，可直接跳到 04）%s\n' "$C_RESET" "$C_RESET"
    printf '  ./03-resign.sh\n  ./04-launch.sh\n\n'
else
    bad "有文件缺失，请检查上面的错误"
    exit 1
fi
