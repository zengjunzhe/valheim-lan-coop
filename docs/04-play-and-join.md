# 开玩、加入、存档

## 启动顺序（别搞反）

```
1. Windows 运行 04-launch.ps1 → 启动游戏
2. Windows 进游戏 → Start Game → 真正进入世界
3. Mac 运行 04-launch.sh
4. Mac → Join Game → Join IP → 192.168.x.x:2456
```

第 2 步不能省。主机没进世界时端口没监听，客机连不上。

---

## 加入方式对照

| 方式 | 适用 | 说明 |
|---|---|---|
| `Join IP` | ✅ 本方案 | 填 `IP:2456`，UDP 直连 |
| 控制台 `connect IP:port` | ✅ 备用 | `Join IP` 找不到时用，`F5` 开控制台 |
| `Join with code` | ❌ | 走 PlayFab，Goldberg 无真 ticket，必失败 |
| `LAN` 标签页 | ⚠️ 可能 | 依赖广播，Goldberg 广播模拟不完整，优先 Join IP |

---

## 世界设置建议

主机创建世界时：

- **世界名**：纯英文，如 `YG_World`（中文名偶发路径问题）
- **密码**：建议设，局域网也能防手滑
- **战斗系统**：默认

---

## 存档位置

### 主机（Windows）

```
%USERPROFILE%\AppData\LocalLow\IronGate\Valheim\
├── worlds\           ← 世界存档（.fwl / .db）
└── characters\       ← 角色存档（.fch）
```

### 客机（Mac）

```
~/.config/unity3d/IronGate/Valheim\
├── worlds\
└── characters\
```

**世界存档在主机侧**。客机的 `worlds\` 基本不用，但 `characters\` 是客机自己的角色，别删。

### 备份（开玩前做一次）

Windows：

```powershell
$src = "$env:USERPROFILE\AppData\LocalLow\IronGate\Valheim"
$dst = "D:\Backup\Valheim_$(Get-Date -f yyyyMMdd_HHmm)"
Copy-Item $src $dst -Recurse -Force
```

Mac：

```bash
cp -R ~/.config/unity3d/IronGate/Valheim ~/Desktop/Valheim_backup_$(date +%Y%m%d_%H%M)
```

---

## 世界常驻（主机想退出游戏时）

默认主机退出 = 世界关闭。两种解法：

### 方案 1：主机挂机（推荐）

主机进世界后不退出，最小化窗口。Valheim 最小化时仍在跑，UDP 端口持续监听。

### 方案 2：专用服务器（兼容性不确定）

> ⚠️ 这条路需要 steamcmd 装服务端，且 Goldberg 服务端在非 crossplay 下的稳定性依赖具体版本，**先在 Windows 本机自测通过再拉 Mac**。

```powershell
# 装服务端（匿名，不消耗游戏授权）
steamcmd +force_install_dir C:\valheim-server +login anonymous +app_update 896660 validate +quit

# 服务端也要 Goldberg 化（appid 896660，steamid 用 ...0003）
powershell -ExecutionPolicy Bypass -File .\02-apply-goldberg.ps1 `
  -ValheimDir C:\valheim-server -GoldbergDir C:\goldberg `
  -AccountName ServerHost -SteamId 76561198000000003

# 启动服务端
cd C:\valheim-server
.\valheim_server.exe -name "YG_LAN" -port 2456 -world "Dedicated" -password "ygpass123" -public 0

# 本机客户端（端口错开）
cd C:\Valheim
.\valheim.exe -port 2466
```

客户端进游戏后 `Join IP 127.0.0.1:2456`，Mac 填 `192.168.x.x:2456`。

**如果连不上，退回方案 1。**

---

## 日常流程

```
开玩：
  Windows: 04-launch.ps1 → Start Game → 进世界
  Mac:     04-launch.sh --host 192.168.x.x → Join IP

关玩：
  先让 Mac 退（Esc → Quit）
  主机最后退
  主机退出前确认客机已保存

更新：
  两台都打开 Steam 更新到最新
  然后各自重跑补丁脚本（Steam 会覆盖 dll）
```

---

## 更新后必做

Steam 更新会覆盖 `steam_api64.dll` / `libsteam_api.dylib`，补丁失效。表现：启动直接进 Steam 校验，或提示无授权。

```powershell
# Windows
powershell -ExecutionPolicy Bypass -File .\01-detect.ps1
powershell -ExecutionPolicy Bypass -File .\02-apply-goldberg.ps1 -GoldbergDir C:\goldberg
```

```bash
# Mac
./01-detect.sh
./02-apply-goldberg.sh --goldberg-dir ~/goldberg
./03-resign.sh
```

`steam_settings` 通常不会被 Steam 覆盖，脚本会重写确保正确。

**更新后重新核对 buildid**，两台必须一致。

---

## 换人玩 / 多角色

改 `configs.user.ini` 里的 `account_steamid`，**两端必须不同**。改完重启游戏生效。

Windows：

```powershell
notepad "D:\SteamLibrary\steamapps\common\Valheim\steam_settings\configs.user.ini"
```

Mac：

```bash
find /Applications/Valheim.app -name "configs.user.ini" -exec nano {} \;
```
