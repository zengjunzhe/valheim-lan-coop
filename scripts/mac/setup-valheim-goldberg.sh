#!/bin/bash
# 在 macOS 上给 Valheim 装 Goldberg Steam 模拟器（已实测可启动、可进单人世界）
#
# 用法:
#   ./setup-valheim-goldberg.sh                 # 克隆到 ~/Games/Valheim 并安装
#   PLAYER_NAME="Alice" ./setup-valheim-goldberg.sh
#   DEST=~/Games/Valheim2 ./setup-valheim-goldberg.sh
#
# 幂等：重复执行只会更新 dylib 与配置，不会重复克隆。

set -euo pipefail

STEAM_COMMON="$HOME/Library/Application Support/Steam/steamapps/common/Valheim"
DEST="${DEST:-$HOME/Games/Valheim}"
PLAYER_NAME="${PLAYER_NAME:-PlayerA}"
GOLD_DIR="${GOLD_DIR:-$HOME/goldberg}"
GOLD_URL="https://github.com/aaf2tbz/goldberg_emulator/releases/download/latest/libsteam_api.dylib"

say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31m!!\033[0m %s\n' "$*" >&2; exit 1; }

# ---------- 0. 前置检查 ----------
[ -d "$STEAM_COMMON/valheim.app" ] || die "没找到 Steam 版 Valheim: $STEAM_COMMON/valheim.app"
[ "$(uname -m)" = "arm64" ] && ARCH="arm64" || ARCH="x86_64"
say "本机架构: $ARCH"

# ---------- 1. 下载 Goldberg 的 macOS dylib ----------
mkdir -p "$GOLD_DIR"
if [ ! -f "$GOLD_DIR/libsteam_api.dylib" ]; then
  say "下载 libsteam_api.dylib"
  curl -fsSL -o "$GOLD_DIR/libsteam_api.dylib" "$GOLD_URL"
fi
say "校验 dylib: $(lipo -archs "$GOLD_DIR/libsteam_api.dylib")"
echo "$ARCH" | grep -qE "$(lipo -archs "$GOLD_DIR/libsteam_api.dylib")" \
  || die "dylib 不含 $ARCH 架构"

# ---------- 2. APFS 克隆（瞬间完成，不占额外空间） ----------
mkdir -p "$DEST"
if [ ! -d "$DEST/valheim.app" ]; then
  say "克隆游戏到 $DEST/valheim.app"
  cp -Rc "$STEAM_COMMON/valheim.app" "$DEST/valheim.app"
else
  say "已存在 $DEST/valheim.app，跳过克隆"
fi
cp -f "$STEAM_COMMON/steam_appid.txt" "$DEST/steam_appid.txt"

APP="$DEST/valheim.app"
BUNDLE="$APP/Contents/PlugIns/steam_api.bundle"
DYLIB="$BUNDLE/Contents/MacOS/libsteam_api.dylib"

# ---------- 3. 安装 dylib ----------
[ -d "$BUNDLE" ] || die "没找到 steam_api.bundle: $BUNDLE"
if [ ! -f "$DEST/backup-libsteam_api.dylib.valve-orig" ]; then
  cp -p "$DYLIB" "$DEST/backup-libsteam_api.dylib.valve-orig"
  say "已备份原始 dylib 到 $DEST/backup-libsteam_api.dylib.valve-orig"
fi
cp -f "$GOLD_DIR/libsteam_api.dylib" "$DYLIB"
say "dylib 已替换"

# ---------- 4. steam_settings（必须放在 dylib 同级！） ----------
SS="$BUNDLE/Contents/MacOS/steam_settings"
mkdir -p "$SS"
printf '892970'   > "$SS/steam_appid.txt"
printf '47584'    > "$SS/listen_port.txt"
printf '0'        > "$SS/disable_networking.txt"
printf 'schinese' > "$SS/language.txt"
say "steam_settings 写入 $SS"

# ---------- 5. 重签名 ----------
say "重签名（先内层 bundle 再外层 app）"
codesign --force --sign - --preserve-metadata=entitlements,requirements,flags "$BUNDLE" 2>/dev/null || true
codesign --force --deep --sign - --preserve-metadata=entitlements,requirements,flags "$APP" 2>/dev/null || true
# codesign --verify 会报 nested code is modified or invalid，属预期，不影响启动

# ---------- 6. 用户级身份（每台机一份，优先级最高） ----------
U="$HOME/.local/share/Goldberg SteamEmu Saves/settings"
mkdir -p "$U"
printf '%s' "$PLAYER_NAME" > "$U/account_name.txt"
printf 'schinese'          > "$U/language.txt"
printf '47584'             > "$U/listen_port.txt"
[ -f "$U/user_steam_id.txt" ] || printf '' > "$U/user_steam_id.txt"  # 首次运行自动生成随机 ID
say "身份: $PLAYER_NAME（SteamID 见 $U/user_steam_id.txt）"

# ---------- 7. 启动脚本 ----------
LAUNCHER="$DEST/启动英灵神殿.command"
cat > "$LAUNCHER" <<'EOS'
#!/bin/bash
cd "$(dirname "$0")" || exit 1
open -n "$(dirname "$0")/valheim.app"
EOS
chmod +x "$LAUNCHER"

say "完成。启动：open -n \"$APP\"   或双击 $LAUNCHER"
say "回滚：cp -p \"$DEST/backup-libsteam_api.dylib.valve-orig\" \"$DYLIB\""
