#!/bin/bash
# 04-launch.sh — 启动 Valheim（客机模式，Join IP 连主机）
# 用法: ./04-launch.sh
#       ./04-launch.sh --host 192.168.1.23 --port 2456

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

APP=""
HOST=""
PORT=2456

while [[ $# -gt 0 ]]; do
    case "$1" in
        --app)  APP="$2"; shift 2 ;;
        --host) HOST="$2"; shift 2 ;;
        --port) PORT="$2"; shift 2 ;;
        -h|--help) echo "用法: $0 [--host <主机IP>] [--port <端口>] [--app <Valheim.app>]"; exit 0 ;;
        *) bad "未知参数: $1"; exit 1 ;;
    esac
done

printf '\n%sValheim LAN Coop - 启动（客机模式）%s\n' "$C_RESET" "$C_RESET"

# ---------- 平台检查 ----------
if [[ "$(uname -s)" != "Darwin" ]]; then
    printf '\n%s[FAIL]%s 本脚本只能在 macOS 上运行（当前: %s）\n\n' "$C_RED" "$C_RESET" "$(uname -s)"
    exit 1
fi

line

# ---------- 定位 ----------
head "定位 Valheim"
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

# ---------- 前置检查 ----------
head "前置检查"

DYLIB=$(find "$APP" -name "libsteam_api.dylib" -not -name "*.orig" 2>/dev/null | head -1)
if [[ -z "$DYLIB" ]]; then
    bad "未找到 libsteam_api.dylib"
    exit 1
fi
if [[ ! -f "$DYLIB.orig" ]]; then
    bad "未检测到补丁（缺 .orig 备份）"
    info "请先运行 ./02-apply-goldberg.sh"
    exit 1
fi
ok "补丁已应用"

SS=$(find "$APP" -name "configs.main.ini" -maxdepth 6 2>/dev/null | head -1)
if [[ -z "$SS" ]]; then
    bad "未找到 configs.main.ini"
    info "请先运行 ./02-apply-goldberg.sh"
    exit 1
fi
if grep -qE '^enable_lan_only\s*=\s*1' "$SS"; then
    ok "enable_lan_only = 1"
else
    bad "enable_lan_only 未设为 1，联机会失败"
    info "文件: $SS"
    exit 1
fi

# 签名
if ! codesign -v "$APP" 2>/dev/null; then
    warn "签名无效，自动重签名"
    codesign --force --deep --sign - "$APP" 2>/dev/null && ok "已重签" || { bad "重签名失败，跑 ./03-resign.sh"; exit 1; }
else
    ok "签名有效"
fi

# Steam 进程
if pgrep -x "steam_osx" >/dev/null 2>&1 || pgrep -x "Steam" >/dev/null 2>&1; then
    warn "Steam 正在运行，会干扰 Goldberg 身份并可能顶掉 Windows 侧"
    read -r -p "  关闭 Steam? (Y/n) " ans
    if [[ "$ans" != "n" ]]; then
        osascript -e 'quit app "Steam"' 2>/dev/null
        sleep 3
        pkill -x "steam_osx" 2>/dev/null
        pkill -x "Steam" 2>/dev/null
        sleep 1
        ok "Steam 已关闭"
    fi
else
    ok "Steam 未运行"
fi

# 游戏进程
if pgrep -f "Valheim.app/Contents/MacOS/valheim" >/dev/null 2>&1; then
    warn "Valheim 已在运行"
    read -r -p "  结束并重启? (y/N) " ans
    if [[ "$ans" == "y" ]]; then
        pkill -f "Valheim.app/Contents/MacOS/valheim" 2>/dev/null
        sleep 2
    else
        exit 0
    fi
fi

# ---------- 主机连通性 ----------
if [[ -n "$HOST" ]]; then
    head "测试主机连通性"
    info "目标: $HOST:$PORT"
    if ping -c 2 -W 1000 "$HOST" >/dev/null 2>&1; then
        ok "ICMP 可达"
    else
        warn "ICMP 不通（可能被防火墙拦，UDP 仍可能通）"
    fi
    info "UDP 端口无法用 nc 可靠探测，直接进游戏试"
fi

# ---------- 启动 ----------
head "启动"
info "执行: open -a \"$APP\""
if open -a "$APP" 2>&1; then
    ok "已启动"
    sleep 3
    if pgrep -f "Valheim.app/Contents/MacOS/valheim" >/dev/null 2>&1; then
        ok "进程运行中"
    else
        bad "进程未存活，可能启动即崩溃"
        info "查看崩溃日志:"
        info "  ls -lt ~/Library/Logs/DiagnosticReports/ | head -5"
        info "  log show --last 2m --predicate 'process CONTAINS \"alheim\"'"
        info "常见原因:"
        info "  1. 未重签名 → ./03-resign.sh"
        info "  2. dylib 架构不匹配 → lipo -info $DYLIB"
        exit 1
    fi
else
    bad "启动失败"
    exit 1
fi

# ---------- 后续 ----------
head "接下来"
info "1. 游戏内 Join Game"
info "2. 选 Join IP（不是 Join with code）"
if [[ -n "$HOST" ]]; then
    printf '\n  %s>>> 填: %s:%s%s\n\n' "$C_MAGENTA" "$HOST" "$PORT" "$C_RESET"
else
    info "3. 填 Windows 的内网 IP + 端口，例如 192.168.1.23:2456"
fi
info "4. Join IP 无效时，按 F5 开控制台: connect IP:PORT"

line
printf '关闭本终端不影响游戏。\n\n'
