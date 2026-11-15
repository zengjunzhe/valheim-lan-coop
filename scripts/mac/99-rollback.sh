#!/bin/bash
# 99-rollback.sh — 回滚到正版（Mac）
# 用法: ./99-rollback.sh
#       ./99-rollback.sh --app /Applications/Valheim.app --keep-settings

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
KEEP=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --app) APP="$2"; shift 2 ;;
        --keep-settings) KEEP=1; shift ;;
        -h|--help) echo "用法: $0 [--app <Valheim.app>] [--keep-settings]"; exit 0 ;;
        *) bad "未知参数: $1"; exit 1 ;;
    esac
done

printf '\n%sValheim LAN Coop - 回滚到正版（Mac）%s\n' "$C_RESET" "$C_RESET"

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
    bad "未找到 Valheim.app"
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

# ---------- 恢复 dylib ----------
head "恢复 libsteam_api.dylib"
DYLIB=$(find "$APP" -name "libsteam_api.dylib" -not -name "*.orig" 2>/dev/null | head -1)
if [[ -z "$DYLIB" ]]; then
    bad "未找到 libsteam_api.dylib"
else
    if [[ -f "$DYLIB.orig" ]]; then
        cp -f "$DYLIB.orig" "$DYLIB"
        ok "已恢复原版 ($(stat -f%z "$DYLIB") bytes)"
        info "备份保留: $DYLIB.orig"
    else
        warn "未找到 .orig 备份"
        info "解决: Steam → 库 → 右键 Valheim → 属性 → 已安装文件 → 验证完整性"
    fi
fi

# ---------- 处理 steam_settings ----------
head "处理 steam_settings"
COUNT=0
while IFS= read -r ss; do
    COUNT=$((COUNT+1))
    if [[ $KEEP -eq 1 ]]; then
        info "--keep-settings 指定，保留: $ss"
    else
        STAMP=$(date +%Y%m%d_%H%M%S)
        mv "$ss" "${ss}.bak_${STAMP}" 2>/dev/null && ok "已移走: $(basename "$ss").bak_${STAMP}" || warn "移动失败: $ss"
    fi
done < <(find "$APP" -name "steam_settings" -maxdepth 6 -type d 2>/dev/null)

[[ $COUNT -eq 0 ]] && info "未找到 steam_settings"

# ---------- 重签名 ----------
head "重签名"
info "执行: codesign --force --deep --sign - $APP"
xattr -cr "$APP" 2>/dev/null
if codesign --force --deep --sign - "$APP" 2>/dev/null; then
    ok "签名成功"
else
    warn "签名失败，试 sudo codesign --force --deep --sign - $APP"
fi
xattr -dr com.apple.quarantine "$APP" 2>/dev/null && ok "quarantine 已清除"

# ---------- 验证 ----------
head "验证"
OK_ALL=1
if [[ -n "$DYLIB" && -f "$DYLIB.orig" ]]; then
    if cmp -s "$DYLIB" "$DYLIB.orig"; then
        ok "dylib 与原版一致"
    else
        bad "dylib 与原版不一致"
        OK_ALL=0
    fi
fi
if find "$APP" -name "steam_settings" -maxdepth 6 -type d 2>/dev/null | grep -q .; then
    [[ $KEEP -eq 1 ]] && info "steam_settings 保留（按 -keep-settings）" || warn "steam_settings 仍存在"
else
    ok "steam_settings 已移除"
fi

if codesign -v "$APP" 2>/dev/null; then ok "签名有效"; else warn "签名验证有警告"; fi

line
if [[ $OK_ALL -eq 1 ]]; then
    ok "回滚完成"
    printf '\n%s现在可以正常通过 Steam 启动:%s\n' "$C_RESET" "$C_RESET"
    printf '  open steam://rungameid/892970\n\n'
    printf '%s存档未受影响:%s\n' "$C_GRAY" "$C_RESET"
    printf '  ~/.config/unity3d/IronGate/Valheim/\n\n'
else
    warn "回滚不完整，建议在 Steam 里验证文件完整性"
fi
