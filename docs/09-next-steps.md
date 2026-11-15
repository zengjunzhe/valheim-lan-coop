# 下一步：先验证，再自动化

> 在 `docs/08-verification.md` 确认此前方案有误之后，这里给出正确的推进顺序。
>
> **核心原则：每一步都要有明确的"通过/不通过"判据，不通过就停下。**

---

## 阶段 1：Mac 单机验证（最高优先级）

**目标**：确认 `aaf2tbz` 的 dylib 能在真实 Valheim.app 上加载，游戏能进单人世界。

**如果这一步失败，整条路线就断了，不用往下走。**

### 1.1 摸清现状

```bash
# 找 steam api 库
find /Applications/Valheim.app -name "*steam_api*" 2>/dev/null

# 记录原文件信息（用于回滚）
DYLIB=$(find /Applications/Valheim.app -name "libsteam_api.dylib" -not -name "*.orig" | head -1)
echo "路径: $DYLIB"
ls -la "$DYLIB"
file "$DYLIB"
lipo -archs "$DYLIB"
shasum -a 256 "$DYLIB"
```

**记录输出**。原文件哈希是回滚的唯一依据。

**判据**：能找到 `libsteam_api.dylib`，且架构与本机匹配。

- 如果找不到任何 `steam_api` 相关文件 → Valheim Mac 版可能不通过 Steamworks 联机，**路线不成立**
- 如果架构是 `x86_64` 但你是 Apple Silicon → 需确认 Rosetta 是否在跑游戏

### 1.2 下载 Goldberg macOS 构建

```bash
mkdir -p ~/goldberg && cd ~/goldberg

# 从 GitHub release 下载
curl -sL -o libsteam_api.dylib \
  "$(curl -s https://api.github.com/repos/aaf2tbz/goldberg_emulator/releases/latest \
     | python3 -c 'import json,sys; d=json.load(sys.stdin); print([a["browser_download_url"] for a in d["assets"] if a["name"]=="libsteam_api.dylib"][0])')"

file libsteam_api.dylib
lipo -archs libsteam_api.dylib
```

**判据**：输出 `universal binary` 或至少包含 `arm64`（Apple Silicon）/ `x86_64`（Intel）。

### 1.3 备份并替换

```bash
DYLIB=$(find /Applications/Valheim.app -name "libsteam_api.dylib" -not -name "*.orig" | head -1)

# 备份（只做一次）
[ -f "$DYLIB.orig" ] || cp -p "$DYLIB" "$DYLIB.orig"

# 替换
cp -f ~/goldberg/libsteam_api.dylib "$DYLIB"

# 重签名（必需）
codesign --force --deep --sign - /Applications/Valheim.app
xattr -dr com.apple.quarantine /Applications/Valheim.app

# 验证
codesign -v /Applications/Valheim.app && echo "签名 OK"
```

### 1.4 写最小配置

```bash
SS="/Applications/Valheim.app/Contents/MacOS/steam_settings"
mkdir -p "$SS"

echo "892970" > "$SS/steam_appid.txt"
echo "PlayerA" > "$SS/account_name.txt"
echo "76561198000000001" > "$SS/user_steam_id.txt"
echo "schinese" > "$SS/language.txt"
```

**注意是 `.txt` 不是 `.ini`。** 详见 `08-verification.md` 2.3 节。

### 1.5 启动验证

```bash
# 完全退出 Steam
osascript -e 'quit app "Steam"' 2>/dev/null; sleep 2
pkill -x steam_osx 2>/dev/null

# 启动游戏
open -a /Applications/Valheim.app
```

**判据（必须全部通过）**：

```
□ 游戏窗口出现，没有闪退
□ 主菜单能进
□ 能新建世界并进入
□ 能正常移动、砍树
□ 退出游戏不崩溃
```

**如果闪退**，看崩溃日志：

```bash
ls -lt ~/Library/Logs/DiagnosticReports/ | head -5
log show --last 3m --predicate 'process CONTAINS "alheim"'
```

常见原因：

| 现象 | 原因 | 处理 |
|---|---|---|
| `code signature invalid` | 没重签名 | 重跑 `codesign --force --deep --sign -` |
| `incompatible architecture` | 架构不匹配 | `lipo -archs` 检查 |
| `Library not loaded` | 依赖缺失 | 恢复 `.orig`，换其他 fork |
| 静默退出 | dylib 加载失败 | 恢复 `.orig`，确认游戏本身能跑 |

**失败就回滚**：

```bash
DYLIB=$(find /Applications/Valheim.app -name "libsteam_api.dylib" -not -name "*.orig" | head -1)
cp -f "$DYLIB.orig" "$DYLIB"
codesign --force --deep --sign - /Applications/Valheim.app
```

---

## 阶段 2：Windows 单机验证

**目标**：确认 gbe_fork 的 dll 能加载。

### 2.1 版本要求

**必须 ≥ `release-2026_01_17`**。更早版本破坏 Valheim 联机（issue #396）。

当前最新：`release-2026_09_27`

```powershell
# 下载
# https://github.com/Detanup01/gbe_fork/releases
# 选 emu-win-release-vs22.7z 或 emu-win-release-vs26.7z
```

### 2.2 替换与配置

```powershell
$V = "D:\SteamLibrary\steamapps\common\Valheim"
$dll = "$V\valheim_Data\Plugins\x86_64\steam_api64.dll"

# 备份
if (-not (Test-Path "$dll.orig")) { Copy-Item $dll "$dll.orig" }

# 替换
Copy-Item "C:\goldberg\steam_api64.dll" $dll -Force

# 配置
$ss = "$V\steam_settings"
New-Item -ItemType Directory -Force -Path $ss | Out-Null
Set-Content "$ss\steam_appid.txt" "892970" -NoNewline -Encoding ASCII
```

`$ss\configs.user.ini`：

```ini
[user::general]
account_name=PlayerB
account_steamid=76561198000000002
language=schinese
```

`$ss\configs.main.ini`：

```ini
[main::connectivity]
disable_networking=0
listen_port=47584
```

### 2.3 启动验证

```powershell
# 退出 Steam
Stop-Process -Name steam -Force -ErrorAction SilentlyContinue

# 启动
& "$V\valheim.exe" -console
```

**判据**：同样五项（窗口、菜单、进世界、操作、退出）。

---

## 阶段 3：联机验证

**只有在阶段 1 和 2 都通过后才做这一步。**

### 3.1 配 custom_broadcasts.txt

两端都写，内容相同：

```
192.168.1.255
192.168.1.23
192.168.1.45
```

（第一行本网段广播地址，后两行两台机实际 IP）

### 3.2 确认端口

| 端口 | 用途 |
|---|---|
| **47584** | Goldberg emu 发现（两端必须一致） |
| **2456** | Valheim 游戏数据（`Join IP` 填这个） |

两个都要放行。

### 3.3 试连

1. 主机进世界
2. 客机 `Join Game`
3. 先看 **LAN 标签页** 有没有出现（`custom_broadcasts.txt` 生效的话应该有）
4. 没有再试 `Join IP` 填 `主机IP:2456`

**判据**：能进同一个世界，两人能互相看见、能同步动作。

**如果失败**，收集两端日志：

```bash
# Mac
log show --last 5m --predicate 'process CONTAINS "alheim"' > mac.log
```

```powershell
# Windows
& "$V\valheim.exe" -console   # 控制台会打印连接日志
```

看有没有 `Failed to send data k_EResultFail` —— 那是 issue #396 的症状，说明 emu 版本太旧。

---

## 阶段 4：自动化

**前三阶段都通过后**，才值得写脚本。届时按实测结果重写 `scripts/`。

现在写脚本的问题：不知道哪一步会失败，脚本会把错误包装成"看起来成功"。

---

## 时间预估

| 阶段 | 乐观 | 悲观 |
|---|---|---|
| 1. Mac 单机 | 30 分钟 | 卡住（架构/签名问题） |
| 2. Windows 单机 | 20 分钟 | 卡住（版本问题） |
| 3. 联机 | 30 分钟 | 卡住（发现机制不通） |
| 4. 自动化 | 1 小时 | — |

**阶段 3 是最可能卡住的**，因为没有现成方案可参考，`custom_broadcasts.txt` 对 Valheim 的实际效果未经验证。

---

## 如果阶段 3 卡住

停止折腾，考虑：

| 方案 | 成本 | 说明 |
|---|---|---|
| 买第二份 | ¥30（史低） | 官方支持，零风险 |
| PC Game Pass | 订阅 | Windows 侧用 Game Pass 版，与 Steam 版官方 crossplay |
| 放弃双人 | 0 | 单人玩 |

**官方 crossplay 已确认可用**：Steam 版 ↔ Game Pass 版，两端加 `-crossplay`。

不值得为了 ¥30 卡几天。
