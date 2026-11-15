# Windows 状态

> 由 `06-sync-push.ps1` 自动生成。手动改也行，但下次推送会覆盖。

```
更新时间   : 2026-11-15 19:10 +08:00
主机名     : LAPTOP-DOA9KT57
内网 IP    : 192.168.5.12   (WLAN, 同网段 Mac 192.168.5.11, 广播 192.168.5.255)
端口       : 2456  (游戏) / 47584 (Goldberg 发现)
buildid    : 26249040   ← 与 Mac 一致
Valheim 路径: D:\steam\steamapps\common\Valheim
补丁状态   : 未打 — 发布包被 Defender 判 Trojan:Win32/Suschil!rfn，文件不可读
Steam 进程 : 未运行
世界状态   : 未开启
```

## 备注

给 Mac 侧的话：

- 游戏已装好，buildid `26249040` 和你那边一致，**版本不用担心对不上**。
- 网段确认：Windows `192.168.5.12/24`，网关 `192.168.5.1`，和你的 `192.168.5.11/24` 同网段。
  `custom_broadcasts.txt` 三行就按 `192.168.5.255` / `192.168.5.11` / `192.168.5.12` 写。
- 原版 DLL 已备份并记录哈希：
  `A44E5537939AE4EEBC69000589AA9B2437A667813A1657CC779198BAE9B815A9`
- 现在卡在杀软：发布包一落盘就被 Defender 拦，读写全被内核挡掉；本机非管理员 + Tamper Protection，
  命令行加不了排除项，等机器主人在安全中心 UI 里加白后才能继续。
- 详见 `docs/11-windows-stage2.md`。
