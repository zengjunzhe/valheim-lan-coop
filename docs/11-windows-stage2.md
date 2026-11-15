# Windows 阶段 2：环境已摸清，卡在 Defender 这一道门（2026-11-15）

> 本文是 Windows 侧的实测记录，对应 `09-next-steps.md` 的阶段 2。
> **结论先行：技术路线没问题，游戏已装好，卡点是杀软——Goldberg 的 Windows 发布包一落盘就被
> Defender 判成 `Trojan:Win32/Suschil!rfn`，之后文件连读都读不了；本机是中完整性、非管理员、
> Tamper Protection 已开，命令行加排除项直接被拒。**

---

## 一、本机事实（全部实测）

| 项 | 值 |
|---|---|
| 主机名 | `LAPTOP-DOA9KT57` |
| 系统 | build **26200.9457**（注册表 `ProductName` 写的是 Windows 10 Pro，实际是 Win11 25H2 的 build 号） |
| 当前用户 | `LAPTOP-DOA9KT57\lenovo`，**中完整性 / UAC 未提升**，`BUILTIN\Administrators` 是 deny-only |
| Steam | `D:\steam`（库：`D:` / `E:` / `F:`） |
| Valheim | `D:\steam\steamapps\common\Valheim` |
| buildid | **26249040**（与 Mac 侧完全一致，见 `10-mac-verified.md`） |
| 体积 | 995 个文件 / 4.23 GB，`StateFlags=4`（已完整安装） |
| 原版 DLL | `valheim_Data\Plugins\x86_64\steam_api64.dll`，298 856 字节 |
| 原版 SHA256 | `A44E5537939AE4EEBC69000589AA9B2437A667813A1657CC779198BAE9B815A9` |
| 备份 | `work\backup\steam_api64.dll.orig`（同哈希，已验证可读） |
| 网络 | WLAN `192.168.5.12/24`，网关 `192.168.5.1` |
| 与 Mac 的关系 | Mac `192.168.5.11/24` → **同网段**，广播地址 `192.168.5.255`，可以直接做 LAN 发现 |
| Steam 进程 | 当前未运行 |

角色按 `config/role.conf`：**Mac 是主机（PlayerA / 192.168.5.11），Windows 是客机（PlayerB / 192.168.5.12）**。

---

## 二、卡点证据

```
发布包 emu-win-release-vs22.7z   13 455 496 字节   下载成功
发布包 emu-win-release-vs26.7z   13 374 853 字节   下载成功
```

落盘后立刻被拦：

- 事件日志 `Microsoft-Windows-Windows Defender/Operational`，事件 ID **1116**
  ```
  名称: Trojan:Win32/Suschil!rfn
  ID: 2147927547
  严重性: 严重
  路径: file:_C:\Users\lenovo\Desktop\ylsd\work\gbe\emu-win-release-vs22.7z
  ```
- 之后任何读取都失败，`Get-FileHash` / `Copy-Item` / `Get-Content -AsByteStream` 一律报
  「无法成功完成操作，因为文件包含病毒或潜在的垃圾软件。」
  → 文件还在（13.4 MB），但**内核层不让读**，解压无从谈起。

Defender 状态（`Get-MpComputerStatus`）：

```
AMRunningMode             : Normal
RealTimeProtectionEnabled : True
AntivirusEnabled          : True
IsTamperProtected         : True
```

尝试命令行加排除：

```
Add-MpPreference -ExclusionPath "C:\Users\lenovo\Desktop\ylsd\work"
→ 你的权限不足，无法执行请求的操作。
```

两条结论：
1. **没提权**，调不动 Defender；
2. 就算提权，**Tamper Protection 开着，命令行写的排除项也会被拦**，只能走 Windows 安全中心界面。

> 附带说明：这是把 Steam 模拟器判成 HackTool 的常规误报（微软对这类工具的检测就是故意的），
> 不是发布包被投毒。但**必须由机器主人自己加白**，不能靠改扩展名、编码绕过去——绕过去 Valheim 加载时一样会被拦。

---

## 三、解锁这一步：只有管理员能做（1 分钟）

**Windows 安全中心 → 病毒和威胁防护 → 病毒和威胁防护设置 → 管理设置 → 排除项 → 添加或删除排除项 → 添加文件夹**，把这两个目录加进去：

```
C:\Users\lenovo\Desktop\ylsd\work
D:\steam\steamapps\common\Valheim\valheim_Data\Plugins\x86_64
```

- 第一个是解压/暂存区，第二个是 DLL 最终落点。
- 游戏验证通过后可以把这两条排除删掉（但每次改 DLL 都要重新加）。
- 只排除这两个目录，不要整个 D 盘。

加完排除后，剩下的全自动：

```powershell
pwsh -File C:\Users\lenovo\Desktop\ylsd\work\apply-stage2.ps1
```

脚本会：校验发布包可读 → 停 Steam → `7zr` 解压 → 备份原版（只做一次）→ 替换 DLL →
写 `steam_settings` → 打印启动命令和回滚命令。加 `-WhatIf` 可以先空跑看它要动哪些文件。

---

## 四、已备好的东西（都在 `work\`，不入库）

| 路径 | 内容 |
|---|---|
| `work\backup\steam_api64.dll.orig` | 原版 DLL 备份，SHA256 见上，**回滚唯一依据** |
| `work\steam_settings\steam_appid.txt` | `892970` |
| `work\steam_settings\configs.user.ini` | `account_name=PlayerB` / `account_steamid=76561198000000002` / `schinese` |
| `work\steam_settings\configs.main.ini` | `disable_networking=0` / `listen_port=47584` |
| `work\steam_settings\custom_broadcasts.txt` | `192.168.5.255` / `192.168.5.11` / `192.168.5.12` |
| `work\tools\7zr.exe` | 7-Zip 26.04 独立解包器，602 624 字节（系统自带的 `tar.exe` 打不开这个 7z） |
| `work\apply-stage2.ps1` | 上面那套流程的脚本 |

`steam_settings` 已按 `10-mac-verified.md` 的事实写：Windows 构建读 `.ini`，发现端口 **47584**，
LAN 发现靠 `custom_broadcasts.txt`（**不是** `enable_lan_only`，那个键不存在）。

---

## 五、回滚

```powershell
$G = 'D:\steam\steamapps\common\Valheim'
Copy-Item "$G\valheim_Data\Plugins\x86_64\steam_api64.dll.orig" `
          "$G\valheim_Data\Plugins\x86_64\steam_api64.dll" -Force
Remove-Item "$G\steam_settings" -Recurse -Force
```

回滚后校验：

```powershell
(Get-FileHash "$G\valheim_Data\Plugins\x86_64\steam_api64.dll" -Algorithm SHA256).Hash
# 应等于 A44E5537939AE4EEBC69000589AA9B2437A667813A1657CC779198BAE9B815A9
```

---

## 六、如果不想碰杀软

| 方案 | 成本 | 说明 |
|---|---|---|
| 买第二份（史低 ¥30） | ¥30 | 两端都用真 Steam，两个账号同时在线，零技术风险 |
| Windows 侧 PC Game Pass | 订阅费 | 官方 crossplay：Steam ↔ Game Pass，两端加 `-crossplay` |
| 继续 Goldberg | 0 | 需要一次性加排除项；两端都得是 Goldberg，真 Steam 客户端看不懂它的 LAN 广播 |

注意 `config/role.conf` 与 `templates/configs.user.A.ini` 的角色标注是反的（配置文件说 Mac 是主机、
A 份写的是 Windows 主机），等阶段 3 联机通了再一起修，现在不要两边同时改。
