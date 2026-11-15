#!/bin/bash
# 03-resign.sh — 重签名 Valheim.app（替换 dylib 后必需）
# 用法: ./03-resign.sh
#       ./03-resign.sh --app /Applications/Valheim.app

set -uo pipefail

C_RESET=$'\033[0m'
C_CYAN=$'\033[0;36m'
C_GREEN=$'\033[0;32m'
C_YELLOW=$'\033[0;33m'
C_RED=$'\033[0;31m'
C_GRAY=$'\033[0;90m'

line() { printf '%s\n' "--------------------------------------------------------------"; }
head() { printf '\n%s== %s ==%s\n' "$C_CYAN" "$1" "$C_RESET"; }
ok()   { printf '  %s[OK]%s   %s\n' "$C_GREEN" "$C_RESET" "$1"; }
warn() { printf '  %s[WARN]%s %s\n' "$C_YELLOW" "$C_RESET" "$1"; }
bad()  { printf '  %s[FAIL]%s %s\n' "$C_RED" "$C_RESET" "$1"; }
info() { printf '         %s%s%s\n' "$C_GRAY" "$1" "$C_RESET"; }

APP=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --app) APP="$2"; shift 2 ;;
        -h|--help) echo "用法: $0 [--app <Valheim.app>]"; exit 0 ;;
        *) bad "未知参数: $1"; exit 1 ;;
    esac
done

printf '\n%sValheim LAN Coop - 重签名%s\n' "$C_RESET" "$C_RESET"

# ---------- 平台检查 ----------
if [[ "$(uname -s)" != "Darwin" ]]; then
    printf '\n%s[FAIL]%s 本脚本只能在 macOS 上运行（当前: %s）\n\n' "$C_RED" "$C_RESET" "$(uname -s)"
    exit 1
fi

line

if [[ -z "$APP" ]]; then
    for p in "/Applications/Valheim.app" "$HOME/Applications/Valheim.app"; do
        [[ -d "$p" ]] && { APP="$p"; break; }
    done
fi
if [[ -z "$APP" || ! -d "$APP" ]]; then
    bad "未找到 Valheim.app，用 --app 指定"
    exit 1
fi
ok "App: $APP"

# ---------- 关闭进程 ----------
head "关闭进程"
if pgrep -f "Valheim.app/Contents/MacOS/valheim" >/dev/null 2>&1; then
    pkill -f "Valheim.app/Contents/MacOS/valheim" 2>/dev/null
    sleep 2
    ok "已关闭 Valheim"
else
    info "Valheim 未运行"
fi

# ---------- 清理扩展属性 ----------
head "清理扩展属性"
info "执行: xattr -cr $APP"
if xattr -cr "$APP" 2>/dev/null; then
    ok "扩展属性已清理"
else
    warn "清理部分失败（通常无碍）"
fi

Q=$(xattr -p com.apple.quarantine "$APP" 2>/dev/null)
if [[ -n "$Q" ]]; then
    xattr -dr com.apple.quarantine "$APP" 2>/dev/null
    ok "quarantine 已清除"
else
    ok "无 quarantine"
fi

# ---------- 签名 ----------
head "重签名"
info "执行: codesign --force --deep --sign - $APP"
OUT=$(codesign --force --deep --sign - "$APP" 2>&1)
RC=$?
if [[ -n "$OUT" ]]; then echo "$OUT" | while read -r l; do info "$l"; done; fi

if [[ $RC -eq 0 ]]; then
    ok "签名成功"
else
    bad "签名失败 (rc=$RC)"
    info "常见原因与处理:"
    info "  1. detritus not allowed → 已自动 xattr -cr，重试一次"
    info "  2. 文件系统权限 → 试 sudo codesign --force --deep --sign - $APP"
    info "  3. dylib 损坏 → 从 .orig 恢复后重试"
    exit 1
fi

# ---------- 验证 ----------
head "验证签名"
if codesign -vv "$APP" 2>&1 | while read -r l; do info "$l"; done; then
    ok "签名有效"
else
    warn "验证有警告（自签名通常正常）"
fi

# 检查 dylib 是否也被签
DYLIB=$(find "$APP" -name "libsteam_api.dylib" -not -name "*.orig" 2>/dev/null | head -1)
if [[ -n "$DYLIB" ]]; then
    if codesign -v "$DYLIB" 2>/dev/null; then
        ok "dylib 签名有效"
    else
        warn "dylib 未单独签名（deep 签名通常已覆盖）"
    fi
fi

# ---------- Gatekeeper ----------
head "Gatekeeper 检查"
if spctl -a -vv "$APP" 2>&1 | grep -q "rejected"; then
    warn "Gatekeeper 会拒绝（自签名正常现象）"
    info "首次启动如被拦：系统设置 → 隐私与安全性 → 仍要打开"
    info "或: xattr -dr com.apple.quarantine $APP"
else
    ok "Gatekeeper 未阻止"
fi

line
ok "重签名完成"
printf '\n%s下一步: ./04-launch.sh%s\n\n' "$C_RESET" "$C_RESET"
