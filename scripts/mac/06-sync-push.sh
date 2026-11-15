#!/bin/bash
# 06-sync-push.sh — 把自己的东西推到 GitHub 中转
# 用法:
#   ./06-sync-push.sh
#   ./06-sync-push.sh --saves
#   ./06-sync-push.sh --diag -m "世界已开"

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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/role.sh
source "$SCRIPT_DIR/lib/role.sh" 2>/dev/null || true

REPO_DIR=""
SAVES=0
DIAG=0
MESSAGE=""
NO_PUSH=0
SAVE_LIMIT_MB=50

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo-dir) REPO_DIR="$2"; shift 2 ;;
        --app)      shift 2 ;;
        --saves)    SAVES=1; shift ;;
        --diag)     DIAG=1; shift ;;
        -m|--message) MESSAGE="$2"; shift 2 ;;
        --no-push)  NO_PUSH=1; shift ;;
        -h|--help)  echo "用法: $0 [--saves] [--diag] [-m 说明] [--no-push] [--repo-dir 目录]"; exit 0 ;;
        *) bad "未知参数: $1"; exit 1 ;;
    esac
done

printf '\n%sValheim LAN Coop - 同步推送%s\n' "$C_RESET" "$C_RESET"

# ---------- 平台检查 ----------
if [[ "$(uname -s)" != "Darwin" ]]; then
    printf '\n%s[FAIL]%s 本脚本只能在 macOS 上运行（当前: %s）\n\n' "$C_RED" "$C_RESET" "$(uname -s)"
    exit 1
fi

line

# ---------- 定位仓库 ----------
head "定位仓库"
if [[ -z "$REPO_DIR" ]]; then
    CUR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    while [[ -n "$CUR" && "$CUR" != "/" ]]; do
        if [[ -d "$CUR/.git" ]]; then REPO_DIR="$CUR"; break; fi
        CUR="$(dirname "$CUR")"
    done
fi
if [[ -z "$REPO_DIR" || ! -d "$REPO_DIR/.git" ]]; then
    bad "未找到 git 仓库。请用 --repo-dir 指定"
    exit 1
fi
ok "仓库: $REPO_DIR"
cd "$REPO_DIR" || exit 1

command -v git >/dev/null 2>&1 || { bad "未安装 git"; exit 1; }

# ---------- 定位 Valheim ----------
APP=""
for p in "/Applications/Valheim.app" "$HOME/Applications/Valheim.app"; do
    [[ -d "$p" ]] && { APP="$p"; break; }
done

# ---------- 读角色配置 ----------
REPO_ROOT="$(find_repo_root "$SCRIPT_DIR" 2>/dev/null || true)"
MY_ROLE="host"
MY_NAME="PlayerA"
MY_SID="76561198000000001"
if [[ -n "$REPO_ROOT" ]]; then
    eval "$(read_role_conf "$REPO_ROOT")"
    MY_ROLE="$(this_machine_role "$REPO_ROOT")"
    read -r MY_NAME MY_SID _ <<< "$(my_identity "$REPO_ROOT")"
fi

# ---------- 收集状态 ----------
head "收集本机状态"
NOW=$(date "+%Y-%m-%d %H:%M:%S")
HOSTNAME_V=$(hostname)

IP=$(ifconfig 2>/dev/null | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | grep '^192\.168\.' | head -1)
[[ -z "$IP" ]] && IP=$(ifconfig 2>/dev/null | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | head -1)
[[ -z "$IP" ]] && IP="未知"

ARCH=$(uname -m)

BUILDID="未知"
ACF="$HOME/Library/Application Support/Steam/steamapps/appmanifest_892970.acf"
if [[ -f "$ACF" ]]; then
    BUILDID=$(grep -A1 '"buildid"' "$ACF" 2>/dev/null | grep -oE '[0-9]{6,}' | head -1)
    [[ -z "$BUILDID" ]] && BUILDID=$(grep '"buildid"' "$ACF" | grep -oE '[0-9]+' | head -1)
fi

DYLIB_ARCH="未知"
PATCH_STATUS="未打"
SIGN_STATUS="未知"
if [[ -n "$APP" ]]; then
    DYLIB=$(find "$APP" -name "libsteam_api.dylib" -not -name "*.orig" 2>/dev/null | head -1)
    [[ -n "$DYLIB" ]] && DYLIB_ARCH=$(lipo -archs "$DYLIB" 2>/dev/null || echo "未知")
    if [[ -n "$DYLIB" && -f "$DYLIB.orig" ]]; then
        SS=$(find "$APP" -name "configs.main.ini" -maxdepth 6 2>/dev/null | head -1)
        if [[ -n "$SS" ]] && grep -qE '^enable_lan_only\s*=\s*1' "$SS"; then
            PATCH_STATUS="已打（enable_lan_only=1）"
        else
            PATCH_STATUS="已打（但 enable_lan_only 未设）"
        fi
    fi
    if codesign -v "$APP" 2>/dev/null; then SIGN_STATUS="有效"; else SIGN_STATUS="无效"; fi
else
    APP="未找到"
fi

STEAM_PROC="未运行"
pgrep -x "steam_osx" >/dev/null 2>&1 && STEAM_PROC="运行中"
pgrep -x "Steam" >/dev/null 2>&1 && STEAM_PROC="运行中"

# 主机才有端口监听
WORLD_STATE="不适用（客机）"
if [[ "$MY_ROLE" == "host" ]]; then
    if netstat -an 2>/dev/null | grep -qE "udp.*\.2456|udp46.*2456"; then
        WORLD_STATE="已开启（端口 2456 监听中）"
    else
        WORLD_STATE="未开启"
    fi
fi

ok "IP=$IP  buildid=$BUILDID  架构=$ARCH  补丁=$PATCH_STATUS"

# ---------- 写状态文件 ----------
head "写 status-mac.md"
cat > "sync/shared/status-mac.md" <<EOF
# Mac 状态

> 由 \`06-sync-push.sh\` 自动生成。手动改也行，但下次推送会覆盖。

\`\`\`
更新时间   : $NOW
主机名     : $HOSTNAME_V
本机角色   : $(if [[ "$MY_ROLE" == "host" ]]; then echo "主机（开世界）"; else echo "客机（加入）"; fi)
身份       : $MY_NAME / $MY_SID
内网 IP    : $IP
buildid    : $BUILDID
架构       : $ARCH
dylib 架构 : $DYLIB_ARCH
Valheim    : $APP
补丁状态   : $PATCH_STATUS
签名状态   : $SIGN_STATUS
Steam 进程 : $STEAM_PROC
\`\`\`

## 备注

$(if [[ -n "$MESSAGE" ]]; then echo "$MESSAGE"; else echo "（本次推送无附加留言）"; fi)
EOF
ok "已写入"

# ---------- 拷存档 ----------
if [[ $SAVES -eq 1 ]]; then
    head "拷贝存档"
    SAVE_SRC="$HOME/.config/unity3d/IronGate/Valheim"
    if [[ ! -d "$SAVE_SRC" ]]; then
        warn "存档目录不存在: $SAVE_SRC"
    else
        DST="sync/saves/mac"
        mkdir -p "$DST"
        find "$DST" -type f -delete 2>/dev/null

        TOTAL_KB=0
        COPIED=0
        for sub in worlds characters; do
            S="$SAVE_SRC/$sub"
            [[ -d "$S" ]] || continue
            while IFS= read -r f; do
                SZ_KB=$(( $(stat -f%z "$f" 2>/dev/null || echo 0) / 1024 ))
                if [[ $SZ_KB -gt $((SAVE_LIMIT_MB * 1024)) ]]; then
                    warn "跳过 $(basename "$f")（$((SZ_KB/1024)) MB > 上限 ${SAVE_LIMIT_MB} MB）"
                    info "  大存档建议本地备份，不推 Git"
                    continue
                fi
                cp -f "$f" "$DST/" 2>/dev/null && { TOTAL_KB=$((TOTAL_KB + SZ_KB)); COPIED=$((COPIED+1)); }
            done < <(find "$S" -type f 2>/dev/null)
        done

        if [[ $COPIED -gt 0 ]]; then
            ok "拷贝 $COPIED 个文件，共 $((TOTAL_KB/1024)) MB → sync/saves/mac/"
            if [[ "$MY_ROLE" == "host" ]]; then
                info "本机是主机 → 这里的世界存档是权威版本，Windows 拉下来就是备份"
            else
                info "本机是客机 → 这里的角色存档属于 $MY_NAME"
            fi
            if [[ $TOTAL_KB -gt 20480 ]]; then
                warn "存档较大（$((TOTAL_KB/1024)) MB），仓库会持续变大"
                info "长期使用建议只推 .fwl，或定期 git gc"
            fi
        else
            info "没有可拷贝的存档文件"
        fi
    fi
fi

# ---------- 生成诊断 ----------
if [[ $DIAG -eq 1 ]]; then
    head "生成诊断"
    DIAG_DIR="sync/diag/mac"
    mkdir -p "$DIAG_DIR"
    STAMP=$(date +%Y%m%d_%H%M%S)
    DIAG_FILE="$DIAG_DIR/diag-$STAMP.txt"

    {
        echo "=== Mac 诊断 $NOW ==="
        echo ""
        echo "--- 系统 ---"
        echo "macOS: $(sw_vers -productVersion 2>/dev/null) ($(sw_vers -buildVersion 2>/dev/null))"
        echo "架构: $ARCH"
        echo "主机名: $HOSTNAME_V"
        echo ""
        echo "--- 网络 ---"
        ifconfig 2>/dev/null | grep "inet " | grep -v "127.0.0.1"
        echo ""
        echo "--- Valheim ---"
        echo "App: $APP"
        echo "buildid: $BUILDID"
        echo "dylib 架构: $DYLIB_ARCH"
        echo "补丁: $PATCH_STATUS"
        echo "签名: $SIGN_STATUS"
        echo ""
        echo "--- steam_settings ---"
        if [[ -n "$APP" && "$APP" != "未找到" ]]; then
            while IFS= read -r ss; do
                echo "== $ss =="
                ls -la "$ss" 2>/dev/null
                for f in steam_appid.txt configs.user.ini configs.main.ini; do
                    [[ -f "$ss/$f" ]] && { echo "--- $f ---"; cat "$ss/$f"; }
                done
            done < <(find "$APP" -name "steam_settings" -maxdepth 6 -type d 2>/dev/null)
            echo ""
            echo "--- dylib ---"
            if [[ -n "${DYLIB:-}" ]]; then
                echo "路径: $DYLIB"
                ls -la "$DYLIB" 2>/dev/null
                [[ -f "$DYLIB.orig" ]] && ls -la "$DYLIB.orig" 2>/dev/null
            fi
        fi
        echo ""
        echo "--- 最近崩溃日志 ---"
        ls -lt ~/Library/Logs/DiagnosticReports/ 2>/dev/null | head -5
        echo ""
        echo "--- 签名验证 ---"
        codesign -vv "$APP" 2>&1 || true
    } > "$DIAG_FILE" 2>&1

    ok "诊断 → $DIAG_FILE"
fi

# ---------- git 提交推送 ----------
head "提交并推送"
git add sync/ 2>/dev/null

STAGED=$(git diff --cached --name-only 2>/dev/null)
if [[ -z "$STAGED" ]]; then
    info "sync/ 下无变化，跳过提交"
else
    info "暂存文件:"
    echo "$STAGED" | head -20 | while read -r l; do info "  $l"; done

    COMMIT_MSG="sync(mac): ${MESSAGE:-$NOW}"
    if git commit -q -m "$COMMIT_MSG" 2>/dev/null; then
        ok "已提交: $COMMIT_MSG"
    else
        warn "提交失败"
    fi
fi

if [[ $NO_PUSH -eq 1 ]]; then
    info "--no-push 指定，不推送"
else
    info "执行: git pull --rebase --autostash && git push"
    git pull --rebase --autostash 2>&1 | while read -r l; do info "$l"; done
    if git push 2>&1 | while read -r l; do info "$l"; done; then
        ok "推送成功"
    else
        bad "推送失败"
    fi
fi

line
ok "同步推送完成"
printf '\n%sWindows 侧跑 05-sync-pull.ps1 即可看到%s\n\n' "$C_GRAY" "$C_RESET"
