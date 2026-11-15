# Windows 主机完整步骤（Steam 版）

> ⚠️ **本文档部分内容已被 [`08-verification.md`](08-verification.md) 推翻。**
> 特别是 `enable_lan_only` 这个配置键**不存在**，端口也不是 2456。
> 阅读时请对照 08 号文档的修正说明。

前提：**已经用 Steam 客户端把 Valheim 下载好**。Windows 那台既是主机（开世界）也是玩家 A。

> 全程以管理员身份打开 PowerShell。脚本在 `scripts/windows/` 下。

---

## 为什么用 Steam 下载而不是 steamcmd

| 方式 | 版本对齐 | 补丁后能否启动 | 推荐 |
|---|---|---|---|
| Steam 下载 | ✅ 两台同一账号拉最新版，天然一致 | ✅ 可以 | **本方案** |
| steamcmd 匿名下载 | ⚠️ 需手动核对 buildid | ✅ 可以 | 备选 |

Steam 下载的最大好处：**两台机器用同一个账号各自下载，buildid 必然相同**，省掉最麻烦的版本对齐环节。下载完成后把 Steam 关掉，再用 Goldberg 启动即可。

注意 Steam 的限制在这里只影响"同时在线玩"，不影响"各自下载"。下载时一台在线、另一台排队即可。

---

## 步骤 0：Steam 下载（两台都做）

1. Windows 打开 Steam，登录你的账号
2. 库 → Valheim → 安装
3. 等下载完成，**先不要启动游戏**
4. 记下安装路径：库 → 右键 Valheim → 管理 → 浏览本地文件

常见路径：

```
C:\Program Files (x86)\Steam\steamapps\common\Valheim
D:\SteamLibrary\steamapps\common\Valheim
```

Mac 那台同样操作（见 `03-mac-setup.md`）。

**下载完就先退出 Steam**，后面不需要它了。

---

## 步骤 1：环境探测

```powershell
cd scripts\windows
powershell -ExecutionPolicy Bypass -File .\01-detect.ps1
```

脚本自动做的事：

- 从注册表 + `libraryfolders.vdf` 定位 Valheim（多库、多盘都能找到）
- 打印 `buildid`（记下来，和 Mac 对比）
- 检查 `steam_api64.dll` 是否存在、是否已打补丁
- 检查 `steam_settings` 里 `enable_lan_only` 是否为 1
- **打印内网 IP**（Mac 要填这个）
- 检查 Steam 是否还在运行

**记下输出的两样东西**：

```
buildid = 12345678          ← 和 Mac 对比
>>> Mac 侧 Join IP 填: 192.168.1.23:2456   ← 告诉 Mac
```

### buildid 不一致怎么办

| 情况 | 处理 |
|---|---|
| Windows 有、Mac 没有 | Mac 打开 Steam 让它更新完 |
| Mac 有、Windows 没有 | Windows 打开 Steam 让它更新完 |
| 两边都有但不同 | 让版本落后的那台更新（Steam → 库 → Valheim → 更新） |

Steam 会自动保持最新，所以只要两台都下载过，基本不会不一致。

---

## 步骤 2：下载 Goldberg

浏览器打开：

```
https://github.com/Mr_Goldberg/goldberg_emulator/releases
```

下载最新 `goldberg_emulator.zip`，解压到 `C:\goldberg\`。

需要的文件：`x64\steam_api64.dll`

解压后确认：

```powershell
Get-ChildItem C:\goldberg -Recurse -Filter "steam_api64.dll"
```

应该有输出。没有的话说明下错了包（可能是 Linux/macOS 构建）。

---

## 步骤 3：打补丁

**先确认 Steam 完全退出**（含托盘图标）。

```powershell
powershell -ExecutionPolicy Bypass -File .\02-apply-goldberg.ps1 -GoldbergDir C:\goldberg
```

自动定位 Valheim，也支持手动指定：

```powershell
powershell -ExecutionPolicy Bypass -File .\02-apply-goldberg.ps1 `
  -ValheimDir "D:\SteamLibrary\steamapps\common\Valheim" `
  -GoldbergDir C:\goldberg `
  -AccountName PlayerA `
  -SteamId 76561198000000001
```

脚本做的事：

1. 校验 Goldberg dll 是有效 PE 文件（MZ 头）
2. 备份原版 → `steam_api64.dll.orig`（**只备份一次，不会被覆盖**）
3. 覆盖为 Goldberg 版
4. 创建 `steam_settings\`，写入三个配置文件
5. 打印完整目录树供核对

### 打完补丁的结构

```
D:\SteamLibrary\steamapps\common\Valheim\
├── valheim.exe
├── valheim_Data\
│   └── Plugins\
│       └── x86_64\
│           ├── steam_api64.dll        ← Goldberg 版
│           └── steam_api64.dll.orig   ← 原版备份
└── steam_settings\                    ← 游戏根目录，不是 valheim_Data 里
    ├── steam_appid.txt                ← 892970
    ├── configs.user.ini               ← PlayerA / ...0001
    └── configs.main.ini               ← enable_lan_only=1
```

**最常见的错误**：把 `steam_settings` 放进 `valheim_Data\` 里面。必须在 `valheim.exe` 同级。

---

## 步骤 4：防火墙

```powershell
powershell -ExecutionPolicy Bypass -File .\03-firewall.ps1
```

放行 UDP 2456-2458，仅专用/域网络。脚本会同时提示网络位置问题——如果当前网络被识别为「公用」，规则不生效，脚本会明确警告。

改网络位置：

```
设置 → 网络和 Internet → 属性 → 网络配置文件 → 专用
```

---

## 步骤 5：启动

```powershell
powershell -ExecutionPolicy Bypass -File .\04-launch.ps1
```

脚本会：

1. 校验补丁完整性（缺文件直接拒绝启动）
2. 发现 Steam 在运行 → 询问是否关闭（**必须关**）
3. 检查游戏是否已在运行
4. 检查端口占用
5. 启动 `valheim.exe -console`
6. 等 3 秒验证进程存活（启动即崩会报出来）
7. 打印 Mac 要填的 IP:PORT

**永远不要通过 Steam 启动**。Steam 会校验授权，而且同账号在线会顶掉 Mac 那边。

---

## 步骤 6：进世界

1. `Start Game` → `New World` 或选已有世界
2. 世界名建议纯英文（中文名偶发路径问题）
3. **必须真正进入世界**，端口才开始监听
4. 按 `F5` 看控制台，确认无报错
5. 告诉 Mac 那台：`192.168.1.23:2456`

---

## 常见问题

| 现象 | 处理 |
|---|---|
| `01-detect.ps1` 找不到 Valheim | 用 `-ValheimDir` 手动指定；确认 Steam 真的装完了 |
| 启动后闪退，无窗口 | `steam_api64.dll` 放错目录，必须是 `valheim_Data\Plugins\x86_64\` |
| 报 `0xc000007b` | 混用了 32 位 dll，用 `steam_api64.dll` 不是 `steam_api.dll` |
| 缺 VC++ 运行库 | 装 `vc_redist.x64.exe`（微软官网） |
| 通过 Steam 启动提示无授权 | 别用 Steam 启动，直接跑 `valheim.exe` |
| Mac 被顶下线 | Steam 客户端还登着同一账号，完全退出 |
| 防火墙加了还是连不上 | 网络位置是「公用」，改成「专用」 |
| 游戏能开但 Mac 连不上 | 主机没进世界，端口没监听 |

---

## 更新游戏后

Steam 更新会覆盖 `steam_api64.dll`，补丁失效。重跑：

```powershell
powershell -ExecutionPolicy Bypass -File .\01-detect.ps1
powershell -ExecutionPolicy Bypass -File .\02-apply-goldberg.ps1 -GoldbergDir C:\goldberg
```

`steam_settings` 通常不会被 Steam 覆盖，但脚本会重写一遍确保正确。

---

## 回滚

```powershell
powershell -ExecutionPolicy Bypass -File .\99-rollback.ps1
```

恢复原版 dll，移走 `steam_settings`，之后可正常通过 Steam 启动。详见 [`06-rollback.md`](06-rollback.md)。
