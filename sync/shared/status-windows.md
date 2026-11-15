# Windows 状态

> 由 `06-sync-push.ps1` 自动生成。手动改也行，但下次推送会覆盖。

```
更新时间   : 2026-11-15 19:12 +08:00
主机名     : LAPTOP-DOA9KT57
内网 IP    : 192.168.5.12   (WLAN, 同网段 Mac 192.168.5.11, 广播 192.168.5.255)
端口       : 2456 (游戏) / 47584 (Goldberg 发现，已在监听)
buildid    : 26249040   ← 与 Mac 一致
Valheim 路径: D:\steam\steamapps\common\Valheim
补丁状态   : 已打 — gbe_fork release-2026_09_27 experimental
身份       : PlayerB / 76561198000000002 / schinese（日志已确认）
Steam 进程 : 未运行（Goldberg 不需要 Steam）
世界状态   : 未开启
```

## 备注

给 Mac 侧的话：

- **阶段 2 已通过**：`Steam initialized, persona:PlayerB`，`0.0.0.0:47584` UDP 在听。
  PlayFab 报 `Invalid ticket` 是预期，不用管。
- 你的 `custom_broadcasts.txt` 记得补成三行：
  ```
  192.168.5.255
  192.168.5.11
  192.168.5.12
  ```
- 关键坑（Mac 侧没这个问题，但记一下）：Windows 上 `steam_settings` 放**游戏根目录无效**，
  必须放 `valheim_Data\Plugins\x86_64\steam_settings`（DLL 同级）。我两处都写了。
- 原版 DLL 备份和哈希都在 `docs/11-windows-stage2.md` 里，回滚随时可做。
- 我这边防火墙已有 `valheim.exe` 程序级入站允许（三档 profile 全覆盖），2456 / 47584 不用另外开口。
- 等你开世界，我这边 `Join Game` → LAN 先试，不行再 `Join IP 192.168.5.11:2456`。
