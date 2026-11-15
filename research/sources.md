# 上游项目索引

查证时用到的所有来源，按可靠性排序。

## 官方 / 活跃

| 项目 | 地址 | ★ | 最后活动 | 说明 |
|---|---|---|---|---|
| Mr_Goldberg（原版） | https://gitlab.com/Mr_Goldberg/goldberg_emulator | 1094 | 2026-09-21 | 原始作者，Linux + Windows |
| Detanup01/gbe_fork | https://github.com/Detanup01/gbe_fork | 2856 | 2026-10-30 | 活跃 fork，Windows 首选 |

## macOS 构建（均非官方）

| 项目 | ★ | 最后推送 | 实测 | 说明 |
|---|---|---|---|---|
| aaf2tbz/goldberg_emulator | 6 | 2026-08-14 | ✅ universal binary | **首选**，SDK v1.0–v1.65 全接口 |
| squareloopthings/goldberg-mac | 1 | 2026-08-23 | 未测 | Apple Silicon 专用 |
| bitmap4/goldberg-mac-shim | 1 | 2026-06-22 | 未测 | 兼容层，让旧 Goldberg 跑 Mac |
| da-wood69/goldberg-emulator-macos | 0 | 2026-09-02 | 未测 | universal 构建脚本 |
| surf5726/goldberg_emulator_macos | 0 | 2026-06-25 | 未测 | 个人修改版 |
| s690759602/goldberg_emulator | 2 | 2023-03-28 | 未测 | 老版本，仅 x86_64 |

## 关键 issue

| 编号 | 标题 | 状态 | 价值 |
|---|---|---|---|
| Detanup01/gbe_fork#41 | Add support for steam's lan game servers | closed | **维护者确认 LAN 发现靠 `custom_broadcasts.txt`** |
| Detanup01/gbe_fork#396 | Multiplayer dosnt work with the new version | closed | **Valheim 联机 2025-09-13 后被破坏，2026-01-17 修复** |
| Detanup01/gbe_fork#189 | [Feature] Mac Support | **open** | 官方明确不支持 macOS |

## 辅助工具

| 项目 | ★ | 说明 |
|---|---|---|
| delabarra/SmartGoldbergEmu | 41 | Windows GUI，自动配置 Goldberg（仅 Windows） |
| brunolee-GIT/GSE-Generator | 189 | 生成 steam_settings |
| alex47exe/gse_fork | 416 | 另一个活跃 fork |

## Valheim 相关信息

- Steam AppID: `892970`
- 专用服务器 AppID: `896660`
- 平台：Windows / macOS / Linux（**有原生 Mac 版**）
- 联机协议：PlayFab（官方跨平台）+ LAN（Steam server browser）

## 搜索记录

以下查询在 GitHub 全站返回 **0 结果**：

```
valheim + goldberg + guide
valheim + coop + one copy
valheim + multiplayer + emulator
valheim + crack + multiplayer
```

**结论：没有现成的 Valheim + Goldberg 双人方案。**
