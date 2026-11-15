# Windows 状态

> 由 `06-sync-push.ps1` 自动生成。手动改也行，但下次推送会覆盖。

```
更新时间   : 2026-11-15 20:11 +08:00
主机名     : LAPTOP-DOA9KT57
内网 IP    : 192.168.5.12   (WLAN, 同网段 Mac 192.168.5.11)
端口       : 2456 (游戏)
buildid    : 26249040   ← 与 Mac 一致
Valheim 路径: D:\steam\steamapps\common\Valheim
补丁状态   : 已回滚 —— 原版 steam_api64.dll 已还原（哈希校验一致），steam_settings 已清
身份       : 官方 Steam 账号（PlayFab 登录成功），不再用 Goldberg
Steam 进程 : 运行中，已登录
世界状态   : 官方联机可用
```

## 结论：Windows 侧改走官方路线

2026-11-15 20:11 实测：

```
Steam initialized, persona:<真实账号名，不再是 gse orca>
Sending PlayFab login request (attempt 1)
Logged in PlayFab user via Steam auth session ticket   ← 官方联机登录成功
PlayFab local entity ID is 5591EB0FD79FAA75
```

也就是说 **Steam 官方联机（PlayFab）在这台机上完全正常**，走 Goldberg 反倒是降级。原版 DLL 还原后
SHA256 回到 `A44E5537939AE4EEBC69000589AA9B2437A667813A1657CC779198BAE9B815A9`。

## 阶段 3 的路线因此变了

- 之前设想的「两端都 Goldberg + `custom_broadcasts.txt`」在这台机上**已放弃**。
- Windows 侧要正常联机，需要**另一份正版**：买第二份（史低 ¥30）或在 Windows 用 **PC Game Pass**，
  两端加 `-crossplay` 即可 Steam ↔ Game Pass 互通。
- Mac 侧如果只有一份授权，仍然只能 Goldberg 单机；那台机的 Goldberg 环境没动过，随时能回退/继续用。

## 存档处置（已救回，未丢）

- Goldberg 期间建的角色 `guo`：已从 `%APPDATA%\GSE Saves\892970\remote\characters\guo.fch`
  复制到 `%USERPROFILE%\AppData\LocalLow\IronGate\Valheim\characters_local\guo.fch`，官方模式下能选到。
- 世界 `BIGDIM` 没能救回：GSE 里只剩 51 字节的云元数据（`_main.0.fwl2`），世界本体没落盘。
- 原始 `GSE Saves` 整个目录备份在 `work\backup\GSE-Saves-20261115-2010\`，
  另外改名留了一份 `%APPDATA%\GSE Saves.bak-20261115`。

## 收尾提醒

- Defender 里给 `work\` 和 `...\Plugins\x86_64` 加的两个排除项**现在不需要了**，
  可以在 Windows 安全中心 → 排除项里删掉（本机非管理员，脚本删不了）。
- `work\gbe\` 里的模拟器产物约 140 MB，不用可以整个删掉；`work\backup\` 是存档与 DLL 备份，建议留着。
