#!/bin/bash
# 01-detect.sh — Mac 环境探测
# 用法: ./01-detect.sh

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

printf '\n%sValheim LAN Coop - Mac 环境探测%s\n' "$C_RESET" "$C_RESET"

# ---------- 平台检查 ----------
if [[ "$(uname -s)" != "Darwin" ]]; then
    printf '\n%s[FAIL]%s 本脚本只能在 macOS 上运行（当前: %s）\n\n' "$C_RED" "$C_RESET" "$(uname -s)"
    exit 1
fi

line

# ---------- 系统 ----------
head "系统"
ok "macOS   : $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
ok "架构    : $(uname -m)"
if [[ "$(uname -m)" == "arm64" ]]; then
    info "Apple Silicon — dylib 必须是 arm64 或 universal"
else
    info "Intel Mac — dylib 必须是 x86_64 或 universal"
fi
ok "主机名  : $(hostname)"

# ---------- Valheim ----------
head "Valheim 安装"
APP=""
for p in "/Applications/Valheim.app" "$HOME/Applications/Valheim.app"; do
    if [[ -d "$p" ]]; then APP="$p"; break; fi
done

if [[ -z "$APP" ]]; then
    bad "未找到 Valheim.app"
    info "请先在 Steam 里安装 Valheim"
    line
    exit 1
fi
ok "路径: $APP"

EXE="$APP/Contents/MacOS/valheim"
if [[ -f "$EXE" ]]; then
    ok "可执行文件存在"
    info "架构: $(lipo -archs "$EXE" 2>/dev/null || echo '未知')"
else
    bad "可执行文件缺失: $EXE"
fi

# ---------- dylib ----------
head "steam_api dylib"
DYLIB=$(find "$APP" -name "libsteam_api.dylib" -not -name "*.orig" 2>/dev/null | head -1)
if [[ -n "$DYLIB" ]]; then
    ok "路径: $DYLIB"
    SZ=$(stat -f%z "$DYLIB" 2>/dev/null)
    info "大小: $SZ bytes"
    ARCH=$(lipo -archs "$DYLIB" 2>/dev/null || echo "unknown")
    info "架构: $ARCH"

    MACHINE=$(uname -m)
    if [[ "$MACHINE" == "arm64" ]]; then
        if [[ "$ARCH" == *"arm64"* ]]; then
            ok "架构匹配（arm64）"
        else
            bad "架构不匹配！需要 arm64，实际 $ARCH"
            info "纯 x86_64 dylib 在 Apple Silicon 上会闪退"
            info "解决: 找 universal 构建，或用 CrossOver 备选方案"
        fi
    else
        if [[ "$ARCH" == *"x86_64"* ]]; then
            ok "架构匹配（x86_64）"
        else
            bad "架构不匹配！需要 x86_64，实际 $ARCH"
        fi
    fi

    if [[ -f "$DYLIB.orig" ]]; then
        ok "已存在备份 libsteam_api.dylib.orig（补丁已应用）"
    else
        info "无 .orig 备份（尚未打补丁，正常）"
    fi
else
    bad "未找到 libsteam_api.dylib"
    info "搜索: find $APP -name '*steam_api*'"
    find "$APP" -name "*steam_api*" 2>/dev/null | while read -r f; do info "  $f"; done
fi

# ---------- steam_settings ----------
head "steam_settings"
FOUND=0
while IFS= read -r ss; do
    FOUND=1
    ok "目录: $ss"
    ls -la "$ss" 2>/dev/null | tail -n +2 | while read -r l; do info "  $l"; done
    if [[ -f "$ss/configs.user.ini" ]]; then
        SID=$(grep -E '^account_steamid' "$ss/configs.user.ini" 2>/dev/null | cut -d= -f2 | tr -d ' ')
        info "account_steamid = ${SID:-未设置}"
    fi
    if [[ -f "$ss/configs.main.ini" ]]; then
        LAN=$(grep -E '^enable_lan_only' "$ss/configs.main.ini" 2>/dev/null | cut -d= -f2 | tr -d ' ')
        if [[ "$LAN" == "1" ]]; then ok "enable_lan_only = 1（正确）"; else bad "enable_lan_only = ${LAN:-缺失}（必须为 1）"; fi
    fi
done < <(find "$APP" -name "steam_settings" -maxdepth 6 -type d 2>/dev/null)

if [[ $FOUND -eq 0 ]]; then
    info "未找到 steam_settings（尚未打补丁）"
fi

# ---------- buildid ----------
head "版本（与 Windows 必须一致）"
ACF="$HOME/Library/Application Support/Steam/steamapps/appmanifest_892970.acf"
if [[ -f "$ACF" ]]; then
    BUILDID=$(grep -A1 '"buildid"' "$ACF" 2>/dev/null | grep -oE '[0-9]{6,}' | head -1)
    if [[ -z "$BUILDID" ]]; then
        BUILDID=$(grep '"buildid"' "$ACF" | grep -oE '[0-9]+' | head -1)
    fi
    printf '\n  %sbuildid = %s%s\n\n' "$C_MAGENTA" "${BUILDID:-未知}" "$C_RESET"
    info "Windows 侧核对: appmanifest_892970.acf 里的 buildid"
    info "两边必须相同，否则连不上"
else
    info "未找到 appmanifest（Steam 未安装或路径不同）"
    info "预期: $ACF"
fi

# ---------- Steam 进程 ----------
head "Steam 进程"
if pgrep -x "steam_osx" >/dev/null 2>&1 || pgrep -x "Steam" >/dev/null 2>&1; then
    warn "Steam 正在运行"
    warn "打补丁和启动游戏前请完全退出（Cmd+Q，检查菜单栏图标）"
    warn "原因：Steam 在线会校验授权，也会顶掉 Windows 侧同账号"
else
    ok "Steam 未运行（正确状态）"
fi

# ---------- 网络 ----------
head "网络（Windows 那台的 IP 填到这里）"
IFACES=$(ifconfig | grep "inet " | grep -v "127.0.0.1")
if [[ -n "$IFACES" ]]; then
    echo "$IFACES" | while read -r l; do ok "$(echo "$l" | awk '{print $2}')"; done
    PRIMARY=$(echo "$IFACES" | awk '{print $2}' | grep '^192\.168\.' | head -1)
    [[ -z "$PRIMARY" ]] && PRIMARY=$(echo "$IFACES" | awk '{print $2}' | head -1)
    printf '\n  %s>>> 本机 IP: %s%s\n' "$C_MAGENTA" "$PRIMARY" "$C_RESET"
    info "（客机用 Windows 的 IP，不是这个）"
else
    bad "未找到内网 IP"
fi

# ---------- 签名 ----------
head "代码签名"
if codesign -v "$APP" 2>/dev/null; then
    ok "签名有效"
else
    warn "签名无效（打了补丁后正常，需重新签名）"
    info "命令: codesign --force --deep --sign - $APP"
fi
Q=$(xattr -p com.apple.quarantine "$APP" 2>/dev/null)
if [[ -n "$Q" ]]; then
    warn "存在 quarantine 属性（会阻止启动）"
    info "命令: xattr -dr com.apple.quarantine $APP"
else
    ok "无 quarantine 属性"
fi

# ---------- 汇总 ----------
line
printf '%s下一步:%s\n' "$C_RESET" "$C_RESET"
printf '  1. 完全退出 Steam\n'
printf '  2. ./02-apply-goldberg.sh --goldberg-dir ~/goldberg\n'
printf '  3. ./03-resign.sh\n'
printf '  4. ./04-launch.sh\n'
printf '\n'
