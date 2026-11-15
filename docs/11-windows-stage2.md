# Windows 阶段 2：已通过（2026-11-15 实测）

> 环境：`LAPTOP-DOA9KT57` / Windows 11 25H2 build 26200.9457 / Valheim buildid **26249040**
> （与 Mac 侧一致）/ Steam 库 `D:\steam`。
>
> 对应 `09-next-steps.md` 的阶段 2。**结论：gbe_fork 的 Windows 构建能加载，游戏能起、
> 身份能生效、`47584` 在监听；PlayFab 登录必然失败，属预期。**

---

## 一、结论

| 项 | 结果 |
|---|---|
| `gbe_fork release-2026_09_27` 的 Windows DLL 能否加载 | ✅ 能 |
| 游戏能启动到主菜单 | ✅（窗口标题 `Valheim`，进程常驻 2.1 GB，D3D11 已初始化） |
| 中文界面 | ✅（`language=schinese`） |
| 身份生效 | ✅ 日志 `Steam initialized, persona:PlayerB` |
| LAN 发现端口在监听 | ✅ `0.0.0.0:47584` UDP |
| PlayFab 登录 | ❌ `errorcode:101 Invalid ticket`（伪造 ticket 无效，预期） |

日志证据（`%USERPROFILE%\AppData\LocalLow\IronGate\Valheim\Player.log`）：

```
11/15/2026 19:05:57: Using steam_appid.txt
11/15/2026 19:05:57: Using steam APPID:892970
11/15/2026 19:05:57: Authentication:k_ESteamNetworkingAvailability_Current
11/15/2026 19:07:00: Steam initialized, persona:PlayerB
11/15/2026 19:07:02: /Client/LoginWithSteam: ... errorcode:101, errordesc:Invalid ticket
```

端口证据（`Get-NetUDPEndpoint -OwningProcess <valheim pid>`）：

```
LocalAddress  LocalPort
0.0.0.0       47584      ← Goldberg 的 LAN 发现端口，和 Mac 侧要求一致
```

---

## 二、与旧文档不一致的地方（以本节为准）

| 项 | 旧文档 | 实测 |
|---|---|---|
| `steam_settings` 位置 | 游戏根目录 | **根目录无效**：emu 仍随机生成 persona（`gse orca`）；必须放 **DLL 同级** `valheim_Data\Plugins\x86_64\steam_settings`。两处都写更保险 |
| 用哪个构建 | 未说明 | 用 `release\experimental\x64\steam_api64.dll`（22 777 768 B）。包里另有两种：`regular\x64`（11 431 336 B）与 `steamclient_experimental` |
| experimental 的副作用 | 未记录 | 默认**阻断所有非内网连接**（只放行 10/8、127/8、169.254/16、172.16/12、192.168/16、224+）；要解除在 `configs.main.ini` 写 `disable_lan_only=1` |
| 发布包能不能直接下 | 能 | Defender 把发布包判成 `Trojan:Win32/Suschil!rfn`（事件 1116），之后**读都读不了**，还会连文件一起删掉 → 必须先把目录加进排除项 |
| 下载工具 | curl / Invoke-WebRequest | 本机 schannel 报 `SEC_E_NO_CREDENTIALS`，curl/PowerShell 都不通，改用 node（自带 CA） |
| `steam_settings` 的配置格式 | `.ini` | 对，Windows 构建读 ini。`custom_broadcasts.txt` 仍是 txt |
| 端口 2456 | 游戏端口 | 对；发现端口是 **47584**，两者都要放行 |

---

## 三、实测步骤（可复跑）

```powershell
# 1. 前置：Windows 安全中心 → 排除项，加
#    C:\Users\lenovo\Desktop\ylsd\work
#    D:\steam\steamapps\common\Valheim\valheim_Data\Plugins\x86_64
#    （本机非管理员 + Tamper Protection，命令行加不了，只能走 UI）

# 2. 一条命令做完剩下的
pwsh -File C:\Users\lenovo\Desktop\ylsd\work\apply-stage2.ps1
```

脚本做的事：发布包不在就重下（node）→ `7zr` 解压 → 备份原版 `.orig`（只做一次）→
复制 `experimental\x64\steam_api64.dll` → 把 `steam_settings` 写进 DLL 同级和游戏根目录 →
打印启动/回滚命令。加 `-WhatIf` 可空跑。

手工等价步骤：

```powershell
$G = 'D:\steam\steamapps\common\Valheim'
$P = "$G\valheim_Data\Plugins\x86_64"

# 备份
if (-not (Test-Path "$P\steam_api64.dll.orig")) { Copy-Item "$P\steam_api64.dll" "$P\steam_api64.dll.orig" }

# 替换
Copy-Item 'C:\Users\lenovo\Desktop\ylsd\work\gbe\x\release\experimental\x64\steam_api64.dll' "$P\steam_api64.dll" -Force

# 配置（DLL 同级 + 根目录都写）
foreach ($ss in @("$P\steam_settings", "$G\steam_settings")) {
    New-Item -ItemType Directory -Force -Path $ss | Out-Null
    Copy-Item 'C:\Users\lenovo\Desktop\ylsd\work\steam_settings\*' $ss -Force
}

# 启动
& "$G\valheim.exe" -console
```

`steam_settings` 内容（客机 PlayerB）：

```ini
# steam_appid.txt
892970

# configs.user.ini
[user::general]
account_name=PlayerB
account_steamid=76561198000000002
language=schinese

# configs.main.ini
[main::connectivity]
disable_networking=0
listen_port=47584

# custom_broadcasts.txt
192.168.5.255
192.168.5.11
192.168.5.12
```

---

## 四、本机事实

| 项 | 值 |
|---|---|
| 主机名 | `LAPTOP-DOA9KT57` |
| 系统 | build 26200.9457（注册表 `ProductName` 仍写 Windows 10 Pro，实际是 Win11 25H2 的 build 号） |
| 当前用户 | `LAPTOP-DOA9KT57\lenovo`，**中完整性**，`BUILTIN\Administrators` deny-only |
| Steam | `D:\steam` |
| Valheim | `D:\steam\steamapps\common\Valheim`，995 文件 / 4.23 GB，`StateFlags=4` |
| 原版 DLL | 298 856 B，SHA256 `A44E5537939AE4EEBC69000589AA9B2437A667813A1657CC779198BAE9B815A9` |
| 备份 | `work\backup\steam_api64.dll.orig`，以及游戏内 `steam_api64.dll.orig`（同哈希） |
| 换上的 DLL | `release\experimental\x64` 那份，SHA256 `36AACB0EBFAA2E2E585A16D26A43E56B71C31AFDC7D0E06477B6E75665FDB163` |
| 网络 | WLAN `192.168.5.12/24`，网关 `192.168.5.1`，与 Mac `192.168.5.11` 同网段 |
| 网络类别 | **Public**（`ZTE-FCSxec`） |
| 防火墙 | 入站默认 Block，但已有两条 `valheim.exe` 程序级入站允许规则（Domain/Private/Public 全覆盖）→ 2456 与 47584 入站放行 |
| 存档位置 | `%APPDATA%\GSE Saves\`（Goldberg 全局设置落在 `GSE Saves\settings\configs.user.ini`） |

---

## 五、需要人确认的三项

脚本只能证明「进程起来、Steam 初始化成功、端口在听」，下面三项要人点：

```
□ 新建世界能进
□ 能走动、砍树
□ 退出游戏不崩
```

---

## 六、回滚

```powershell
$G = 'D:\steam\steamapps\common\Valheim'
$P = "$G\valheim_Data\Plugins\x86_64"
Copy-Item "$P\steam_api64.dll.orig" "$P\steam_api64.dll" -Force
Remove-Item "$P\steam_settings", "$G\steam_settings" -Recurse -Force

# 校验
(Get-FileHash "$P\steam_api64.dll" -Algorithm SHA256).Hash
# 应等于 A44E5537939AE4EEBC69000589AA9B2437A667813A1657CC779198BAE9B815A9
```

---

## 七、阶段 3 的入口（下一步）

1. **Mac 侧**把 `custom_broadcasts.txt` 补成三行 `192.168.5.255` / `192.168.5.11` / `192.168.5.12`
   （`10-mac-verified.md` 里写的是 `192.168.5.x` 但内容是举例，要按实际 IP 改）。
2. 两端 `listen_port` 都是 `47584`，`disable_networking=0`。
3. Mac 开世界（主机）→ Windows `Join Game` 先看 **LAN 标签页**，没有再 `Join IP: 192.168.5.11:2456`。
4. 判据：能进同一个世界、两人互相看见、动作同步。

---

## 八、仓库同步（本机网络）

这台机器直连 GitHub HTTPS 会 `Connection was reset` / 443 超时，而且没有缓存 HTTPS 凭据
（`credential.helper=manager-core`，`credential fill` 直接拒绝，push 会弹 `Connect to GitHub` 登录窗）。

**能用的方式：SSH 推送**（`~/.ssh/id_ed25519` 已在 GitHub 上，`ssh -T git@github.com` 回
`Hi zengjunzhe!`）：

```powershell
git push ssh://git@github.com/zengjunzhe/valheim-lan-coop.git main
```

- SSH 22 端口直连通，不需要代理；`ssh.github.com:443` 也通（备用）。
- 走 HTTPS 才需要 `-c http.proxy=http://127.0.0.1:7890`，且必须补一次登录。

`work\` 下的东西（发布包、解压产物、备份、脚本）都不入库，靠本文的哈希与步骤复现。
两个辅助脚本的指纹，方便核对是不是同一份：

```
8F51809C9FADF0B833060D54326EC5D7EA78C628898DF1D5290F0EF6AE09A3A7  apply-stage2.ps1
79E6E34F37FDE4E0B1E7661727F02379B9DE950E7E4AF4037367C033D1BD0A34  download-gbe.mjs
```

---

## 九、回滚记录（2026-11-15 20:10，Windows 侧改走官方）

Goldberg 验证完之后，这台机决定不再走模拟器，直接登录正常账号玩。回滚做了这些：

| 动作 | 结果 |
|---|---|
| 还原 `steam_api64.dll` | SHA256 回到 `A44E5537939AE4EEBC69000589AA9B2437A667813A1657CC779198BAE9B815A9`，298 856 B ✅ |
| 删除 `steam_settings` | 游戏根目录 + DLL 同级，两处都清 |
| 删除游戏内 `steam_api64.dll.orig` | 游戏目录恢复成 Steam 原样（工作区仍有备份） |
| `%APPDATA%\GSE Saves` | 整个目录先备份到 `work\backup\GSE-Saves-20261115-2010\`，再改名为 `GSE Saves.bak-20261115` |
| 角色 `guo` | 从 GSE 云存档复制到 `LocalLow\IronGate\Valheim\characters_local\guo.fch`，官方模式能选到 |
| 世界 `BIGDIM` | 救不回来：GSE 里只剩 51 字节云元数据，世界本体没落盘 |

回滚后的启动验证（通过 Steam 启动，不是直接跑 exe）：

```
11/15/2026 20:11:22: Steam initialized, persona:<真实账号名>
11/15/2026 20:11:24: Logged in PlayFab user via Steam auth session ticket   ← 官方联机登录成功
11/15/2026 20:11:24: PlayFab local entity ID is 5591EB0FD79FAA75
```

**结论：这台机上官方联机（PlayFab）本来就正常，Goldberg 是不必要的降级。**
阶段 3 若要两台机联机，官方路线需要第二份正版（¥30）或 Windows 侧 PC Game Pass + `-crossplay`；
Mac 侧单份授权的 Goldberg 环境保持原样没动。

回滚还差一步要人做：把 Defender 里给 `work\` 和 `...\Plugins\x86_64` 加的两个排除项删掉
（非管理员，脚本删不了）。
