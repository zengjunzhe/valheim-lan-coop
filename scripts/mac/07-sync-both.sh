#!/bin/bash
# 07-sync-both.sh — 一键：先拉再推
# 用法:
#   ./07-sync-both.sh
#   ./07-sync-both.sh --saves --diag -m "世界已开"

set -uo pipefail

C_RESET=$'\033[0m'
C_CYAN=$'\033[0;36m'
C_GREEN=$'\033[0;32m'
C_YELLOW=$'\033[0;33m'
C_GRAY=$'\033[0;90m'

line() { printf '%s\n' "--------------------------------------------------------------"; }

REPO_DIR=""
SAVES=0
DIAG=0
MESSAGE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo-dir) REPO_DIR="$2"; shift 2 ;;
        --saves)    SAVES=1; shift ;;
        --diag)     DIAG=1; shift ;;
        -m|--message) MESSAGE="$2"; shift 2 ;;
        -h|--help)  echo "用法: $0 [--saves] [--diag] [-m 说明] [--repo-dir 目录]"; exit 0 ;;
        *) printf '  %s[FAIL]%s 未知参数: %s\n' $'\033[0;31m' "$C_RESET" "$1"; exit 1 ;;
    esac
done

printf '\n%sValheim LAN Coop - 双向同步%s\n' "$C_RESET" "$C_RESET"

# ---------- 平台检查 ----------
if [[ "$(uname -s)" != "Darwin" ]]; then
    printf '\n%s[FAIL]%s 本脚本只能在 macOS 上运行（当前: %s）\n\n' "$C_RED" "$C_RESET" "$(uname -s)"
    exit 1
fi

line

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON=()
[[ -n "$REPO_DIR" ]] && COMMON+=(--repo-dir "$REPO_DIR")

printf '\n%s>>> 第一步：拉取对方更新%s\n' "$C_CYAN" "$C_RESET"
"$HERE/05-sync-pull.sh" "${COMMON[@]}" --quiet
PULL_RC=$?

printf '\n%s>>> 第二步：推送自己的更新%s\n' "$C_CYAN" "$C_RESET"
PUSH_ARGS=("${COMMON[@]}")
[[ $SAVES -eq 1 ]] && PUSH_ARGS+=(--saves)
[[ $DIAG -eq 1 ]]  && PUSH_ARGS+=(--diag)
[[ -n "$MESSAGE" ]] && PUSH_ARGS+=(-m "$MESSAGE")
"$HERE/06-sync-push.sh" "${PUSH_ARGS[@]}"
PUSH_RC=$?

line
if [[ $PULL_RC -eq 0 && $PUSH_RC -eq 0 ]]; then
    printf '  %s双向同步完成%s\n\n' "$C_GREEN" "$C_RESET"
else
    printf '  %s有步骤失败（pull=%s push=%s），检查上面的输出%s\n\n' "$C_YELLOW" "$PULL_RC" "$PUSH_RC" "$C_RESET"
fi
