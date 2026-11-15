#!/bin/bash
# 05-sync-pull.sh — 从 GitHub 拉取对方放的东西
# 用法:
#   ./05-sync-pull.sh
#   ./05-sync-pull.sh --repo-dir ~/valheim-lan-coop
#   ./05-sync-pull.sh --quiet

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

REPO_DIR=""
QUIET=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo-dir) REPO_DIR="$2"; shift 2 ;;
        --quiet)    QUIET=1; shift ;;
        -h|--help)  echo "用法: $0 [--repo-dir <仓库根目录>] [--quiet]"; exit 0 ;;
        *) bad "未知参数: $1"; exit 1 ;;
    esac
done

printf '\n%sValheim LAN Coop - 同步拉取%s\n' "$C_RESET" "$C_RESET"
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

# ---------- git 可用性 ----------
if ! command -v git >/dev/null 2>&1; then
    bad "未安装 git"
    info "xcode-select --install"
    exit 1
fi

# ---------- 远程 ----------
head "远程仓库"
REMOTE=$(git remote -v 2>/dev/null | head -1)
if [[ -z "$REMOTE" ]]; then
    bad "未配置远程仓库"
    info "执行: git remote add origin git@github.com:zengjunzhe/valheim-lan-coop.git"
    exit 1
fi
info "$REMOTE"

# ---------- 本地改动 ----------
head "检查本地改动"
DIRTY=$(git status --porcelain)
if [[ -n "$DIRTY" ]]; then
    warn "本地有未提交改动:"
    echo "$DIRTY" | head -15 | while read -r l; do info "$l"; done
    [[ $(echo "$DIRTY" | wc -l) -gt 15 ]] && info "... 还有更多"
    warn "pull 前需要处理"
    read -r -p "  用 stash 暂存后继续? (y/N) " ans
    if [[ "$ans" == "y" ]]; then
        git stash push -u -m "auto-stash before pull $(date +%Y%m%d_%H%M%S)" >/dev/null 2>&1
        ok "已 stash"
        STASHED=1
    else
        warn "已中止。请先处理本地改动"
        exit 1
    fi
else
    ok "工作区干净"
    STASHED=0
fi

# ---------- 拉取 ----------
head "拉取"
info "执行: git pull --rebase --autostash"
if PULL_OUT=$(git pull --rebase --autostash 2>&1); then
    echo "$PULL_OUT" | while read -r l; do info "$l"; done
    ok "拉取完成"
else
    echo "$PULL_OUT" | while read -r l; do info "$l"; done
    bad "拉取失败"
    info "可能原因:"
    info "  1. SSH key 未配置 → 见 docs/07-git-as-bridge.md"
    info "  2. 网络问题"
    info "  3. 冲突 → git status 查看后手动解决"
    exit 1
fi

# ---------- 展示对方内容 ----------
if [[ $QUIET -eq 0 ]]; then
    head "Windows 侧状态"
    if [[ -f "sync/shared/status-windows.md" ]]; then
        cat "sync/shared/status-windows.md" | while read -r l; do info "$l"; done
    else
        info "（尚无 status-windows.md）"
    fi

    head "Windows 放的诊断"
    if [[ -d "sync/diag/windows" ]]; then
        COUNT=$(find "sync/diag/windows" -type f 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$COUNT" -gt 0 ]]; then
            find "sync/diag/windows" -type f -exec ls -lt {} + 2>/dev/null | head -5 | while read -r l; do info "$l"; done
        else
            info "（空）"
        fi
    else
        info "（目录不存在）"
    fi

    head "Windows 放的存档"
    if [[ -d "sync/saves/windows" ]]; then
        COUNT=$(find "sync/saves/windows" -type f 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$COUNT" -gt 0 ]]; then
            find "sync/saves/windows" -type f 2>/dev/null | while read -r f; do
                info "$(basename "$f")  ($(du -h "$f" | cut -f1))"
            done
        else
            info "（空）"
        fi
    else
        info "（目录不存在）"
    fi

    head "Windows 放的文件"
    if [[ -d "sync/from-windows" ]]; then
        COUNT=$(find "sync/from-windows" -type f 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$COUNT" -gt 0 ]]; then
            find "sync/from-windows" -type f 2>/dev/null | while read -r f; do
                info "$(basename "$f")  ($(du -h "$f" | cut -f1))"
            done
        else
            info "（空）"
        fi
    else
        info "（目录不存在）"
    fi

    head "留言板"
    if [[ -f "sync/shared/notes.md" ]]; then
        tail -20 "sync/shared/notes.md" | while read -r l; do info "$l"; done
    else
        info "（无 notes.md）"
    fi
fi

# ---------- 恢复 stash ----------
if [[ "${STASHED:-0}" -eq 1 ]]; then
    head "恢复暂存的改动"
    info "执行: git stash pop"
    if POP_OUT=$(git stash pop 2>&1); then
        echo "$POP_OUT" | while read -r l; do info "$l"; done
        ok "已恢复"
    else
        echo "$POP_OUT" | while read -r l; do info "$l"; done
        warn "恢复失败，改动仍在 stash 里: git stash list"
    fi
fi

line
ok "同步拉取完成"
printf '\n%s下一步: 若你有东西要传给 Windows，跑 ./06-sync-push.sh%s\n\n' "$C_GRAY" "$C_RESET"
