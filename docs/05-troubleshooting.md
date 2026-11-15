# 排错

> ⚠️ **本文档部分内容已被 [`08-verification.md`](08-verification.md) 推翻。**
> 特别是 `enable_lan_only` 这个配置键**不存在**，端口也不是 2456。
> 阅读时请对照 08 号文档的修正说明。

按"现象 → 原因 → 处理"查表。先跑 `01-detect`，大部分问题它会直接报出来。

---

## 一、Windows 侧

### 安装 / 定位阶段

| 现象 | 原因 | 处理 |
|---|---|---|
| `01-detect.ps1` 找不到 Steam | 装在非标准路径 | 用 `-ValheimDir` 手动指定 |
| 找不到 Valheim 目录 | 多库或多盘 | 脚本会读 `libraryfolders.vdf`；仍失败则手动指定 |
| 提示"请先安装 Steam 并下载 Valheim" | 真的没装 | 打开 Steam 下载 |
| 磁盘空间不足 | 需要 ≥5GB | 换盘 |

### 打补丁阶段

| 现象 | 原因 | 处理 |
|---|---|---|
| 找不到 `steam_api64.dll` | 游戏文件不完整 | Steam → 右键 Valheim → 属性 → 已安装文件 → 验证完整性 |
| Goldberg dll 报"不是有效 PE 文件" | 下错包（Linux/macOS 构建） | 重新下载 `goldberg_emulator.zip`，取 `x64\steam_api64.dll` |
| 覆盖失败"文件被占用" | 游戏或 Steam 还在跑 | 完全退出 Steam 和 valheim.exe |
| `steam_settings` 放错位置 | 放进了 `valheim_Data\` | 必须在 `valheim.exe` 同级 |

### 启动阶段

| 现象 | 原因 | 处理 |
|---|---|---|
| 双击无反应 | dll 放错目录 | 必须是 `valheim_Data\Plugins\x86_64\steam_api64.dll` |
| 报 `0xc000007b` | 混用 32 位 dll | 用 `steam_api64.dll`，不是 `steam_api.dll` |
| 启动即崩，无日志 | 缺 VC++ 运行库 | 装 `vc_redist.x64.exe` |
| 通过 Steam 启动提示"无授权" | Steam 在校验 | 不要用 Steam 启动，直接跑 `valheim.exe` |
| 启动后 Mac 被顶下线 | Steam 客户端还登着同一账号 | 完全退出 Steam（托盘也要退） |
| `04-launch.ps1` 报"进程启动后立即退出" | 补丁或依赖问题 | 看脚本打印的三条常见原因，逐条排查 |

### 运行阶段

| 现象 | 原因 | 处理 |
|---|---|---|
| 进了游戏但 Mac 连不上 | 主机没进世界 | 必须先 `Start Game` 真正进世界 |
| Mac 连上秒断 | buildid 不一致 | 核对两端 buildid |
| 两人装备串了 | `account_steamid` 重复 | 两端必须不同 |
| 世界列表里看到重复存档 | 多次创建 | 手动删 `worlds\` 下多余 `.fwl`/`.db` |

---

## 二、Mac 侧

### 定位阶段

| 现象 | 原因 | 处理 |
|---|---|---|
| `find` 找不到 `libsteam_api.dylib` | 路径变了 | `find /Applications/Valheim.app -name "*steam_api*"` |
| `lipo -info` 报 `x86_64` 但机器是 arm64 | 架构不匹配 | 找 universal 构建 / 自编译 / 走 CrossOver |
| 找不到 `libsteam_api.dylib` 在 Goldberg 包里 | 该 release 只提供 Windows 构建 | 自编译 macOS 版，或用 CrossOver |

### 签名阶段

| 现象 | 原因 | 处理 |
|---|---|---|
| `codesign` 报 `detritus not allowed` | 扩展属性残留 | `xattr -cr /Applications/Valheim.app` 后重签 |
| `codesign` 报 `code object is not signed at all` | 签名被破坏 | `codesign --force --deep --sign -` 重跑 |
| 提示"已损坏，无法打开" | quarantine 未清 | `xattr -dr com.apple.quarantine /Applications/Valheim.app` |
| Gatekeeper 拒绝 | 自签名正常现象 | 系统设置 → 隐私与安全性 → 仍要打开 |

### 启动阶段

| 现象 | 原因 | 处理 |
|---|---|---|
| 图标闪一下就消失 | 未重签名 | `./03-resign.sh` |
| 崩溃日志 `incompatible architecture` | 架构不匹配 | 见上 |
| 崩溃日志 `Library not loaded` | dylib 依赖问题 | 从 `.orig` 恢复后换 Goldberg 版本 |
| 启动后立刻退出，无日志 | Steam 在运行干扰 | 完全退出 Steam（`Cmd+Q` + 菜单栏图标） |

### 运行阶段

| 现象 | 原因 | 处理 |
|---|---|---|
| `Join IP` 一直 `Connecting...` | 端口不通 / 配置错 | 见下方连通性排查 |
| 连上后画面卡死 | 显存不足 | 画质 Medium，关 SSAO/动态模糊 |
| 角色是新的，装备全没 | `account_steamid` 变了 | 改回原值 |
| 进不去，提示密码错误 | 主机设了世界密码 | 问主机要 |

崩溃日志：

```bash
ls -lt ~/Library/Logs/DiagnosticReports/ | head -5
log show --last 5m --predicate 'process CONTAINS "alheim"'
```

---

## 三、连通性排查（最常见）

按顺序执行，每步确认结果再往下。

### 1. 确认同网段

Windows：
```powershell
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like "192.168.*" }
```

Mac：
```bash
ifconfig | grep "inet " | grep -v 127.0.0.1
```

两台应该都是 `192.168.x.*` 且**第三段相同**（如都是 `192.168.1.*`）。

不同段 = 不在同一局域网。检查是不是一台连 WiFi、一台连另一个路由器/访客网络。

### 2. 确认主机在监听

Windows：
```powershell
netstat -ano | Select-String "2456"
```

应看到 `UDP 0.0.0.0:2456`。没有 = 主机没进世界。

### 3. 从 Mac 测连通

```bash
ping -c 3 192.168.1.23
```

ICMP 通不代表 UDP 通（防火墙可能只拦 UDP），但不通说明路由就有问题。

### 4. 临时关防火墙验证

```powershell
# Windows 管理员
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
# 测完立刻开回来
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
```

关了能连 → 防火墙规则问题，重跑 `03-firewall.ps1`。

### 5. 检查网络位置是不是「公用」

**这是最容易踩的坑**：Windows 把 WiFi 识别为「公用」时，`profile=private` 的规则完全不生效。

```powershell
Get-NetConnectionProfile
```

`NetworkCategory` 是 `Public` → 改成专用：

```
设置 → 网络和 Internet → 属性 → 网络配置文件 → 专用
```

### 6. 检查路由器 AP 隔离

登录路由器管理页，找并**关闭**：

- `AP 隔离` / `AP Isolation`
- `客户端隔离` / `Client Isolation`
- `无线隔离` / `Wireless Isolation`

这是"局域网里互相看不到"的头号原因。

### 7. 检查频段 / VLAN

某些 Mesh 路由器的 2.4G 和 5G 隔离，或「访客网络」独立。两台都连主网络。

---

## 四、配置核对清单

逐项对照：

```
□ Windows: steam_settings\steam_appid.txt = 892970
□ Windows: configs.user.ini 的 account_steamid = 76561198000000001
□ Windows: configs.main.ini 的 enable_lan_only = 1
□ Windows: valheim_Data\Plugins\x86_64\steam_api64.dll 是 Goldberg 版
□ Windows: steam_settings 在 valheim.exe 同级（不是 valheim_Data 里）
□ Mac:     steam_settings\steam_appid.txt = 892970
□ Mac:     configs.user.ini 的 account_steamid = 76561198000000002
□ Mac:     configs.main.ini 的 enable_lan_only = 1
□ Mac:     libsteam_api.dylib 是 Goldberg 版
□ Mac:     已重签名（codesign -v 通过）
□ 两端 buildid 相同
□ 两端都没加 -crossplay 启动参数
□ 两端 Steam 客户端都已完全退出
□ Windows 防火墙放行 UDP 2456-2458
□ Windows 网络位置是「专用」
□ 路由器 AP 隔离已关闭
```

**「-crossplay 不能加」** 容易搞错：本方案走 IP 直连，加了 crossplay 会切 PlayFab，Goldberg 无真 ticket，必然失败。

---

## 五、收集诊断信息

Windows：

```powershell
cd scripts\windows
powershell -ExecutionPolicy Bypass -File .\01-detect.ps1 | Out-File diag-win.txt
Get-ChildItem "$env:ProgramFiles(x86)\Steam\steamapps\common\Valheim\steam_settings" -Recurse -ErrorAction SilentlyContinue | Out-File -Append diag-win.txt
netstat -ano | Select-String "2456" | Out-File -Append diag-win.txt
Get-NetConnectionProfile | Out-File -Append diag-win.txt
```

Mac：

```bash
cd scripts/mac
./01-detect.sh > diag-mac.txt 2>&1
find /Applications/Valheim.app -name "steam_settings" -exec sh -c 'echo "== $1"; ls -la "$1"; cat "$1"/*.ini "$1"/*.txt 2>/dev/null' _ {} \; >> diag-mac.txt
log show --last 5m --predicate 'process CONTAINS "alheim"' >> diag-mac.txt 2>&1
```

两份文件对照看，通常能定位。
