#!/bin/bash
# lib/role.sh — 通用配置读取，供其它脚本 source
# 用法: source "$(dirname "${BASH_SOURCE[0]}")/lib/role.sh"

# 向上查找仓库根
find_repo_root() {
    local cur="$1"
    while [[ -n "$cur" && "$cur" != "/" ]]; do
        if [[ -d "$cur/.git" ]]; then echo "$cur"; return 0; fi
        cur="$(dirname "$cur")"
    done
    return 1
}

# 读取 role.conf，输出 ROLE_* 变量赋值语句
# 用法: eval "$(read_role_conf "$REPO_DIR")"
read_role_conf() {
    local repo="${1:-}"
    local conf="$repo/config/role.conf"

    local v_role="mac"
    local v_hname="PlayerA"
    local v_hsid="76561198000000001"
    local v_cname="PlayerB"
    local v_csid="76561198000000002"
    local v_port="2456"

    if [[ -f "$conf" ]]; then
        local line k val
        while IFS= read -r line || [[ -n "$line" ]]; do
            # 去注释、去首尾空白
            line="${line%%#*}"
            line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            [[ -z "$line" ]] && continue
            [[ "$line" != *=* ]] && continue
            k="${line%%=*}"
            val="${line#*=}"
            k="$(echo "$k" | tr -d '[:space:]')"
            val="$(echo "$val" | tr -d '[:space:]')"
            case "$k" in
                HOST_ROLE)      [[ -n "$val" ]] && v_role="$val" ;;
                HOST_NAME)      [[ -n "$val" ]] && v_hname="$val" ;;
                HOST_STEAMID)   [[ -n "$val" ]] && v_hsid="$val" ;;
                CLIENT_NAME)    [[ -n "$val" ]] && v_cname="$val" ;;
                CLIENT_STEAMID) [[ -n "$val" ]] && v_csid="$val" ;;
                PORT)           [[ -n "$val" ]] && v_port="$val" ;;
            esac
        done < "$conf"
    fi

    echo "ROLE_HOST_ROLE=$v_role"
    echo "ROLE_HOST_NAME=$v_hname"
    echo "ROLE_HOST_STEAMID=$v_hsid"
    echo "ROLE_CLIENT_NAME=$v_cname"
    echo "ROLE_CLIENT_STEAMID=$v_csid"
    echo "ROLE_PORT=$v_port"
}

# 本机（Mac）是主机还是客机
# 输出: host | client
this_machine_role() {
    local repo="${1:-}"
    eval "$(read_role_conf "$repo")"
    if [[ "$ROLE_HOST_ROLE" == "mac" ]]; then echo "host"; else echo "client"; fi
}

# 本机的身份，输出 "name steamid role"
my_identity() {
    local repo="${1:-}"
    eval "$(read_role_conf "$repo")"
    if [[ "$ROLE_HOST_ROLE" == "mac" ]]; then
        echo "$ROLE_HOST_NAME $ROLE_HOST_STEAMID host"
    else
        echo "$ROLE_CLIENT_NAME $ROLE_CLIENT_STEAMID client"
    fi
}

# 对方（Windows）的身份，输出 "name steamid role"
peer_identity() {
    local repo="${1:-}"
    eval "$(read_role_conf "$repo")"
    if [[ "$ROLE_HOST_ROLE" == "mac" ]]; then
        echo "$ROLE_CLIENT_NAME $ROLE_CLIENT_STEAMID client"
    else
        echo "$ROLE_HOST_NAME $ROLE_HOST_STEAMID host"
    fi
}
